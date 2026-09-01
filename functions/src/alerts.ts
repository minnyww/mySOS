/**
 * MySOS alert fan-out handlers.
 *
 * Two handlers:
 *  - onAlertCreatedHandler  : created an alert → fan out to caregivers
 *  - onAlertUpdatedHandler  : ack or cancel → notify the other side
 *
 * Each is a plain (alertId, data) -> Promise so they can be wrapped by
 * either v1 (firebase-functions/v1/firestore) or v2 (v2/firestore) triggers
 * — letting us choose the variant that Eventarc supports for our DB region.
 */
import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import type { MulticastMessage } from 'firebase-admin/messaging';
import { lineChannelToken, twilioAccountSid, twilioAuthToken, twilioFrom } from './config';
import { linePush, buildSosMessage } from './line';
import { sendSms, normalizeThaiPhone, buildSosSmsBody } from './twilio';
import { db } from './admin';

/** Minimum gap between two fanned-out SOS alerts from the same user. */
const SOS_COOLDOWN_MS = 60_000;

const INVALID_TOKEN_ERRORS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-apns-token',
]);

interface UserData {
  role?: string;
  displayName?: string;
  phone?: string;
  fcmTokens?: string[];
  lineUserId?: string;
  caregiverUids?: string[];
  caringUids?: string[];
  sosLastAlertAt?: FirebaseFirestore.Timestamp | number;
}

function toMillis(value: unknown): number {
  if (typeof value === 'number') return value;
  if (value && typeof value === 'object' && 'toMillis' in value) {
    return (value as FirebaseFirestore.Timestamp).toMillis();
  }
  return 0;
}

async function fanOutAlert(alertId: string, raw: admin.firestore.QueryDocumentSnapshot | undefined) {
  if (!raw) return;
  const alert = raw.data();
  const channels: Record<string, unknown> = {};

  const ownerRef = db.collection('users').doc(String(alert.userId));
  const ownerSnap = await ownerRef.get();
  if (!ownerSnap.exists) {
    await raw.ref.update({ status: 'failed', 'channels.error': 'owner-profile-missing' });
    return;
  }
  const owner = ownerSnap.data() as UserData;

  const ts = toMillis(alert.ts) || Date.now();
  if (ts - toMillis(owner.sosLastAlertAt) < SOS_COOLDOWN_MS) {
    await raw.ref.update({ status: 'rate_limited' });
    return;
  }
  await ownerRef.update({ sosLastAlertAt: FieldValue.serverTimestamp() });

  const caregiverUids: string[] = Array.isArray(alert.caregiverUids) ? alert.caregiverUids : [];
  if (caregiverUids.length === 0) {
    channels.summary = 'no-caregivers-linked';
    await raw.ref.update({ status: 'no_caregivers', channels });
    return;
  }

  const caregivers: { uid: string; data: UserData }[] = [];
  for (const uid of caregiverUids) {
    const snap = await db.collection('users').doc(uid).get();
    if (snap.exists) caregivers.push({ uid, data: snap.data() as UserData });
  }

  const userName = String(alert.userName ?? 'ผู้ใช้');
  const alertDate = new Date(ts);
  const dateText = alertDate.toLocaleDateString('th-TH', { day: 'numeric', month: 'short' });
  const timeText = alertDate.toLocaleTimeString('th-TH', { hour: '2-digit', minute: '2-digit' });
  const sourceText = alert.source === 'widget' ? 'วิดเจ็ตหน้าจอหลัก' : 'แอป MySOS';
  const location = alert.location as { lat: number; lng: number } | undefined;
  const mapUrl = location ? `https://maps.google.com/?q=${location.lat},${location.lng}` : null;
  const locationText = location
    ? `${location.lat.toFixed(5)}, ${location.lng.toFixed(5)}`
    : null;
  const alertInfo = {
    userName,
    dateTimeText: `${dateText} ${timeText}`,
    sourceText,
    locationText,
    mapUrl,
    phone: owner.phone ?? null,
  };

  // ---- Channel 1: FCM push -------------------------------------------------
  try {
    const tokens = caregivers.flatMap((c) => (Array.isArray(c.data.fcmTokens) ? c.data.fcmTokens : []));
    if (tokens.length === 0) {
      channels.fcm = { sent: 0, failed: 0, skipped: 'no-tokens' };
    } else {
      const message: MulticastMessage = {
        tokens,
        data: {
          type: 'sos',
          alertId,
          userId: String(alert.userId ?? ''),
          userName,
          ts: String(ts),
          source: String(alert.source ?? 'app'),
          ...(location ? { lat: String(location.lat), lng: String(location.lng) } : {}),
          ...(owner.phone ? { phone: owner.phone } : {}),
        },
        notification: {
          title: `🚨 SOS จาก ${userName}`,
          body: [
            `⏰ ${dateText} ${timeText} น. • จาก${sourceText}`,
            locationText ? `📍 พิกัด ${locationText}` : '📍 ไม่มีข้อมูลตำแหน่ง',
            locationText ? 'แตะเพื่อดูแผนที่และโทรกลับ' : 'แตะเพื่อดูรายละเอียดและติดต่อกลับ',
          ].join('\n'),
        },
        android: {
          priority: 'high',
          notification: {
            icon: 'ic_notification',
            channelId: 'sos_alerts',
            priority: 'max',
            sound: 'default',
          },
        },
        apns: {
          payload: { aps: { sound: 'default', interruptionLevel: 'time-sensitive' } },
        },
      };
      const response = await admin.messaging().sendEachForMulticast(message);
      const invalid: { uid: string; token: string }[] = [];
      let i = 0;
      let failed = 0;
      for (const r of response.responses) {
        const token = tokens[i++];
        if (!r.success) {
          failed++;
          if (r.error && INVALID_TOKEN_ERRORS.has(r.error.code)) {
            const ownerDoc = caregivers.find((c) => c.data.fcmTokens?.includes(token));
            if (ownerDoc) invalid.push({ uid: ownerDoc.uid, token });
          }
        }
      }
      for (const { uid, token } of invalid) {
        await db.collection('users').doc(uid).update({ fcmTokens: FieldValue.arrayRemove(token) });
      }
      channels.fcm = { sent: response.successCount, failed, prunedTokens: invalid.length };
    }
  } catch (err) {
    channels.fcm = { error: (err as Error).message.slice(0, 200) };
  }

  // ---- Channel 2: LINE Messaging API --------------------------------------
  try {
    const token = lineChannelToken.value();
    const lineUsers = caregivers.filter((c) => typeof c.data.lineUserId === 'string' && c.data.lineUserId);
    if (!token) {
      channels.line = { skipped: 'not-configured' };
    } else if (lineUsers.length === 0) {
      channels.line = { skipped: 'no-linked-line-accounts' };
    } else {
      const message = buildSosMessage(alertInfo);
      let sent = 0;
      const errors: string[] = [];
      for (const c of lineUsers) {
        try {
          await linePush(c.data.lineUserId as string, token, [message]);
          sent++;
        } catch (e) {
          errors.push(`uid=${c.uid}: ${(e as Error).message.slice(0, 100)}`);
        }
      }
      channels.line = errors.length ? { sent, errors } : { sent };
    }
  } catch (err) {
    channels.line = { error: (err as Error).message.slice(0, 200) };
  }

  // ---- Channel 3: SMS via Twilio ------------------------------------------
  try {
    const accountSid = twilioAccountSid.value();
    const authToken = twilioAuthToken.value();
    const from = twilioFrom.value();
    const targets = caregivers
      .map((c) => ({ uid: c.uid, phone: c.data.phone ? normalizeThaiPhone(c.data.phone) : null }))
      .filter((t): t is { uid: string; phone: string } => t.phone !== null);
    if (!accountSid || !authToken || !from) {
      channels.sms = { skipped: 'not-configured' };
    } else if (targets.length === 0) {
      channels.sms = { skipped: 'no-valid-phone-numbers' };
    } else {
      const body = buildSosSmsBody(userName, timeText, mapUrl);
      let sent = 0;
      const errors: string[] = [];
      for (const t of targets) {
        const result = await sendSms(accountSid, authToken, from, t.phone, body);
        if (result.ok) sent++;
        else errors.push(`uid=${t.uid}: ${result.error}`);
      }
      channels.sms = errors.length ? { sent, errors } : { sent };
    }
  } catch (err) {
    channels.sms = { error: (err as Error).message.slice(0, 200) };
  }

  channels.completedAt = FieldValue.serverTimestamp();
  await raw.ref.update({ channels });
}

async function handleAlertUpdated(
  alertId: string,
  before: admin.firestore.QueryDocumentSnapshot | undefined,
  after: admin.firestore.QueryDocumentSnapshot | undefined,
) {
  if (!before || !after) return;
  const b = before.data();
  const a = after.data();

  if (b.status === 'active' && a.status === 'acked') {
    const ownerSnap = await db.collection('users').doc(String(a.userId)).get();
    const tokens = (ownerSnap.data() as UserData | undefined)?.fcmTokens ?? [];
    if (tokens.length === 0) return;
    const ackAtText = new Date(toMillis(a.ackAt) || Date.now()).toLocaleTimeString('th-TH', {
      hour: '2-digit',
      minute: '2-digit',
    });
    const sentAtText = new Date(toMillis(a.ts) || Date.now()).toLocaleTimeString('th-TH', {
      hour: '2-digit',
      minute: '2-digit',
    });
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: '✅ ผู้ดูแลรับทราบแล้ว',
        body: [
          `${String(a.ackByName ?? 'ผู้ดูแล')} เห็น SOS ของคุณแล้ว`,
          `ตอบรับเมื่อ ${ackAtText} น. (แจ้งเตือนเมื่อ ${sentAtText} น.)`,
        ].join('\n'),
      },
      data: { type: 'ack', alertId },
      android: {
        priority: 'high',
        notification: { icon: 'ic_notification', channelId: 'sos_alerts' },
      },
    });
    return;
  }

  if (b.status === 'active' && a.status === 'cancelled') {
    const uids: string[] = Array.isArray(a.caregiverUids) ? a.caregiverUids : [];
    const tokens: string[] = [];
    for (const uid of uids) {
      const snap = await db.collection('users').doc(uid).get();
      const t = (snap.data() as UserData | undefined)?.fcmTokens;
      if (t) tokens.push(...t);
    }
    if (tokens.length === 0) return;
    const cancelTimeText = new Date().toLocaleTimeString('th-TH', {
      hour: '2-digit',
      minute: '2-digit',
    });
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: 'SOS ถูกยกเลิกแล้ว',
        body: `${String(a.userName ?? 'ผู้ใช้')} ยกเลิกการขอความช่วยเหลือแล้ว เมื่อ ${cancelTimeText} น.`,
      },
      data: { type: 'alert_cancelled', alertId },
      android: {
        notification: { icon: 'ic_notification', channelId: 'sos_alerts' },
      },
    });
  }
}

export async function onAlertCreatedHandler(
  alertId: string,
  snap: admin.firestore.QueryDocumentSnapshot | undefined,
) {
  await fanOutAlert(alertId, snap);
}

export async function onAlertUpdatedHandler(
  alertId: string,
  before: admin.firestore.QueryDocumentSnapshot,
  after: admin.firestore.QueryDocumentSnapshot,
) {
  await handleAlertUpdated(alertId, before, after);
}

/**
 * Wire up a pair code once a caregiver claims it.
 * Plain handler so v1/v2 triggers can call it.
 */
import { db } from './admin';
import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';

export async function onPairAcceptedHandler(
  code: string,
  before: admin.firestore.QueryDocumentSnapshot,
  after: admin.firestore.QueryDocumentSnapshot,
) {
  const b = before.data();
  const a = after.data();
  if (b.acceptedBy || !a.acceptedBy) return;
  if (a.status !== 'pending') return;

  const ownerUid = String(a.ownerUid);
  const caregiverUid = String(a.acceptedBy);
  if (ownerUid === caregiverUid) return;

  const pairRef = after.ref;
  const ownerRef = db.collection('users').doc(ownerUid);
  const caregiverRef = db.collection('users').doc(caregiverUid);

  let ownerName = 'ผู้ใช้';
  let caregiverName = 'ผู้ดูแล';
  let ownerTokens: string[] = [];
  let caregiverTokens: string[] = [];

  await db.runTransaction(async (tx) => {
    const pairSnap = await tx.get(pairRef);
    const pair = pairSnap.data();
    if (!pair || pair.status !== 'pending' || !pair.acceptedBy) return;
    const expiresAt = typeof pair.expiresAt === 'number' ? pair.expiresAt : 0;
    if (expiresAt < Date.now()) return;

    const [ownerSnap, caregiverSnap] = await Promise.all([tx.get(ownerRef), tx.get(caregiverRef)]);
    if (!ownerSnap.exists || !caregiverSnap.exists) return;

    const owner = ownerSnap.data()!;
    const caregiver = caregiverSnap.data()!;
    ownerName = String(owner.displayName ?? 'ผู้ใช้');
    caregiverName = String(caregiver.displayName ?? 'ผู้ดูแล');
    ownerTokens = Array.isArray(owner.fcmTokens) ? owner.fcmTokens : [];
    caregiverTokens = Array.isArray(caregiver.fcmTokens) ? caregiver.fcmTokens : [];

    tx.update(ownerRef, { caregiverUids: FieldValue.arrayUnion(caregiverUid) });
    tx.update(caregiverRef, { caringUids: FieldValue.arrayUnion(ownerUid) });
    tx.create(db.collection('links').doc(), {
      userId: ownerUid,
      caregiverId: caregiverUid,
      active: true,
      pairCode: code,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(pairRef, { status: 'linked', linkedAt: FieldValue.serverTimestamp() });
  });

  const notify = async (tokens: string[], title: string, body: string) => {
    if (tokens.length === 0) return;
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: { type: 'pair_linked' },
    });
  };

  await Promise.all([
    notify(ownerTokens, 'เชื่อมต่อสำเร็จ', `${caregiverName} จะได้รับแจ้งเตือน SOS ของคุณ`),
    notify(caregiverTokens, 'เชื่อมต่อสำเร็จ', `คุณจะได้รับแจ้งเตือน SOS จาก ${ownerName}`),
  ]);
}

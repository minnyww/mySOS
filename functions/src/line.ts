import { createHmac, timingSafeEqual } from 'crypto';

const LINE_API = 'https://api.line.me/v2/bot';

export interface LineAction {
  type: 'uri';
  label: string;
  uri: string;
}

export function verifySignature(secret: string, body: Buffer, signature: string | undefined): boolean {
  if (!signature) return false;
  const expected = Buffer.from(createHmac('sha256', secret).update(body).digest('base64'));
  const actual = Buffer.from(signature);
  if (expected.length !== actual.length) return false;
  return timingSafeEqual(expected, actual);
}

export async function lineReply(replyToken: string, token: string, text: string): Promise<void> {
  await fetch(`${LINE_API}/message/reply`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ replyToken, messages: [{ type: 'text', text }] }),
  });
}

export async function linePush(to: string, token: string, messages: unknown[]): Promise<void> {
  const res = await fetch(`${LINE_API}/message/push`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ to, messages }),
  });
  if (!res.ok) {
    throw new Error(`LINE push failed: HTTP ${res.status} ${(await res.text().catch(() => '')).slice(0, 200)}`);
  }
}

/** Details of one SOS alert, pre-formatted for display in messages. */
export interface SosAlertInfo {
  userName: string;
  dateTimeText: string;
  sourceText: string;
  locationText: string | null;
  mapUrl: string | null;
  phone: string | null;
}

/** Buttons template for an SOS alert; falls back to plain text when no actions are available. */
export function buildSosMessage(info: SosAlertInfo): unknown {
  const { userName, dateTimeText, sourceText, locationText, mapUrl, phone } = info;
  const actions: LineAction[] = [];
  if (mapUrl) {
    actions.push({ type: 'uri', label: 'ดูตำแหน่งแผนที่', uri: mapUrl });
  }
  if (phone) {
    const label = `โทรหา ${userName}`.slice(0, 20);
    actions.push({ type: 'uri', label, uri: `tel:${phone}` });
  }

  const altText =
    `🚨 SOS จาก ${userName} เวลา ${dateTimeText} น. (จาก${sourceText})` +
    (locationText ? ` พิกัด ${locationText}` : ' ไม่มีข้อมูลตำแหน่ง') +
    ' — เปิดแอป MySOS เพื่อดูรายละเอียด';

  if (actions.length === 0) {
    const lines = [
      '🚨 SOS ฉุกเฉิน',
      `ผู้ขอความช่วยเหลือ: ${userName}`,
      `🕐 เวลา: ${dateTimeText} น. (จาก${sourceText})`,
      `📍 พิกัด: ${locationText ?? 'ไม่มีข้อมูลตำแหน่ง'}`,
    ];
    if (phone) lines.push(`📞 เบอร์ติดต่อ: ${phone}`);
    lines.push('เปิดแอป MySOS เพื่อดูรายละเอียด');
    return { type: 'text', text: lines.join('\n') };
  }

  // Buttons template caps `text` at 60 characters (a title is present),
  // so the detail block is truncated rather than risking a rejected push.
  const text = [
    `${userName} ขอความช่วยเหลือ`,
    `🕐 ${dateTimeText} น. • ${sourceText}`,
    `📍 ${locationText ?? 'ไม่มีข้อมูลตำแหน่ง'}`,
  ]
    .join('\n')
    .slice(0, 60);

  return {
    type: 'template',
    altText,
    template: {
      type: 'buttons',
      title: '🚨 SOS ฉุกเฉิน',
      text,
      actions,
    },
  };
}

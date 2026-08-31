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

/** Buttons template for an SOS alert; falls back to plain text when no actions are available. */
export function buildSosMessage(userName: string, timeText: string, mapUrl: string | null, phone: string | null): unknown {
  const actions: LineAction[] = [];
  if (mapUrl) {
    actions.push({ type: 'uri', label: 'ดูตำแหน่ง', uri: mapUrl });
  }
  if (phone) {
    const label = `โทรหา ${userName}`.slice(0, 20);
    actions.push({ type: 'uri', label, uri: `tel:${phone}` });
  }
  if (actions.length === 0) {
    return {
      type: 'text',
      text: `🚨 SOS จาก ${userName} เวลา ${timeText} น. — เปิดแอป MySOS เพื่อดูรายละเอียด`,
    };
  }
  return {
    type: 'template',
    altText: `🚨 SOS จาก ${userName} เวลา ${timeText} น.`,
    template: {
      type: 'buttons',
      title: '🚨 SOS',
      text: `${userName} ขอความช่วยเหลือ\nเวลา ${timeText} น.`,
      actions,
    },
  };
}

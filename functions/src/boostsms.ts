/**
 * BoostSMS adapter — https://boost-sms.com
 * POST /api/v1/sms/send, Authorization: Bearer <key>
 * Body: { recipient, message, senderName? } — rate limit 10 req/min.
 * Thai text is UCS-2 encoded: max 70 chars per segment (billed per segment).
 */

const BOOSTSMS_SEND_URL = 'https://app.boost-sms.com/api/v1/sms/send';

export interface SmsResult {
  ok: boolean;
  error?: string;
}

export function normalizeThaiPhone(raw: string): string | null {
  const digits = raw.replace(/(?!^\+)\D/g, '');
  if (/^0\d{9}$/.test(digits)) return digits;
  if (/^\+66\d{9}$/.test(digits)) return `0${digits.slice(3)}`;
  if (/^66\d{9}$/.test(digits)) return `0${digits.slice(2)}`;
  return null;
}

export async function sendSms(
  apiKey: string,
  recipient: string,
  message: string,
  senderName: string
): Promise<SmsResult> {
  try {
    const res = await fetch(BOOSTSMS_SEND_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        recipient,
        message,
        ...(senderName ? { senderName } : {}),
      }),
    });
    if (res.ok) return { ok: true };
    const detail = await res.text().catch(() => '');
    return { ok: false, error: `HTTP ${res.status} ${detail}`.slice(0, 200) };
  } catch (err) {
    return { ok: false, error: (err as Error).message.slice(0, 200) };
  }
}

/** Build the SMS body — kept short so a Thai message stays within one 70-char segment when possible. */
export function buildSosSmsBody(userName: string, timeText: string, mapUrl: string | null): string {
  const base = `SOS! ${userName} ขอความช่วยเหลือ (${timeText}น.)`;
  if (!mapUrl) return `${base} ด่วน!`;
  return `${base} ${mapUrl}`;
}

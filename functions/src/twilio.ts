/**
 * Twilio SMS adapter — POST /2010-04-01/Accounts/{sid}/Messages.json
 * Basic auth (AccountSID:AuthToken), form-encoded To/From/Body.
 * Thai text is UCS-2 encoded: max 70 chars per segment (billed per segment).
 */

export interface SmsResult {
  ok: boolean;
  error?: string;
}

/** Returns E.164 (+66xxxxxxxxx) — Twilio requires international format. */
export function normalizeThaiPhone(raw: string): string | null {
  const digits = raw.replace(/(?!^\+)\D/g, '');
  if (/^0\d{9}$/.test(digits)) return `+66${digits.slice(1)}`;
  if (/^\+66\d{9}$/.test(digits)) return digits;
  if (/^66\d{9}$/.test(digits)) return `+${digits}`;
  return null;
}

export async function sendSms(
  accountSid: string,
  authToken: string,
  from: string,
  to: string,
  body: string
): Promise<SmsResult> {
  try {
    const res = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
      {
        method: 'POST',
        headers: {
          Authorization: `Basic ${Buffer.from(`${accountSid}:${authToken}`).toString('base64')}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({ To: to, From: from, Body: body }).toString(),
        signal: AbortSignal.timeout(10_000),
      }
    );
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

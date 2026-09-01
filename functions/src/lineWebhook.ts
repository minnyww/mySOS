/**
 * HTTP handler for the LINE Messaging API webhook.
 * Plain (req, res) handler so it can be wrapped as v1 or v2.
 */
import { FieldValue } from 'firebase-admin/firestore';
import { lineChannelToken, lineChannelSecret } from './config';
import { verifySignature, lineReply } from './line';
import { db } from './admin';

interface LineEvent {
  type: string;
  replyToken?: string;
  source?: { userId?: string };
  message?: { type: string; text?: string };
}

const HELP_TEXT =
  'ยินดีต้อนรับสู่ MySOS 🚨\n' +
  'เพื่อรับแจ้งเตือน SOS ผ่าน LINE กรุณาเปิดแอป MySOS → ตั้งค่า → "เชื่อมต่อ LINE" ' +
  'แล้วส่งรหัส 6 หลักที่ได้จากแอปมาที่แชทนี้';

export async function lineWebhookHandler(req: { method?: string; rawBody?: Buffer; body?: unknown; get(name: string): string | undefined }, res: { status(code: number): { send(body: string): void }; sendStatus?(code: number): void }) {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }
  const secret = lineChannelSecret.value();
  const token = lineChannelToken.value();
  if (!secret || !token) {
    res.status(503).send('LINE channel not configured');
    return;
  }

  const raw: Buffer = req.rawBody ?? Buffer.from(JSON.stringify(req.body));
  const signature = req.get('x-line-signature');
  if (!verifySignature(secret, raw, signature)) {
    res.status(403).send('Invalid signature');
    return;
  }

  const body = JSON.parse(raw.toString('utf8')) as { events?: LineEvent[] };
  for (const event of body.events ?? []) {
    try {
      await handleEvent(event, token);
    } catch (err) {
      console.error('lineWebhook event error', err);
    }
  }
  res.status(200).send('OK');
}

async function handleEvent(event: LineEvent, token: string): Promise<void> {
  const lineUserId = event.source?.userId;
  const replyToken = event.replyToken;
  if (!lineUserId || !replyToken) return;

  if (event.type === 'follow') {
    await lineReply(replyToken, token, HELP_TEXT);
    return;
  }

  if (event.type === 'message' && event.message?.type === 'text') {
    const text = String(event.message.text ?? '').trim();
    const match = text.match(/(\d{6})/);
    if (!match) {
      await lineReply(replyToken, token, 'กรุณาส่งรหัสเชื่อมต่อ 6 หลักจากแอป MySOS เท่านั้น\n' + HELP_TEXT);
      return;
    }
    const code = match[1];
    // Equality-only query: adding a range filter on lineLinkExpiresAt would
    // require a composite index that Firestore does not create automatically.
    const snap = await db.collection('users').where('lineLinkCode', '==', code).get();
    const doc = snap.docs.find((d) => {
      const expiresAt = d.data().lineLinkExpiresAt;
      return typeof expiresAt === 'number' && expiresAt > Date.now();
    });

    if (!doc) {
      await lineReply(replyToken, token, 'รหัสไม่ถูกต้องหรือหมดอายุ กรุณาสร้างรหัสใหม่ในแอป MySOS แล้วส่งมาอีกครั้ง');
      return;
    }
    await doc.ref.update({
      lineUserId,
      lineLinkCode: FieldValue.delete(),
      lineLinkExpiresAt: FieldValue.delete(),
    });
    await lineReply(
      replyToken,
      token,
      `เชื่อมต่อสำเร็จ ✅\n${String(doc.data().displayName ?? 'คุณ')} จะได้รับแจ้งเตือน SOS ผ่าน LINE นี้`,
    );
  }
}

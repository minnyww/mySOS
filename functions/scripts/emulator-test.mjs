/**
 * Emulator integration test for MySOS Cloud Functions.
 *
 * Prerequisites: firebase emulators running (functions+firestore) on localhost.
 *   cd functions && firebase emulators:start --only functions,firestore --project demo-mysos
 *
 * Run:  cd functions && node scripts/emulator-test.mjs
 */
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_FIRESTORE_EMULATOR_ADDRESS ??= '127.0.0.1:8080';
process.env.CLOUD_STORAGE_EMULATOR_HOST ??= '127.0.0.1:9199';

const app = initializeApp({ projectId: 'demo-mysos' });
// Functions and the app both use the named mysosdb database.
const db = getFirestore(app, 'mysosdb');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitFor(cond, { timeoutMs = 15000, label = '' } = {}) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const v = await cond();
    if (v) return v;
    await sleep(300);
  }
  throw new Error(`timeout waiting for: ${label}`);
}

let failures = 0;
function check(name, ok, detail = '') {
  console.log(`${ok ? '✅' : '❌'} ${name}${detail ? ` — ${detail}` : ''}`);
  if (!ok) failures++;
}

async function main() {
  // --- setup: owner + caregiver profiles --------------------------------
  const ownerUid = 'test-owner';
  const caregiverUid = 'test-caregiver';
  const ownerRef = db.collection('users').doc(ownerUid);
  const caregiverRef = db.collection('users').doc(caregiverUid);
  await ownerRef.set({
    role: 'user',
    displayName: 'คุณแม่',
    phone: '0811111111',
    fcmTokens: [],
    caregiverUids: [],
    caringUids: [],
    createdAt: Date.now(),
  });
  await caregiverRef.set({
    role: 'caregiver',
    displayName: 'ลูกสาว',
    phone: '0899999999',
    fcmTokens: [],
    caregiverUids: [],
    caringUids: [],
    createdAt: Date.now(),
  });

  // --- 1. pairing: caregiver claims the code ----------------------------
  const code = String(100000 + Math.floor(Math.random() * 899999));
  await db.collection('pairs').doc(code).set({
    ownerUid,
    role: 'user',
    status: 'pending',
    createdAt: Date.now(),
    expiresAt: Date.now() + 10 * 60 * 1000,
  });
  await db.collection('pairs').doc(code).update({ acceptedBy: caregiverUid });

  const pairAfter = await waitFor(
    async () => {
      const snap = await db.collection('pairs').doc(code).get();
      return snap.data()?.status === 'linked' ? snap.data() : null;
    },
    { label: 'pair status linked' }
  );
  check('pairing: pair doc flips to linked', pairAfter?.status === 'linked');

  const ownerAfter = (await ownerRef.get()).data();
  const caregiverAfter = (await caregiverRef.get()).data();
  check('pairing: owner.caregiverUids contains caregiver', JSON.stringify(ownerAfter.caregiverUids) === JSON.stringify([caregiverUid]));
  check('pairing: caregiver.caringUids contains owner', JSON.stringify(caregiverAfter.caringUids) === JSON.stringify([ownerUid]));

  const linksSnap = await db
    .collection('links')
    .where('userId', '==', ownerUid)
    .where('caregiverId', '==', caregiverUid)
    .limit(1)
    .get();
  check('pairing: links document created', linksSnap.size >= 1);

  // --- 2. SOS alert fan-out (no keys configured -> graceful skips) ------
  const alertRef = await db.collection('alerts').add({
    userId: ownerUid,
    userName: 'คุณแม่',
    status: 'active',
    source: 'app',
    ts: Date.now(),
    caregiverUids: [caregiverUid],
    location: { lat: 13.7563, lng: 100.5018 },
  });

  const alertAfter = await waitFor(
    async () => {
      const snap = await alertRef.get();
      const d = snap.data();
      return d?.channels?.completedAt ? d : null;
    },
    { label: 'alert channels completed' }
  );
  const ch = alertAfter.channels;
  check('alert: fcm channel skipped (no tokens)', ch.fcm?.skipped === 'no-tokens');
  // 'not-configured' when LINE_CHANNEL_TOKEN is empty; 'no-linked-line-accounts'
  // when a token exists but the caregiver hasn't linked LINE. Both are correct.
  check(
    'alert: line channel skipped gracefully',
    ch.line?.skipped === 'not-configured' || ch.line?.skipped === 'no-linked-line-accounts',
    JSON.stringify(ch.line),
  );
  check('alert: sms channel skipped (not configured)', ch.sms?.skipped === 'not-configured');
  check('alert: status stays active', alertAfter.status === 'active');
  const ownerNow = (await ownerRef.get()).data();
  check('alert: sosLastAlertAt stamped on owner', !!ownerNow.sosLastAlertAt);

  // --- 3. rate limiting: immediate second alert is suppressed -----------
  const alert2Ref = await db.collection('alerts').add({
    userId: ownerUid,
    userName: 'คุณแม่',
    status: 'active',
    source: 'widget',
    ts: Date.now(),
    caregiverUids: [caregiverUid],
  });
  const alert2 = await waitFor(
    async () => {
      const snap = await alert2Ref.get();
      return snap.data()?.status === 'rate_limited' ? snap.data() : null;
    },
    { label: 'second alert rate_limited' }
  );
  check('rate limit: second alert within 60s is rate_limited', alert2.status === 'rate_limited');

  // --- 4. ack: caregiver acknowledges ------------------------------------
  await alertRef.update({
    status: 'acked',
    ackBy: caregiverUid,
    ackByName: 'ลูกสาว',
    ackAt: Date.now(),
  });
  await sleep(1500); // ack handler runs; owner has no tokens -> early return, no throw
  const acked = (await alertRef.get()).data();
  check('ack: alert status acked and intact', acked.status === 'acked' && acked.ackByName === 'ลูกสาว');

  // --- 5. LINE webhook signature validation ------------------------------
  const functionsEmulator = 'http://127.0.0.1:5001/demo-mysos/asia-southeast1/lineWebhook';
  const bad = await fetch(functionsEmulator, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-line-signature': 'badsig=' },
    body: JSON.stringify({ events: [] }),
  });
  // 403 when LINE_CHANNEL_SECRET is configured; 503 when it is not (dev .env
  // leaves it empty) — both prove the endpoint guards itself instead of 200.
  check('lineWebhook: rejects bad signature (403/503)', bad.status === 403 || bad.status === 503);
  const get = await fetch(functionsEmulator, { method: 'GET' });
  check('lineWebhook: rejects GET (405)', get.status === 405);

  console.log(failures === 0 ? '\n🎉 ALL CHECKS PASSED' : `\n💥 ${failures} CHECK(S) FAILED`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error('💥 test crashed:', e.message);
  process.exit(1);
});

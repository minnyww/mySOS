// Rules regression test: reproduce the exact FCM token write that the app
// performs, against the local firestore.rules on the emulator.
const fs = require('fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { arrayUnion } = require('@firebase/firestore');

const PROJECT = 'chayen-rules-test';
const UID = 'user123';
const CAREGIVER = 'caregiver456';

(async () => {
  const env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: { rules: fs.readFileSync('../firestore.rules', 'utf8') },
  });

  async function withDoc(doc) {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`users/${UID}`).set(doc);
    });
  }

  async function tryTokenUpdate() {
    const db = env.authenticatedContext(UID).firestore();
    await db.doc(`users/${UID}`).update({ fcmTokens: arrayUnion('tok_abc') });
  }

  // Case A: fresh profile, no sosLastAlertAt yet.
  await withDoc({
    role: 'user', displayName: 'แม่', phone: '0877506878',
    caregiverUids: [CAREGIVER], caringUids: [], fcmTokens: [],
    createdAt: 1788191913091,
  });
  try { await assertSucceeds(tryTokenUpdate()); console.log('A (no sosLastAlertAt): ALLOW'); }
  catch (e) { console.log('A (no sosLastAlertAt): DENY —', e.message.split('\n')[0]); }

  // Case B: after the first alert — sosLastAlertAt written by the function.
  await withDoc({
    role: 'user', displayName: 'แม่', phone: '0877506878',
    caregiverUids: [CAREGIVER], caringUids: [], fcmTokens: [],
    createdAt: 1788191913091, sosLastAlertAt: new Date('2026-08-31T16:00:00Z'),
  });
  try { await assertSucceeds(tryTokenUpdate()); console.log('B (with sosLastAlertAt): ALLOW'); }
  catch (e) { console.log('B (with sosLastAlertAt): DENY —', e.message.split('\n')[0]); }

  // Case C: caregiver profile shape.
  await withDoc({
    role: 'caregiver', displayName: 'มิน', phone: '0909514409',
    caregiverUids: [], caringUids: [UID], fcmTokens: [],
    createdAt: 1788191869454,
  });
  try { await assertSucceeds(tryTokenUpdate()); console.log('C (caregiver doc): ALLOW'); }
  catch (e) { console.log('C (caregiver doc): DENY —', e.message.split('\n')[0]); }

  await env.cleanup();
  process.exit(0);
})().catch((e) => { console.error('FATAL', e); process.exit(1); });

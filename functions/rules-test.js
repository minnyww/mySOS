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

  async function withAlert(doc) {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`alerts/a1`).set(doc);
    });
  }

  const now = () => Date.now();
  const baseAlert = (ageMs) => ({
    userId: UID, userName: 'แม่', status: 'active', source: 'app',
    ts: now() - ageMs, location: { lat: 13.75, lng: 100.5 },
    caregiverUids: [CAREGIVER],
  });
  const freshFix = () => ({
    lat: 13.75001, lng: 100.50001, ts: now(),
  });

  async function tryLiveUpdate(asUid, extra) {
    const db = env.authenticatedContext(asUid).firestore();
    await db.doc('alerts/a1').update({
      location: { lat: 13.75001, lng: 100.50001 },
      locationUpdatedAt: now(),
      locationHistory: arrayUnion(freshFix()),
      ...(extra || {}),
    });
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

  // Case D: owner streams a live fix into an active alert <10 min old.
  await withAlert(baseAlert(60_000));
  try { await assertSucceeds(tryLiveUpdate(UID)); console.log('D (live fix, in window): ALLOW'); }
  catch (e) { console.log('D (live fix, in window): DENY —', e.message.split('\n')[0]); }

  // Case E: a caregiver cannot pose as the owner's live stream.
  try { await assertFails(tryLiveUpdate(CAREGIVER)); console.log('E (caregiver writes fix): DENY'); }
  catch (e) { console.log('E (caregiver writes fix): ALLOW — RULES HOLE'); }

  // Case F: window closed — alert older than 10 minutes.
  await withAlert(baseAlert(700_000));
  try { await assertFails(tryLiveUpdate(UID)); console.log('F (fix after 10 min): DENY'); }
  catch (e) { console.log('F (fix after 10 min): ALLOW — RULES HOLE'); }

  // Case G: location write must not smuggle a status change.
  await withAlert(baseAlert(60_000));
  try { await assertFails(tryLiveUpdate(UID, { status: 'acked' })); console.log('G (fix + status flip): DENY'); }
  catch (e) { console.log('G (fix + status flip): ALLOW — RULES HOLE'); }

  // Case H: trail may not be rewritten/shrunk wholesale.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('alerts/a1').set({
      ...baseAlert(60_000),
      locationHistory: [{ lat: 13.75, lng: 100.5, ts: now() - 30_000 }],
    });
  });
  const db = env.authenticatedContext(UID).firestore();
  try {
    await assertFails(db.doc('alerts/a1').update({
      location: { lat: 13.75002, lng: 100.50002 },
      locationUpdatedAt: now(),
      locationHistory: [],
    }));
    console.log('H (trail wipe): DENY');
  } catch (e) { console.log('H (trail wipe): ALLOW — RULES HOLE'); }

  await env.cleanup();
  process.exit(0);
})().catch((e) => { console.error('FATAL', e); process.exit(1); });

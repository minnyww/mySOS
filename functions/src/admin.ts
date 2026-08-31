/**
 * Firebase Admin SDK configured to talk to the mysosdb database.
 * Without this, admin SDK uses (default), whose region (asia-southeast3)
 * is not yet supported by Eventarc. By switching to mysosdb (asia-southeast1),
 * both the read/write API and Firestore triggers work end-to-end.
 */
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

const APP = initializeApp();
const db = getFirestore(APP, 'mysosdb');
const messaging = getMessaging(APP);

export { db, messaging };

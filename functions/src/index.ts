import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onRequest } from 'firebase-functions/v2/https';

// admin.ts performs the single initializeApp() and exposes the
// Firestore instance bound to the mysosdb database.
import { onAlertCreatedHandler, onAlertUpdatedHandler } from './alerts';
import { onPairAcceptedHandler } from './pairing';
import { lineWebhookHandler } from './lineWebhook';

// v2 triggers targeting the mysosdb database (asia-southeast1).
// The project's (default) database sits in asia-southeast3, which Eventarc
// does not support, so triggers must pin both database and region here.
const BASE = {
  region: 'asia-southeast1',
  database: 'mysosdb',
} as const;

// The Firebase project chayen-2 is shared with other apps that deploy their
// own functions (e.g. an `api` HTTPS function), and a full `firebase deploy`
// from those apps deletes anything not in their source — which wiped the
// previous unprefixed names. Every function is therefore namespaced `mysos*`
// so its path can never collide with another project's.
export const mysosOnAlertCreated = onDocumentCreated(
  { ...BASE, document: 'alerts/{alertId}' },
  (event) => onAlertCreatedHandler(event.params.alertId, event.data),
);

export const mysosOnAlertUpdated = onDocumentUpdated(
  { ...BASE, document: 'alerts/{alertId}' },
  (event) => {
    if (!event.data) return;
    return onAlertUpdatedHandler(event.params.alertId, event.data.before, event.data.after);
  },
);

export const mysosOnPairAccepted = onDocumentUpdated(
  { ...BASE, document: 'pairs/{code}' },
  (event) => {
    if (!event.data) return;
    return onPairAcceptedHandler(event.params.code, event.data.before, event.data.after);
  },
);

export const mysosLineWebhook = onRequest({ region: 'asia-southeast1' }, lineWebhookHandler);

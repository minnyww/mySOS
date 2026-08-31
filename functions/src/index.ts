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

export const onAlertCreated = onDocumentCreated(
  { ...BASE, document: 'alerts/{alertId}' },
  (event) => onAlertCreatedHandler(event.params.alertId, event.data),
);

export const onAlertUpdated = onDocumentUpdated(
  { ...BASE, document: 'alerts/{alertId}' },
  (event) => {
    if (!event.data) return;
    return onAlertUpdatedHandler(event.params.alertId, event.data.before, event.data.after);
  },
);

export const onPairAccepted = onDocumentUpdated(
  { ...BASE, document: 'pairs/{code}' },
  (event) => {
    if (!event.data) return;
    return onPairAcceptedHandler(event.params.code, event.data.before, event.data.after);
  },
);

export const lineWebhook = onRequest({ region: 'asia-southeast1' }, lineWebhookHandler);

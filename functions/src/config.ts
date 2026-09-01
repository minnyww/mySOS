import { defineString } from 'firebase-functions/params';

/** LINE Messaging API channel access token — empty disables the LINE channel. */
export const lineChannelToken = defineString('LINE_CHANNEL_TOKEN', { default: '' });

/** LINE Messaging API channel secret — used to verify the webhook signature. */
export const lineChannelSecret = defineString('LINE_CHANNEL_SECRET', { default: '' });

/** Twilio Account SID — empty disables the SMS channel. */
export const twilioAccountSid = defineString('TWILIO_ACCOUNT_SID', { default: '' });

/** Twilio Auth Token. */
export const twilioAuthToken = defineString('TWILIO_AUTH_TOKEN', { default: '' });

/** Twilio sender phone number in E.164 (e.g. +15551234567). */
export const twilioFrom = defineString('TWILIO_FROM', { default: '' });

/** Public base URL of the app, used inside message links. */
export const appBaseUrl = defineString('APP_BASE_URL', { default: 'https://mysos.example.com' });

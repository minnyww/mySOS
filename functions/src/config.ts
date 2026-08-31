import { defineString } from 'firebase-functions/params';

/** LINE Messaging API channel access token — empty disables the LINE channel. */
export const lineChannelToken = defineString('LINE_CHANNEL_TOKEN', { default: '' });

/** LINE Messaging API channel secret — used to verify the webhook signature. */
export const lineChannelSecret = defineString('LINE_CHANNEL_SECRET', { default: '' });

/** BoostSMS API key — empty disables the SMS channel. */
export const boostSmsApiKey = defineString('BOOSTSMS_API_KEY', { default: '' });

/** Optional BoostSMS sender name (must be pre-approved by the provider). */
export const boostSmsSenderName = defineString('BOOSTSMS_SENDER_NAME', { default: '' });

/** Public base URL of the app, used inside message links. */
export const appBaseUrl = defineString('APP_BASE_URL', { default: 'https://mysos.example.com' });

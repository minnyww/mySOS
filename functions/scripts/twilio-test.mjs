import assert from 'node:assert/strict';
import { buildSosSmsBody, normalizeThaiPhone } from '../lib/twilio.js';

assert.equal(normalizeThaiPhone('081-234-5678'), '+66812345678');
assert.equal(normalizeThaiPhone('+66 81 234 5678'), '+66812345678');
assert.equal(normalizeThaiPhone('66812345678'), '+66812345678');
assert.equal(normalizeThaiPhone('081234567'), null);
assert.match(buildSosSmsBody('สมชาย', '12:34', null), /SOS!/);

console.log('Twilio adapter checks passed');

import test from 'node:test';
import assert from 'node:assert/strict';
import { parseTelemetry, evaluateHighTds, rejectionRate, resolveRange } from '../src/lib/telemetry.js';
import { makeTopics, canPublish, canSubscribe } from '../src/lib/topics.js';
import { normalisePhone } from '../src/lib/http.js';
import { generateOtp, hashOtp, otpMatches } from '../src/lib/otp.js';

test('parseTelemetry accepts a normal payload and rounds values', () => {
  const r = parseTelemetry(Buffer.from('{"tds":42.36,"tdsIn":380,"temp":26.54,"fw":"1.0.3"}'));
  assert.deepEqual(r, { ok: true, reading: { tds: 42.4, tdsIn: 380, temp: 26.5, fw: '1.0.3' } });
});

test('parseTelemetry rejects bad payloads', () => {
  assert.equal(parseTelemetry('not json').ok, false);
  assert.equal(parseTelemetry('{"tds":"42"}').ok, false);
  assert.equal(parseTelemetry('{"tds":-1}').ok, false);
  assert.equal(parseTelemetry('{"temp":200}').ok, false);
  assert.equal(parseTelemetry('{"fw":"1.0"}').ok, false);
  assert.equal(parseTelemetry('[]').ok, false);
});

test('evaluateHighTds opens above limit and resolves only below 90%', () => {
  assert.equal(evaluateHighTds({ tds: 101, limit: 100, hasOpenAlert: false }), 'open');
  assert.equal(evaluateHighTds({ tds: 100, limit: 100, hasOpenAlert: false }), null);
  assert.equal(evaluateHighTds({ tds: 95, limit: 100, hasOpenAlert: true }), 'update');
  assert.equal(evaluateHighTds({ tds: 90, limit: 100, hasOpenAlert: true }), 'resolve');
  assert.equal(evaluateHighTds({ tds: undefined, limit: 100, hasOpenAlert: true }), null);
});

test('rejectionRate', () => {
  assert.equal(rejectionRate(380, 42), 89);
  assert.equal(rejectionRate(0, 42), null);
  assert.equal(rejectionRate(undefined, 42), null);
});

test('resolveRange falls back to 24h', () => {
  assert.equal(resolveRange('7d').key, '7d');
  assert.equal(resolveRange('1y').key, '24h');
});

test('topic permissions keep devices on their own topics', () => {
  const t = makeTopics('shuddham/devices/');
  assert.deepEqual(t.parse('shuddham/devices/SHD-1/telemetry'), { deviceId: 'SHD-1', kind: 'telemetry' });
  assert.equal(t.parse('shuddham/devices/SHD-1/telemetry/x'), null);
  assert.equal(canPublish(t, 'SHD-1', 'shuddham/devices/SHD-1/telemetry'), true);
  assert.equal(canPublish(t, 'SHD-1', 'shuddham/devices/SHD-2/telemetry'), false);
  assert.equal(canPublish(t, 'SHD-1', 'shuddham/devices/SHD-1/cmd'), false);
  assert.equal(canSubscribe(t, 'SHD-1', 'shuddham/devices/SHD-1/cmd'), true);
  assert.equal(canSubscribe(t, 'SHD-1', 'shuddham/devices/+/cmd'), false);
  assert.equal(canSubscribe(t, 'SHD-1', '#'), false);
});

test('normalisePhone', () => {
  assert.equal(normalisePhone('+91 98765-43210'), '9876543210');
  assert.equal(normalisePhone('09876543210'), '9876543210');
  assert.equal(normalisePhone('12345'), null);
  assert.equal(normalisePhone('5876543210'), null);
  assert.equal(normalisePhone(undefined), null);
});

test('OTP generate and match', () => {
  const code = generateOtp(6);
  assert.match(code, /^\d{6}$/);
  const h = hashOtp('9876543210', code);
  assert.equal(otpMatches('9876543210', code, h), true);
  assert.equal(otpMatches('9876543211', code, h), false);
});

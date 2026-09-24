import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../src/app.js';

// These checks don't need MongoDB: they cover validation and auth that run before any query.
const app = createApp({ logger: { error() {} } });

test('health responds', async () => {
  const res = await request(app).get('/health');
  assert.equal(res.status, 200);
  assert.equal(res.body.ok, true);
});

test('protected routes need a token', async () => {
  for (const path of ['/api/me', '/api/devices', '/api/admin/stats']) {
    const res = await request(app).get(path);
    assert.equal(res.status, 401, path);
    assert.equal(res.body.error.code, 'UNAUTHENTICATED');
  }
  const bad = await request(app).get('/api/devices').set('Authorization', 'Bearer nonsense');
  assert.equal(bad.body.error.code, 'INVALID_TOKEN');
});

test('OTP send validates the phone number', async () => {
  const res = await request(app).post('/api/auth/otp/send').send({ phone: '12345' });
  assert.equal(res.status, 400);
  assert.equal(res.body.error.code, 'INVALID_PHONE');
});

test('invalid JSON and unknown routes return JSON errors', async () => {
  const bad = await request(app).post('/api/auth/otp/send').set('content-type', 'application/json').send('{oops');
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error.code, 'INVALID_JSON');
  const nf = await request(app).get('/api/nope');
  assert.equal(nf.status, 404);
});

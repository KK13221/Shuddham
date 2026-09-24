import test from 'node:test';
import assert from 'node:assert/strict';
import mqtt from 'mqtt';
import { createMqttBroker } from '../src/mqtt.js';

const quiet = { info() {}, warn() {}, error() {} };
const PREFIX = 'shuddham/devices';

async function startBroker() {
  const events = { telemetry: [], status: [] };
  const broker = await createMqttBroker({
    port: 0,
    topicPrefix: PREFIX,
    logger: quiet,
    verifyDevice: async (id, secret) => id === 'SHD-TEST' && secret === 's3cret',
    onTelemetry: async (id, reading) => events.telemetry.push({ id, reading }),
    onStatus: async (id, online) => events.status.push({ id, online }),
  });
  return { broker, events };
}

function connect(port, opts) {
  return new Promise((resolve, reject) => {
    const c = mqtt.connect(`mqtt://127.0.0.1:${port}`, { reconnectPeriod: 0, connectTimeout: 3000, ...opts });
    c.once('connect', () => resolve(c));
    c.once('error', (e) => {
      c.end(true);
      reject(e);
    });
  });
}

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

test('device with correct secret connects, telemetry and status are delivered', async () => {
  const { broker, events } = await startBroker();
  try {
    const c = await connect(broker.port, { clientId: 'SHD-TEST', username: 'SHD-TEST', password: 's3cret' });
    c.publish(`${PREFIX}/SHD-TEST/status`, 'online', { qos: 1 });
    c.publish(`${PREFIX}/SHD-TEST/telemetry`, JSON.stringify({ tds: 42, temp: 26.5 }), { qos: 1 });
    c.publish(`${PREFIX}/SHD-TEST/telemetry`, 'garbage', { qos: 1 });
    await wait(200);
    assert.deepEqual(events.telemetry, [{ id: 'SHD-TEST', reading: { tds: 42, temp: 26.5 } }]);
    assert.deepEqual(events.status[0], { id: 'SHD-TEST', online: true });

    // Commands reach the device on its own topic.
    const got = new Promise((resolve) => c.on('message', (topic, msg) => resolve({ topic, msg: JSON.parse(msg) })));
    await new Promise((r) => c.subscribe(`${PREFIX}/SHD-TEST/cmd`, { qos: 1 }, r));
    broker.publishCommand('SHD-TEST', { cmd: 'identify' });
    const m = await got;
    assert.equal(m.topic, `${PREFIX}/SHD-TEST/cmd`);
    assert.equal(m.msg.cmd, 'identify');

    await new Promise((r) => c.end(false, r));
    await wait(100);
    assert.deepEqual(events.status.at(-1), { id: 'SHD-TEST', online: false });
  } finally {
    await broker.close();
  }
});

test('wrong secret or mismatched client id is refused', async () => {
  const { broker } = await startBroker();
  try {
    await assert.rejects(connect(broker.port, { clientId: 'SHD-TEST', username: 'SHD-TEST', password: 'nope' }));
    await assert.rejects(connect(broker.port, { clientId: 'OTHER', username: 'SHD-TEST', password: 's3cret' }));
  } finally {
    await broker.close();
  }
});

test('device cannot publish to another device’s topic', async () => {
  const { broker, events } = await startBroker();
  try {
    const c = await connect(broker.port, { clientId: 'SHD-TEST', username: 'SHD-TEST', password: 's3cret' });
    const closed = new Promise((r) => c.once('close', r));
    c.publish(`${PREFIX}/SHD-OTHER/telemetry`, JSON.stringify({ tds: 999 }), { qos: 0 });
    await Promise.race([closed, wait(1000)]);
    assert.equal(events.telemetry.length, 0);
    c.end(true);
  } finally {
    await broker.close();
  }
});

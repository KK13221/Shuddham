import net from 'node:net';
import tls from 'node:tls';
import fs from 'node:fs';
import { Aedes } from 'aedes';
import { makeTopics, canPublish, canSubscribe } from './lib/topics.js';
import { parseTelemetry } from './lib/telemetry.js';

/**
 * Embedded MQTT broker for the purifiers.
 * Devices log in with username = deviceId (also the MQTT client id) and password = device secret.
 *
 * Dependencies are injected so the broker can be tested without a database:
 *   verifyDevice(deviceId, secret) -> Promise<boolean>
 *   onTelemetry(deviceId, reading) -> Promise
 *   onStatus(deviceId, online) -> Promise
 */
export async function createMqttBroker({
  port,
  tlsPort,
  tlsKeyPath,
  tlsCertPath,
  topicPrefix,
  verifyDevice,
  onTelemetry,
  onStatus,
  logger = console,
}) {
  const topics = makeTopics(topicPrefix);
  const broker = await Aedes.createBroker({ drainTimeout: 30_000 });

  broker.authenticate = (client, username, password, cb) => {
    const deviceId = String(username || '');
    if (!deviceId || client.id !== deviceId || !password) {
      const err = new Error('bad credentials');
      err.returnCode = 4;
      return cb(err, false);
    }
    verifyDevice(deviceId, password.toString('utf8'))
      .then((ok) => {
        if (ok) client.deviceId = deviceId;
        cb(null, ok);
      })
      .catch((err) => {
        logger.error('[mqtt] auth error', err);
        cb(err, false);
      });
  };

  broker.authorizePublish = (client, packet, cb) => {
    if (!client) return cb(null); // broker-internal (e.g. stored LWT)
    if (packet.topic.startsWith('$SYS')) return cb(new Error('reserved topic'));
    if (!canPublish(topics, client.deviceId, packet.topic)) return cb(new Error('topic not allowed'));
    cb(null);
  };

  broker.authorizeSubscribe = (client, sub, cb) => {
    if (!canSubscribe(topics, client.deviceId, sub.topic)) return cb(new Error('subscription not allowed'));
    cb(null, sub);
  };

  broker.on('publish', (packet, client) => {
    const t = topics.parse(packet.topic);
    if (!t) return;
    // Messages from devices, plus LWT "offline" (client may be null or the dead client).
    if (t.kind === 'telemetry' && client) {
      const parsed = parseTelemetry(packet.payload);
      if (!parsed.ok) {
        logger.warn(`[mqtt] ${t.deviceId} bad telemetry: ${parsed.error}`);
        return;
      }
      Promise.resolve(onTelemetry(t.deviceId, parsed.reading)).catch((e) => logger.error('[mqtt] telemetry', e));
    } else if (t.kind === 'status') {
      const online = packet.payload.toString() === 'online';
      Promise.resolve(onStatus(t.deviceId, online)).catch((e) => logger.error('[mqtt] status', e));
    }
  });

  broker.on('clientDisconnect', (client) => {
    if (client.deviceId) {
      Promise.resolve(onStatus(client.deviceId, false)).catch((e) => logger.error('[mqtt] disconnect', e));
    }
  });

  const servers = [];
  const tcp = net.createServer(broker.handle);
  await new Promise((resolve) => tcp.listen(port, resolve));
  servers.push(tcp);
  logger.info(`[mqtt] listening on ${tcp.address().port}`);

  if (tlsKeyPath && tlsCertPath) {
    const secure = tls.createServer(
      { key: fs.readFileSync(tlsKeyPath), cert: fs.readFileSync(tlsCertPath) },
      broker.handle,
    );
    await new Promise((resolve) => secure.listen(tlsPort, resolve));
    servers.push(secure);
    logger.info(`[mqtt] TLS listening on ${tlsPort}`);
  }

  function publishCommand(deviceId, payload) {
    broker.publish(
      { topic: topics.cmd(deviceId), payload: Buffer.from(JSON.stringify(payload)), qos: 1, retain: false },
      () => {},
    );
  }

  async function close() {
    await Promise.all(servers.map((s) => new Promise((r) => s.close(() => r()))));
    await new Promise((r) => broker.close(() => r()));
  }

  return { broker, publishCommand, close, port: tcp.address().port, topics };
}

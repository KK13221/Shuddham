import http from 'node:http';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import { config } from './config.js';
import { createApp } from './app.js';
import { createRealtime } from './realtime.js';
import { createMqttBroker } from './mqtt.js';
import { Device } from './models/Device.js';
import {
  initDeviceService,
  handleTelemetry,
  setDeviceOnline,
  setCommandPublisher,
  startOfflineSweeper,
} from './services/deviceService.js';

const logger = console;

async function main() {
  await mongoose.connect(config.mongoUri);
  await mongoose.syncIndexes();
  logger.info('[db] connected');

  const app = createApp({ logger });
  const server = http.createServer(app);
  const realtime = createRealtime(server, { logger });
  initDeviceService({ realtime, logger });

  const mqtt = await createMqttBroker({
    ...config.mqtt,
    port: config.mqtt.port,
    logger,
    async verifyDevice(deviceId, secret) {
      const device = await Device.findOne({ deviceId }).select('+secretHash');
      return !!device && bcrypt.compare(secret, device.secretHash);
    },
    onTelemetry: handleTelemetry,
    onStatus: setDeviceOnline,
  });
  setCommandPublisher(mqtt.publishCommand);
  const stopSweeper = startOfflineSweeper();

  await new Promise((resolve) => server.listen(config.port, resolve));
  logger.info(`[http] listening on ${config.port}`);

  const shutdown = async (signal) => {
    logger.info(`[server] ${signal}, shutting down`);
    stopSweeper();
    server.close();
    await mqtt.close();
    await mongoose.disconnect();
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  logger.error('[server] failed to start', err);
  process.exit(1);
});

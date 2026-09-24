import { config } from '../config.js';
import { Device } from '../models/Device.js';
import { Reading } from '../models/Reading.js';
import { Alert } from '../models/Alert.js';
import { evaluateHighTds } from '../lib/telemetry.js';
import { nullRealtime } from '../realtime.js';

let realtime = nullRealtime;
let publisher = null; // (deviceId, payloadObject) => void, set by the MQTT broker
let log = console;

export function initDeviceService({ realtime: rt, logger } = {}) {
  if (rt) realtime = rt;
  if (logger) log = logger;
}

export function setCommandPublisher(fn) {
  publisher = fn;
}

export function sendCommand(deviceId, cmd, extra = {}) {
  if (!publisher) throw new Error('MQTT broker not running');
  publisher(deviceId, { cmd, ...extra, at: new Date().toISOString() });
}

const ownerOf = (device) => (device.owner ? device.owner.toString() : null);

async function openAlert(device, fields) {
  try {
    const alert = await Alert.create({
      device: device._id,
      deviceId: device.deviceId,
      owner: device.owner,
      ...fields,
    });
    realtime.emitDevice(ownerOf(device), 'alert', { action: 'open', alert });
    return alert;
  } catch (err) {
    if (err.code === 11000) return null; // already open (race between two messages)
    throw err;
  }
}

async function resolveAlert(device, type) {
  const alert = await Alert.findOneAndUpdate(
    { device: device._id, type, status: 'open' },
    { status: 'resolved', resolvedAt: new Date() },
    { new: true },
  );
  if (alert) realtime.emitDevice(ownerOf(device), 'alert', { action: 'resolve', alert });
  return alert;
}

/** Called for every telemetry message that passed validation. */
export async function handleTelemetry(deviceId, reading, now = new Date()) {
  const device = await Device.findOne({ deviceId });
  if (!device) return null;

  const wasOffline = !device.online;
  const lastAt = device.lastReading?.at?.getTime?.() ?? 0;
  const storeReading = now.getTime() - lastAt >= config.device.minReadingIntervalSeconds * 1000;

  const { fw, ...values } = reading;
  device.lastSeen = now;
  device.online = true;
  device.lastReading = { ...values, at: now };
  if (fw) device.firmware = fw;
  await device.save();

  if (storeReading) await Reading.create({ ts: now, deviceId, ...values });
  if (wasOffline) {
    await resolveAlert(device, 'offline');
    realtime.emitDevice(ownerOf(device), 'device:status', { deviceId, online: true, at: now });
  }

  if (typeof values.tds === 'number') {
    const limit = device.tdsLimit ?? config.device.defaultTdsLimit;
    const open = await Alert.findOne({ device: device._id, type: 'high_tds', status: 'open' });
    const action = evaluateHighTds({ tds: values.tds, limit, hasOpenAlert: !!open });
    if (action === 'open') await openAlert(device, { type: 'high_tds', value: values.tds, peak: values.tds, limit });
    else if (action === 'resolve') await resolveAlert(device, 'high_tds');
    else if (action === 'update' && values.tds > (open.peak ?? 0)) {
      open.peak = values.tds;
      await open.save();
    }
  }

  realtime.emitDevice(ownerOf(device), 'reading', { deviceId, ...values, at: now });
  return device;
}

export async function setDeviceOnline(deviceId, online, now = new Date()) {
  const device = await Device.findOne({ deviceId });
  if (!device || device.online === online) return device;
  device.online = online;
  if (online) device.lastSeen = now;
  await device.save();

  if (online) await resolveAlert(device, 'offline');
  else if (device.owner) await openAlert(device, { type: 'offline' });

  realtime.emitDevice(ownerOf(device), 'device:status', { deviceId, online, at: now });
  log.info(`[device] ${deviceId} ${online ? 'online' : 'offline'}`);
  return device;
}

/** Marks devices offline when they stop reporting without a clean MQTT disconnect. */
export async function sweepOfflineDevices(now = new Date()) {
  const cutoff = new Date(now.getTime() - config.device.offlineAfterSeconds * 1000);
  const stale = await Device.find({ online: true, lastSeen: { $lt: cutoff } }).select('deviceId');
  for (const d of stale) await setDeviceOnline(d.deviceId, false, now);
  return stale.length;
}

export function startOfflineSweeper(intervalMs = 30_000) {
  const timer = setInterval(() => {
    sweepOfflineDevices().catch((err) => log.error('[sweeper]', err));
  }, intervalMs);
  timer.unref();
  return () => clearInterval(timer);
}

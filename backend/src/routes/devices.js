import { Router } from 'express';
import bcrypt from 'bcryptjs';
import mongoose from 'mongoose';
import { Device } from '../models/Device.js';
import { Alert } from '../models/Alert.js';
import { requireAuth } from '../middleware/auth.js';
import { HttpError, badRequest, notFound, pick } from '../lib/http.js';
import { getHistory } from '../services/readingsService.js';
import { sendCommand } from '../services/deviceService.js';

export const devicesRouter = Router();
devicesRouter.use(requireAuth);

async function ownDevice(req) {
  const { id } = req.params;
  const query = mongoose.isValidObjectId(id) ? { _id: id } : { deviceId: String(id).toUpperCase() };
  const device = await Device.findOne({ ...query, owner: req.auth.userId });
  if (!device) throw notFound('DEVICE_NOT_FOUND');
  return device;
}

/** GET /api/devices – the user's purifiers, attention-needed first. */
devicesRouter.get('/', async (req, res) => {
  const devices = await Device.find({ owner: req.auth.userId }).sort({ online: 1, name: 1 });
  const openAlerts = await Alert.find({ owner: req.auth.userId, status: 'open' }).select('device type');
  const byDevice = new Map();
  for (const a of openAlerts) {
    const k = a.device.toString();
    byDevice.set(k, [...(byDevice.get(k) || []), a.type]);
  }
  res.json({
    devices: devices.map((d) => ({ ...d.toPublic(), openAlerts: byDevice.get(d._id.toString()) || [] })),
  });
});

/**
 * POST /api/devices/claim  { deviceId, pop }
 * Called by the app right before Bluetooth provisioning. The setup code (pop) from the
 * purifier's label proves the user has the device in hand.
 */
devicesRouter.post('/claim', async (req, res) => {
  const deviceId = String(req.body?.deviceId || '').toUpperCase().trim();
  const pop = String(req.body?.pop || '').trim();
  if (!deviceId || !pop) throw badRequest('INVALID_INPUT');

  const device = await Device.findOne({ deviceId }).select('+popHash');
  // Same error for "unknown device" and "wrong code" so IDs can't be probed.
  if (!device || !(await bcrypt.compare(pop, device.popHash))) {
    throw badRequest('INVALID_SETUP_CODE', 'Setup code doesn’t match this purifier');
  }
  if (device.owner && device.owner.toString() !== req.auth.userId) {
    throw new HttpError(409, 'ALREADY_CLAIMED', 'This purifier is linked to another account. Ask the owner to remove it first.');
  }
  if (!device.owner) {
    device.owner = req.auth.userId;
    device.claimedAt = new Date();
    await device.save();
  }
  res.json({ device: device.toPublic() });
});

devicesRouter.get('/:id', async (req, res) => {
  const device = await ownDevice(req);
  const openAlerts = await Alert.find({ device: device._id, status: 'open' });
  res.json({ device: device.toPublic(), openAlerts });
});

/** PATCH /api/devices/:id  { name?, room?, tdsLimit? } */
devicesRouter.patch('/:id', async (req, res) => {
  const device = await ownDevice(req);
  const b = pick(req.body || {}, ['name', 'room', 'tdsLimit']);
  if (b.name !== undefined) {
    if (typeof b.name !== 'string' || !b.name.trim() || b.name.length > 60) throw badRequest('INVALID_NAME');
    device.name = b.name.trim();
  }
  if (b.room !== undefined) {
    if (typeof b.room !== 'string' || b.room.length > 40) throw badRequest('INVALID_ROOM');
    device.room = b.room.trim();
  }
  if (b.tdsLimit !== undefined) {
    if (b.tdsLimit !== null && (typeof b.tdsLimit !== 'number' || b.tdsLimit < 10 || b.tdsLimit > 2000)) {
      throw badRequest('INVALID_TDS_LIMIT', 'Limit must be between 10 and 2000 ppm');
    }
    device.tdsLimit = b.tdsLimit ?? undefined;
  }
  await device.save();
  res.json({ device: device.toPublic() });
});

/** DELETE /api/devices/:id – unlink from this account and tell the purifier to forget its Wi-Fi. */
devicesRouter.delete('/:id', async (req, res) => {
  const device = await ownDevice(req);
  device.owner = null;
  device.claimedAt = undefined;
  device.name = 'My purifier';
  device.room = '';
  await device.save();
  await Alert.updateMany({ device: device._id, status: 'open' }, { status: 'resolved', resolvedAt: new Date() });
  try {
    sendCommand(device.deviceId, 'factory_reset');
  } catch {
    /* broker not running in some environments; the unlink still stands */
  }
  res.json({ ok: true });
});

/** GET /api/devices/:id/readings?range=24h|7d|30d */
devicesRouter.get('/:id/readings', async (req, res) => {
  const device = await ownDevice(req);
  res.json(await getHistory(device.deviceId, String(req.query.range || '24h')));
});

/** POST /api/devices/:id/identify – purifier beeps and blinks. */
devicesRouter.post('/:id/identify', async (req, res) => {
  const device = await ownDevice(req);
  if (!device.online) throw new HttpError(409, 'DEVICE_OFFLINE', 'Purifier is offline');
  sendCommand(device.deviceId, 'identify');
  res.json({ ok: true });
});

/** GET /api/devices/:id/alerts */
devicesRouter.get('/:id/alerts', async (req, res) => {
  const device = await ownDevice(req);
  const alerts = await Alert.find({ device: device._id }).sort({ openedAt: -1 }).limit(50);
  res.json({ alerts });
});

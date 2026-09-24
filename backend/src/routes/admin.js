import { Router } from 'express';
import crypto from 'node:crypto';
import bcrypt from 'bcryptjs';
import mongoose from 'mongoose';
import { Device } from '../models/Device.js';
import { Alert } from '../models/Alert.js';
import { User } from '../models/User.js';
import { requireAuth, requireAdmin } from '../middleware/auth.js';
import { HttpError, badRequest, notFound, escapeRegex } from '../lib/http.js';
import { getHistory } from '../services/readingsService.js';
import { config } from '../config.js';

export const adminRouter = Router();
adminRouter.use(requireAuth, requireAdmin);

async function findDevice(id) {
  const query = mongoose.isValidObjectId(id) ? { _id: id } : { deviceId: String(id).toUpperCase() };
  const device = await Device.findOne(query).populate('owner', 'name phone');
  if (!device) throw notFound('DEVICE_NOT_FOUND');
  return device;
}

/** GET /api/admin/stats */
adminRouter.get('/stats', async (_req, res) => {
  const [devices, online, offline, claimed, users, openHighTds, openOffline] = await Promise.all([
    Device.countDocuments(),
    Device.countDocuments({ online: true }),
    Device.countDocuments({ online: false, owner: { $ne: null } }),
    Device.countDocuments({ owner: { $ne: null } }),
    User.countDocuments({ role: 'user' }),
    Alert.countDocuments({ status: 'open', type: 'high_tds' }),
    Alert.countDocuments({ status: 'open', type: 'offline' }),
  ]);
  res.json({ devices, online, offline, claimed, users, openAlerts: { highTds: openHighTds, offline: openOffline } });
});

/** GET /api/admin/devices?search=&status=online|offline|alert|unclaimed&page=1&limit=50 */
adminRouter.get('/devices', async (req, res) => {
  const page = Math.max(1, Number(req.query.page) || 1);
  const limit = Math.min(200, Math.max(1, Number(req.query.limit) || 50));
  const filter = {};

  const search = String(req.query.search || '').trim();
  if (search) {
    const re = new RegExp(escapeRegex(search), 'i');
    const owners = await User.find({ $or: [{ name: re }, { phone: re }] }).select('_id').limit(200);
    filter.$or = [{ deviceId: re }, { name: re }, { owner: { $in: owners.map((o) => o._id) } }];
  }
  const status = String(req.query.status || '');
  if (status === 'online') filter.online = true;
  if (status === 'offline') Object.assign(filter, { online: false, owner: { $ne: null } });
  if (status === 'unclaimed') filter.owner = null;
  if (status === 'alert') {
    const ids = await Alert.distinct('device', { status: 'open' });
    filter._id = { $in: ids };
  }

  const [items, total] = await Promise.all([
    Device.find(filter).populate('owner', 'name phone').sort({ online: 1, updatedAt: -1 }).skip((page - 1) * limit).limit(limit),
    Device.countDocuments(filter),
  ]);
  const open = await Alert.find({ device: { $in: items.map((d) => d._id) }, status: 'open' }).select('device type');
  const byDevice = new Map();
  for (const a of open) {
    const k = a.device.toString();
    byDevice.set(k, [...(byDevice.get(k) || []), a.type]);
  }
  res.json({
    total,
    page,
    limit,
    devices: items.map((d) => ({ ...d.toPublic({ admin: true }), openAlerts: byDevice.get(d._id.toString()) || [] })),
  });
});

/**
 * POST /api/admin/devices  { deviceId }
 * Factory registration. Returns the MQTT secret and the setup code ONCE – flash the secret
 * into the firmware and print the setup code on the label / QR sticker.
 */
adminRouter.post('/devices', async (req, res) => {
  const deviceId = String(req.body?.deviceId || '').toUpperCase().trim();
  if (!/^[A-Z0-9-]{4,32}$/.test(deviceId)) throw badRequest('INVALID_DEVICE_ID', 'Use 4–32 characters: A–Z, 0–9, dash');
  if (await Device.exists({ deviceId })) throw new HttpError(409, 'DEVICE_EXISTS');

  const secret = crypto.randomBytes(24).toString('base64url');
  const pop = crypto.randomInt(0, 1e8).toString().padStart(8, '0');
  const device = await Device.create({
    deviceId,
    secretHash: await bcrypt.hash(secret, 10),
    popHash: await bcrypt.hash(pop, 10),
  });
  res.status(201).json({ device: device.toPublic({ admin: true }), secret, setupCode: pop });
});

adminRouter.get('/devices/:id', async (req, res) => {
  const device = await findDevice(req.params.id);
  const alerts = await Alert.find({ device: device._id }).sort({ openedAt: -1 }).limit(20);
  res.json({ device: device.toPublic({ admin: true }), alerts, defaultTdsLimit: config.device.defaultTdsLimit });
});

adminRouter.get('/devices/:id/readings', async (req, res) => {
  const device = await findDevice(req.params.id);
  res.json(await getHistory(device.deviceId, String(req.query.range || '24h')));
});

/** GET /api/admin/alerts?status=open|resolved&type=high_tds|offline&page=1 */
adminRouter.get('/alerts', async (req, res) => {
  const page = Math.max(1, Number(req.query.page) || 1);
  const limit = 50;
  const filter = {};
  if (['open', 'resolved'].includes(req.query.status)) filter.status = req.query.status;
  if (['high_tds', 'offline'].includes(req.query.type)) filter.type = req.query.type;
  const [alerts, total] = await Promise.all([
    Alert.find(filter)
      .populate('owner', 'name phone')
      .populate('device', 'name deviceId room')
      .sort({ status: 1, openedAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    Alert.countDocuments(filter),
  ]);
  res.json({ total, page, limit, alerts });
});

adminRouter.post('/alerts/:id/ack', async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) throw notFound('ALERT_NOT_FOUND');
  const alert = await Alert.findByIdAndUpdate(
    req.params.id,
    { acknowledged: true, acknowledgedBy: req.auth.userId },
    { new: true },
  );
  if (!alert) throw notFound('ALERT_NOT_FOUND');
  res.json({ alert });
});

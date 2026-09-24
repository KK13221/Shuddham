import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { User } from '../models/User.js';
import { requireAuth } from '../middleware/auth.js';
import { HttpError, badRequest, notFound, EMAIL_RE, PINCODE_RE } from '../lib/http.js';

export const meRouter = Router();
meRouter.use(requireAuth);

meRouter.get('/', async (req, res) => {
  const user = await User.findById(req.auth.userId);
  if (!user) throw notFound('USER_NOT_FOUND');
  res.json({ user: user.toPublic() });
});

/** PATCH /api/me  { name?, email?, pincode?, prefs?: { highTdsAlerts, offlineAlerts, tempUnit } } */
meRouter.patch('/', async (req, res) => {
  const user = await User.findById(req.auth.userId);
  if (!user) throw notFound('USER_NOT_FOUND');
  const b = req.body || {};

  if (b.name !== undefined) {
    if (typeof b.name !== 'string' || !b.name.trim()) throw badRequest('INVALID_NAME');
    user.name = b.name.trim();
  }
  if (b.email !== undefined) {
    if (b.email && !EMAIL_RE.test(b.email)) throw badRequest('INVALID_EMAIL');
    const email = b.email ? b.email.toLowerCase() : undefined;
    if (email && (await User.exists({ email, _id: { $ne: user._id } }))) throw new HttpError(409, 'EMAIL_TAKEN');
    user.email = email;
  }
  if (b.pincode !== undefined) {
    if (b.pincode && !PINCODE_RE.test(b.pincode)) throw badRequest('INVALID_PINCODE');
    user.pincode = b.pincode || undefined;
  }
  if (b.prefs && typeof b.prefs === 'object') {
    for (const k of ['highTdsAlerts', 'offlineAlerts']) if (typeof b.prefs[k] === 'boolean') user.prefs[k] = b.prefs[k];
    if (['C', 'F'].includes(b.prefs.tempUnit)) user.prefs.tempUnit = b.prefs.tempUnit;
  }
  await user.save();
  res.json({ user: user.toPublic() });
});

/** PUT /api/me/password  { password } – enables email login. Requires an email on the account. */
meRouter.put('/password', async (req, res) => {
  const password = String(req.body?.password || '');
  if (password.length < 8) throw badRequest('WEAK_PASSWORD', 'Use at least 8 characters');
  const user = await User.findById(req.auth.userId);
  if (!user) throw notFound('USER_NOT_FOUND');
  if (!user.email) throw badRequest('EMAIL_REQUIRED', 'Add an email to your profile first');
  user.passwordHash = await bcrypt.hash(password, 12);
  await user.save();
  res.json({ ok: true });
});

/** POST /api/me/push-token  { token } – Firebase Cloud Messaging token for push alerts. */
meRouter.post('/push-token', async (req, res) => {
  const token = String(req.body?.token || '');
  if (!token || token.length > 4096) throw badRequest('INVALID_TOKEN');
  await User.updateOne({ _id: req.auth.userId }, { $addToSet: { fcmTokens: token } });
  res.json({ ok: true });
});

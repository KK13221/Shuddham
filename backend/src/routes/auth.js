import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import bcrypt from 'bcryptjs';
import { config } from '../config.js';
import { User } from '../models/User.js';
import { Otp } from '../models/Otp.js';
import { generateOtp, hashOtp, otpMatches, sendOtpSms } from '../lib/otp.js';
import { signToken } from '../middleware/auth.js';
import { HttpError, badRequest, normalisePhone, EMAIL_RE, PINCODE_RE } from '../lib/http.js';

export const authRouter = Router();

const otpLimiter = rateLimit({ windowMs: 15 * 60e3, limit: 10, standardHeaders: true, legacyHeaders: false });
const loginLimiter = rateLimit({ windowMs: 15 * 60e3, limit: 20, standardHeaders: true, legacyHeaders: false });

function session(user) {
  return { token: signToken(user), user: user.toPublic() };
}

/**
 * POST /api/auth/otp/send  { phone, purpose: "login" | "signup" }
 * login: phone must belong to an account. signup: phone must be new.
 */
authRouter.post('/otp/send', otpLimiter, async (req, res) => {
  const phone = normalisePhone(req.body?.phone);
  if (!phone) throw badRequest('INVALID_PHONE', 'Enter a valid 10-digit mobile number');
  const purpose = req.body?.purpose === 'signup' ? 'signup' : 'login';

  const exists = await User.exists({ phone });
  if (purpose === 'login' && !exists) throw new HttpError(404, 'USER_NOT_FOUND', 'No account with this number. Please sign up.');
  if (purpose === 'signup' && exists) throw new HttpError(409, 'PHONE_TAKEN', 'This number already has an account. Please log in.');

  const existing = await Otp.findOne({ phone });
  if (existing && Date.now() - existing.sentAt.getTime() < config.otp.resendCooldownSeconds * 1000) {
    throw new HttpError(429, 'OTP_COOLDOWN', `Please wait ${config.otp.resendCooldownSeconds} seconds before requesting another OTP`);
  }

  const code = generateOtp();
  await Otp.findOneAndUpdate(
    { phone },
    {
      codeHash: hashOtp(phone, code),
      attempts: 0,
      sentAt: new Date(),
      expiresAt: new Date(Date.now() + config.otp.ttlSeconds * 1000),
    },
    { upsert: true },
  );
  await sendOtpSms(phone, code);
  res.json({ sent: true, expiresIn: config.otp.ttlSeconds, resendIn: config.otp.resendCooldownSeconds });
});

/**
 * POST /api/auth/otp/verify  { phone, code, profile?: { name, email, pincode } }
 * Logs in an existing user, or creates the account when profile is given (sign up).
 */
authRouter.post('/otp/verify', loginLimiter, async (req, res) => {
  const phone = normalisePhone(req.body?.phone);
  const code = String(req.body?.code || '');
  if (!phone || !/^\d{4,8}$/.test(code)) throw badRequest('INVALID_INPUT');

  const otp = await Otp.findOne({ phone });
  if (!otp || otp.expiresAt < new Date()) throw badRequest('OTP_EXPIRED', 'OTP expired. Request a new one.');
  if (otp.attempts >= config.otp.maxAttempts) throw new HttpError(429, 'OTP_LOCKED', 'Too many wrong attempts. Request a new OTP.');
  if (!otpMatches(phone, code, otp.codeHash)) {
    otp.attempts += 1;
    await otp.save();
    throw badRequest('OTP_WRONG', `Wrong OTP. ${config.otp.maxAttempts - otp.attempts} attempts left.`);
  }

  let user = await User.findOne({ phone });
  if (!user) {
    const p = req.body?.profile || {};
    const name = typeof p.name === 'string' ? p.name.trim() : '';
    if (!name) throw new HttpError(404, 'USER_NOT_FOUND', 'No account with this number. Please sign up.');
    if (p.email && !EMAIL_RE.test(p.email)) throw badRequest('INVALID_EMAIL');
    if (p.pincode && !PINCODE_RE.test(p.pincode)) throw badRequest('INVALID_PINCODE');
    if (p.email && (await User.exists({ email: p.email.toLowerCase() }))) throw new HttpError(409, 'EMAIL_TAKEN');
    user = await User.create({ name, phone, email: p.email || undefined, pincode: p.pincode || undefined });
  }

  await Otp.deleteOne({ _id: otp._id });
  user.lastLoginAt = new Date();
  await user.save();
  res.json(session(user));
});

/** POST /api/auth/email/login  { email, password } – for users who set a password in Profile. */
authRouter.post('/email/login', loginLimiter, async (req, res) => {
  const email = String(req.body?.email || '').toLowerCase().trim();
  const password = String(req.body?.password || '');
  const user = await User.findOne({ email, role: 'user' }).select('+passwordHash');
  const ok = user?.passwordHash && (await bcrypt.compare(password, user.passwordHash));
  if (!ok) throw new HttpError(401, 'BAD_CREDENTIALS', 'Email or password is incorrect');
  user.lastLoginAt = new Date();
  await user.save();
  res.json(session(user));
});

/** POST /api/auth/admin/login  { email, password } */
authRouter.post('/admin/login', loginLimiter, async (req, res) => {
  const email = String(req.body?.email || '').toLowerCase().trim();
  const password = String(req.body?.password || '');
  const user = await User.findOne({ email, role: 'admin' }).select('+passwordHash');
  const ok = user?.passwordHash && (await bcrypt.compare(password, user.passwordHash));
  if (!ok) throw new HttpError(401, 'BAD_CREDENTIALS', 'Email or password is incorrect');
  user.lastLoginAt = new Date();
  await user.save();
  res.json(session(user));
});

import crypto from 'node:crypto';
import { config } from '../config.js';

export function generateOtp(length = config.otp.length) {
  const max = 10 ** length;
  return String(crypto.randomInt(0, max)).padStart(length, '0');
}

export function hashOtp(phone, code) {
  return crypto.createHmac('sha256', config.jwtSecret).update(`${phone}:${code}`).digest('hex');
}

export function otpMatches(phone, code, hash) {
  const a = Buffer.from(hashOtp(phone, String(code)), 'hex');
  const b = Buffer.from(hash, 'hex');
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

/**
 * Send the OTP through MSG91 (Indian SMS; needs a DLT-approved template with an ##OTP## variable).
 * Without MSG91 keys in development, the code is printed to the log instead.
 */
export async function sendOtpSms(phone, code, { fetchImpl = fetch, logger = console } = {}) {
  if (config.otp.devLogOtp) {
    logger.info(`[otp] DEV MODE – OTP for ${phone}: ${code}`);
    return;
  }
  if (!config.otp.msg91AuthKey || !config.otp.msg91TemplateId) {
    throw new Error('MSG91_AUTH_KEY and MSG91_TEMPLATE_ID must be set');
  }
  const url = new URL('https://control.msg91.com/api/v5/otp');
  url.searchParams.set('template_id', config.otp.msg91TemplateId);
  url.searchParams.set('mobile', `91${phone}`);
  url.searchParams.set('otp', code);
  url.searchParams.set('otp_expiry', String(Math.ceil(config.otp.ttlSeconds / 60)));

  const res = await fetchImpl(url, {
    method: 'POST',
    headers: { authkey: config.otp.msg91AuthKey, 'content-type': 'application/json' },
    body: '{}',
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || body.type === 'error') {
    throw new Error(`MSG91 send failed: ${body.message || res.status}`);
  }
}

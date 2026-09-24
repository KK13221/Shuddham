export class HttpError extends Error {
  constructor(status, code, message) {
    super(message || code);
    this.status = status;
    this.code = code;
  }
}

export const badRequest = (code, msg) => new HttpError(400, code, msg);
export const notFound = (code = 'NOT_FOUND', msg) => new HttpError(404, code, msg);
export const forbidden = (code = 'FORBIDDEN', msg) => new HttpError(403, code, msg);

export const PHONE_RE = /^[6-9]\d{9}$/;
export const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
export const PINCODE_RE = /^\d{6}$/;

/** Normalise "+91 98765-43210" -> "9876543210". Returns null if not a valid Indian mobile. */
export function normalisePhone(input) {
  if (typeof input !== 'string') return null;
  let digits = input.replace(/\D/g, '');
  if (digits.length === 12 && digits.startsWith('91')) digits = digits.slice(2);
  if (digits.length === 11 && digits.startsWith('0')) digits = digits.slice(1);
  return PHONE_RE.test(digits) ? digits : null;
}

export function pick(obj, keys) {
  const out = {};
  for (const k of keys) if (obj && obj[k] !== undefined) out[k] = obj[k];
  return out;
}

export function escapeRegex(s) {
  return String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

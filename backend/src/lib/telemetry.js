// Pure functions for device telemetry. No database access here, so they are easy to test.

const LIMITS = {
  tds: [0, 5000], // ppm
  tdsIn: [0, 5000],
  temp: [-5, 90], // °C
};

/**
 * Parse and validate a telemetry payload from a purifier.
 * Expected JSON: {"tds": 42, "tdsIn": 380, "temp": 26.5, "fw": "1.0.3"}
 * Returns { ok: true, reading } or { ok: false, error }.
 */
export function parseTelemetry(buf) {
  let data;
  try {
    data = JSON.parse(Buffer.isBuffer(buf) ? buf.toString('utf8') : String(buf));
  } catch {
    return { ok: false, error: 'invalid JSON' };
  }
  if (!data || typeof data !== 'object') return { ok: false, error: 'payload must be an object' };

  const reading = {};
  for (const [key, [min, max]] of Object.entries(LIMITS)) {
    const v = data[key];
    if (v === undefined || v === null) continue;
    if (typeof v !== 'number' || !Number.isFinite(v)) return { ok: false, error: `${key} must be a number` };
    if (v < min || v > max) return { ok: false, error: `${key} out of range` };
    reading[key] = Math.round(v * 10) / 10;
  }
  if (reading.tds === undefined && reading.temp === undefined) {
    return { ok: false, error: 'tds or temp required' };
  }
  if (typeof data.fw === 'string' && data.fw.length <= 32) reading.fw = data.fw;
  return { ok: true, reading };
}

/**
 * Decide what to do with the high-TDS alert for a new reading.
 * Opens above the limit; resolves only once TDS falls below 90% of the limit,
 * so a value hovering around the limit doesn't open/close alerts every few seconds.
 * @returns 'open' | 'resolve' | 'update' | null
 */
export function evaluateHighTds({ tds, limit, hasOpenAlert, hysteresis = 0.9 }) {
  if (typeof tds !== 'number' || typeof limit !== 'number') return null;
  if (!hasOpenAlert && tds > limit) return 'open';
  if (hasOpenAlert && tds <= limit * hysteresis) return 'resolve';
  if (hasOpenAlert) return 'update';
  return null;
}

/** Removal percentage from inlet to purified TDS, or null when unknown. */
export function rejectionRate(tdsIn, tds) {
  if (typeof tdsIn !== 'number' || typeof tds !== 'number' || tdsIn <= 0) return null;
  return Math.max(0, Math.min(100, Math.round((1 - tds / tdsIn) * 100)));
}

const RANGES = {
  '24h': { ms: 24 * 3600e3, bucketMs: 15 * 60e3 },
  '7d': { ms: 7 * 24 * 3600e3, bucketMs: 2 * 3600e3 },
  '30d': { ms: 30 * 24 * 3600e3, bucketMs: 6 * 3600e3 },
};

export function resolveRange(range) {
  return RANGES[range] ? { key: range, ...RANGES[range] } : { key: '24h', ...RANGES['24h'] };
}

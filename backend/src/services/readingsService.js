import { Reading } from '../models/Reading.js';
import { resolveRange } from '../lib/telemetry.js';

/**
 * Averaged history for charts: 24h -> 15-min buckets, 7d -> 2-h, 30d -> 6-h.
 * Returns { range, points: [{ t, tds, tdsIn, temp, maxTds }] }.
 */
export async function getHistory(deviceId, rangeKey, now = new Date()) {
  const range = resolveRange(rangeKey);
  const from = new Date(now.getTime() - range.ms);
  const rows = await Reading.aggregate([
    { $match: { deviceId, ts: { $gte: from, $lte: now } } },
    {
      $group: {
        _id: { $dateTrunc: { date: '$ts', unit: 'millisecond', binSize: range.bucketMs } },
        tds: { $avg: '$tds' },
        tdsIn: { $avg: '$tdsIn' },
        temp: { $avg: '$temp' },
        maxTds: { $max: '$tds' },
      },
    },
    { $sort: { _id: 1 } },
  ]);
  const round = (v) => (typeof v === 'number' ? Math.round(v * 10) / 10 : null);
  return {
    range: range.key,
    from,
    to: now,
    points: rows.map((r) => ({
      t: r._id,
      tds: round(r.tds),
      tdsIn: round(r.tdsIn),
      temp: round(r.temp),
      maxTds: round(r.maxTds),
    })),
  };
}

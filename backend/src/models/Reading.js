import mongoose from 'mongoose';
import { config } from '../config.js';

// Time-series collection: one document per telemetry message.
const readingSchema = new mongoose.Schema(
  {
    ts: { type: Date, required: true },
    deviceId: { type: String, required: true },
    tds: Number, // purified water, ppm
    tdsIn: Number, // inlet water, ppm (only if the hardware has an inlet sensor)
    temp: Number, // water temperature, °C
  },
  {
    timeseries: { timeField: 'ts', metaField: 'deviceId', granularity: 'seconds' },
    expireAfterSeconds: config.device.readingRetentionDays * 24 * 3600,
    versionKey: false,
  },
);

readingSchema.index({ deviceId: 1, ts: -1 });

export const Reading = mongoose.model('Reading', readingSchema);

import mongoose from 'mongoose';

const alertSchema = new mongoose.Schema(
  {
    device: { type: mongoose.Schema.Types.ObjectId, ref: 'Device', required: true, index: true },
    deviceId: { type: String, required: true },
    owner: { type: mongoose.Schema.Types.ObjectId, ref: 'User', index: true },
    type: { type: String, enum: ['high_tds', 'offline'], required: true },
    status: { type: String, enum: ['open', 'resolved'], default: 'open', index: true },
    value: Number, // TDS that triggered it
    peak: Number, // highest TDS while open
    limit: Number,
    acknowledged: { type: Boolean, default: false },
    acknowledgedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    openedAt: { type: Date, default: Date.now },
    resolvedAt: Date,
  },
  { timestamps: true },
);

// At most one open alert of each type per device.
alertSchema.index(
  { device: 1, type: 1 },
  { unique: true, partialFilterExpression: { status: 'open' } },
);

export const Alert = mongoose.model('Alert', alertSchema);

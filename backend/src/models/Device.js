import mongoose from 'mongoose';

// A purifier. Registered at the factory (deviceId + secret + setup code),
// then claimed by a user in the app during Bluetooth provisioning.
const deviceSchema = new mongoose.Schema(
  {
    deviceId: { type: String, required: true, unique: true, match: /^[A-Z0-9-]{4,32}$/ },
    secretHash: { type: String, required: true, select: false }, // MQTT password
    popHash: { type: String, required: true, select: false }, // setup code printed on the label
    owner: { type: mongoose.Schema.Types.ObjectId, ref: 'User', index: true, default: null },
    name: { type: String, trim: true, maxlength: 60, default: 'My purifier' },
    room: { type: String, trim: true, maxlength: 40, default: '' },
    tdsLimit: { type: Number, min: 10, max: 2000 },
    online: { type: Boolean, default: false, index: true },
    lastSeen: Date,
    lastReading: {
      tds: Number,
      tdsIn: Number,
      temp: Number,
      at: Date,
    },
    firmware: String,
    claimedAt: Date,
  },
  { timestamps: true },
);

deviceSchema.methods.toPublic = function toPublic({ admin = false } = {}) {
  const out = {
    id: this._id.toString(),
    deviceId: this.deviceId,
    name: this.name,
    room: this.room,
    tdsLimit: this.tdsLimit,
    online: this.online,
    lastSeen: this.lastSeen,
    lastReading: this.lastReading?.at ? this.lastReading : null,
    firmware: this.firmware,
    claimedAt: this.claimedAt,
  };
  if (admin) {
    out.owner = this.owner && this.owner._id
      ? { id: this.owner._id.toString(), name: this.owner.name, phone: this.owner.phone }
      : this.owner;
    out.createdAt = this.createdAt;
  }
  return out;
};

export const Device = mongoose.model('Device', deviceSchema);

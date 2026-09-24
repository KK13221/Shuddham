import mongoose from 'mongoose';

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 80 },
    phone: { type: String, unique: true, sparse: true, match: /^[6-9]\d{9}$/ },
    email: { type: String, unique: true, sparse: true, lowercase: true, trim: true },
    passwordHash: { type: String, select: false },
    pincode: { type: String, match: /^\d{6}$/ },
    role: { type: String, enum: ['user', 'admin'], default: 'user', index: true },
    prefs: {
      highTdsAlerts: { type: Boolean, default: true },
      offlineAlerts: { type: Boolean, default: true },
      tempUnit: { type: String, enum: ['C', 'F'], default: 'C' },
    },
    fcmTokens: { type: [String], default: [], select: false },
    lastLoginAt: Date,
  },
  { timestamps: true },
);

userSchema.methods.toPublic = function toPublic() {
  return {
    id: this._id.toString(),
    name: this.name,
    phone: this.phone,
    email: this.email,
    pincode: this.pincode,
    role: this.role,
    prefs: this.prefs,
    createdAt: this.createdAt,
  };
};

export const User = mongoose.model('User', userSchema);

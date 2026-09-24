// Factory registration from the command line (same as "Register purifier" in the admin panel).
// Usage: npm run device:register -- SHD-A4F2C1
// Prints the MQTT secret (flash into firmware) and the 8-digit setup code (print on the label).
import crypto from 'node:crypto';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import { config } from '../src/config.js';
import { Device } from '../src/models/Device.js';

const deviceId = String(process.argv[2] || '').toUpperCase();
if (!/^[A-Z0-9-]{4,32}$/.test(deviceId)) {
  console.error('Usage: npm run device:register -- <DEVICE-ID>   (A–Z, 0–9, dash; 4–32 chars)');
  process.exit(1);
}

await mongoose.connect(config.mongoUri);
if (await Device.exists({ deviceId })) {
  console.error(`${deviceId} is already registered`);
  process.exit(1);
}
const secret = crypto.randomBytes(24).toString('base64url');
const setupCode = crypto.randomInt(0, 1e8).toString().padStart(8, '0');
await Device.create({
  deviceId,
  secretHash: await bcrypt.hash(secret, 10),
  popHash: await bcrypt.hash(setupCode, 10),
});
console.log(JSON.stringify({ deviceId, secret, setupCode }, null, 2));
console.log('Save these now – they cannot be shown again.');
await mongoose.disconnect();

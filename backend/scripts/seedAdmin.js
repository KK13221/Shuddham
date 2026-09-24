// Create or update an admin account for the admin panel.
// Usage: npm run seed:admin -- admin@shuddham.in "StrongPassword123" "Admin Name"
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import { config } from '../src/config.js';
import { User } from '../src/models/User.js';

const [email, password, name = 'Admin'] = process.argv.slice(2);
if (!email || !password || password.length < 10) {
  console.error('Usage: npm run seed:admin -- <email> <password (min 10 chars)> [name]');
  process.exit(1);
}

await mongoose.connect(config.mongoUri);
const passwordHash = await bcrypt.hash(password, 12);
const user = await User.findOneAndUpdate(
  { email: email.toLowerCase() },
  { $set: { name, role: 'admin', passwordHash } },
  { upsert: true, new: true },
);
console.log(`Admin ready: ${user.email}`);
await mongoose.disconnect();

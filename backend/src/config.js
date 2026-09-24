import 'dotenv/config';

const env = process.env;
const isProd = env.NODE_ENV === 'production';

function required(name, fallbackForDev) {
  const v = env[name];
  if (v) return v;
  if (!isProd && fallbackForDev !== undefined) return fallbackForDev;
  throw new Error(`Missing required env var ${name}`);
}

export const config = {
  isProd,
  port: Number(env.PORT || 4000),
  mongoUri: required('MONGO_URI', 'mongodb://127.0.0.1:27017/shuddham'),
  jwtSecret: required('JWT_SECRET', 'dev-only-change-me'),
  jwtExpiresIn: env.JWT_EXPIRES_IN || '30d',
  corsOrigins: (env.CORS_ORIGINS || 'http://localhost:5173').split(',').map((s) => s.trim()),

  mqtt: {
    port: Number(env.MQTT_PORT || 1883),
    tlsPort: Number(env.MQTT_TLS_PORT || 8883),
    tlsKeyPath: env.MQTT_TLS_KEY || '',
    tlsCertPath: env.MQTT_TLS_CERT || '',
    topicPrefix: env.MQTT_TOPIC_PREFIX || 'shuddham/devices',
  },

  otp: {
    length: 6,
    ttlSeconds: 300,
    resendCooldownSeconds: 30,
    maxAttempts: 5,
    msg91AuthKey: env.MSG91_AUTH_KEY || '',
    msg91TemplateId: env.MSG91_TEMPLATE_ID || '',
    // In development without MSG91 keys the OTP is printed to the server log.
    devLogOtp: !isProd && !env.MSG91_AUTH_KEY,
  },

  device: {
    offlineAfterSeconds: Number(env.DEVICE_OFFLINE_AFTER_SECONDS || 120),
    minReadingIntervalSeconds: Number(env.MIN_READING_INTERVAL_SECONDS || 10),
    defaultTdsLimit: Number(env.DEFAULT_TDS_LIMIT || 100),
    readingRetentionDays: Number(env.READING_RETENTION_DAYS || 180),
  },
};

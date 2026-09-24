// Pretend to be a purifier: connects over MQTT and sends TDS + temperature every few seconds.
// Usage: npm run device:simulate -- <DEVICE-ID> <secret> [mqtt://localhost:1883] [intervalSeconds]
// Set HIGH=1 to push TDS above the default 100 ppm limit and trigger an alert.
import mqtt from 'mqtt';

const [deviceId, secret, url = 'mqtt://localhost:1883', every = '10'] = process.argv.slice(2);
if (!deviceId || !secret) {
  console.error('Usage: npm run device:simulate -- <DEVICE-ID> <secret> [mqtt-url] [intervalSeconds]');
  process.exit(1);
}
const prefix = process.env.MQTT_TOPIC_PREFIX || 'shuddham/devices';
const statusTopic = `${prefix}/${deviceId}/status`;

const client = mqtt.connect(url, {
  clientId: deviceId,
  username: deviceId,
  password: secret,
  will: { topic: statusTopic, payload: 'offline', retain: true, qos: 1 },
});

let tds = process.env.HIGH ? 140 : 42;
let temp = 26.5;

client.on('connect', () => {
  console.log(`[${deviceId}] connected`);
  client.publish(statusTopic, 'online', { retain: true, qos: 1 });
  client.subscribe(`${prefix}/${deviceId}/cmd`);
  const send = () => {
    tds = Math.max(5, tds + (Math.random() - 0.5) * 4);
    temp = Math.max(10, Math.min(40, temp + (Math.random() - 0.5) * 0.3));
    const payload = { tds: +tds.toFixed(1), tdsIn: 380, temp: +temp.toFixed(1), fw: 'sim-1.0.0' };
    client.publish(`${prefix}/${deviceId}/telemetry`, JSON.stringify(payload), { qos: 1 });
    console.log(`[${deviceId}] sent`, payload);
  };
  send();
  setInterval(send, Number(every) * 1000);
});

client.on('message', (_topic, msg) => console.log(`[${deviceId}] command:`, msg.toString()));
client.on('error', (err) => {
  console.error(`[${deviceId}] error:`, err.message);
  process.exit(1);
});

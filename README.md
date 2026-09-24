# Shuddham – RO purifier platform

Everything for the Shuddham Water Solutions smart RO purifier:

| Folder | What | Stack |
|---|---|---|
| `app/` | Customer mobile app: OTP login, Bluetooth Wi-Fi setup, live TDS + temperature | Flutter |
| `backend/` | REST API, MQTT broker for purifiers, alerts, live updates | Node.js, Express, MongoDB, Aedes MQTT, Socket.IO |
| `admin/` | Admin panel: all purifiers with live TDS, charts, alerts, factory registration | React (Vite), Recharts |
| `design/` | UI designs: open `design/index.html` to see every screen | HTML |
| `FIRMWARE.md` | What the ESP32 firmware must do (BLE provisioning, MQTT topics, payloads) | Spec |

## How it fits together

```
 Purifier (ESP32)  ──MQTT: telemetry every 10 s──▶  Backend  ──Socket.IO live──▶  Admin panel
      ▲                                              │  ▲
      │ BLE: Wi-Fi credentials (setup only)          │  │ REST (JWT)
      └──────────────── Flutter app ◀────────────────┘  │
                              └─────────────────────────┘
```

1. At the factory, each purifier is registered: the server issues an MQTT secret (flashed into the firmware) and an 8-digit setup code (printed on the label).
2. The customer signs up with mobile OTP (MSG91), scans for the purifier over Bluetooth, enters the setup code, and picks Wi-Fi.
3. The purifier joins Wi-Fi, connects to the MQTT broker, and sends TDS/temperature. The app shows the data only once the **server** has received a reading.
4. The backend stores readings in a MongoDB time-series collection, opens/resolves **High TDS** and **Offline** alerts, and pushes live updates to the admin panel.

## Run locally

Requirements: Node 20+, MongoDB 6+ (or Docker), Flutter 3.22+.

```bash
# 1. Backend
cd backend
cp .env.example .env            # dev mode prints OTPs to the console instead of sending SMS
npm install
npm run dev                     # API on :4000, MQTT on :1883
npm run seed:admin -- admin@shuddham.in "ChangeThisPassword!" "Admin"

# 2. Register a test purifier and simulate it
npm run device:register -- SHD-TEST01          # prints secret + setup code
npm run device:simulate -- SHD-TEST01 <secret> # sends readings every 10 s (HIGH=1 to trigger an alert)

# 3. Admin panel
cd ../admin
cp .env.example .env
npm install
npm run dev                     # http://localhost:5173

# 4. App
cd ../app
bash tool/setup_platforms.sh
flutter run --dart-define=API_URL=http://<your-computer-ip>:4000
```

Or start MongoDB and the backend with Docker: `docker compose up --build` (create `backend/.env` first).

## API overview

| Method & path | Who | Purpose |
|---|---|---|
| `POST /api/auth/otp/send` | public | Send OTP (`purpose: login \| signup`) |
| `POST /api/auth/otp/verify` | public | Log in, or create an account when `profile` is sent |
| `POST /api/auth/email/login` | public | Email + password (password set in Profile) |
| `POST /api/auth/admin/login` | public | Admin login |
| `GET/PATCH /api/me`, `PUT /api/me/password`, `POST /api/me/push-token` | user | Profile, alert preferences, email-login password, FCM token |
| `GET /api/devices` | user | My purifiers + open alerts |
| `POST /api/devices/claim` | user | Link a purifier using its setup code |
| `GET/PATCH/DELETE /api/devices/:id` | user | Detail, rename / room / TDS limit, remove (also factory-resets it) |
| `GET /api/devices/:id/readings?range=24h\|7d\|30d` | user | Chart data |
| `POST /api/devices/:id/identify` | user | Purifier beeps + blinks |
| `GET /api/admin/stats`, `/devices`, `/devices/:id`, `/devices/:id/readings`, `/alerts` | admin | Admin panel data |
| `POST /api/admin/devices` | admin | Factory registration (returns secret + setup code once) |
| `POST /api/admin/alerts/:id/ack` | admin | Acknowledge an alert |

Live events on Socket.IO (auth with the JWT): `reading`, `device:status`, `alert`.

## Before going to production

- **HTTPS + MQTT over TLS.** Set `MQTT_TLS_KEY` / `MQTT_TLS_CERT` and have firmware use port 8883. Plain MQTT sends device secrets in clear text.
- **MSG91:** DLT-registered sender ID and OTP template (`MSG91_AUTH_KEY`, `MSG91_TEMPLATE_ID`).
- **Strong `JWT_SECRET`**, `NODE_ENV=production`, and `CORS_ORIGINS` set to the admin panel's URL.
- **Push notifications** (FCM) for alerts: tokens are already stored; the sending side isn't built.
- **One backend instance for now.** The MQTT broker keeps its state in memory. To run several instances, use an external broker (EMQX / Mosquitto) or the Aedes MongoDB persistence.
- **TDS wording:** the app says "Within range", never "Safe to drink". TDS can't detect bacteria or heavy metals.

## Test status

- Backend: `npm test` covers 15 checks: telemetry validation, alert rules, topic permissions, OTP, HTTP auth/validation, and MQTT broker auth + message flow with a real MQTT client. Database-backed routes haven't been run against a live MongoDB yet.
- Admin: builds with `npm run build`.
- App: written without a Flutter SDK available, so it hasn't been compiled. Run `flutter analyze` first (see `app/README.md`).

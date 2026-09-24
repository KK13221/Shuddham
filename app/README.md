# Shuddham app (Flutter)

Android and iOS app: OTP login, Bluetooth Wi-Fi setup for the purifier, and live TDS and temperature.

## First-time setup

```bash
cd app
bash tool/setup_platforms.sh     # creates android/ and ios/, adds Bluetooth permissions
flutter run --dart-define=API_URL=http://<your-computer-ip>:4000
```

The Android emulator can reach your computer at `http://10.0.2.2:4000` (the default). Bluetooth setup needs a **real phone**, because emulators have no Bluetooth.

## Settings (`--dart-define`)

| Name | Default | Meaning |
|---|---|---|
| `API_URL` | `http://10.0.2.2:4000` | Backend URL. Use HTTPS in production. |
| `BLE_PREFIX` | `SHD-` | Bluetooth name prefix of purifiers in setup mode |

## Code map

```
lib/
  main.dart, theme.dart, config.dart
  api/           REST client + models
  state/         AppState (session, purifier list)
  services/      ProvisioningService (ESP32 BLE provisioning)
  screens/
    splash_screen.dart          animated logo, restores session
    auth/                       login (OTP), login with email, sign up, OTP entry
    home/                       Devices tab (0 / 1 / many), purifier detail, Profile tab
    setup/                      permissions → scan + setup code → Wi-Fi → progress → done / failed
  widgets/       shared UI, chart
```

## Add-device flow

1. Bluetooth permission
2. Scan for `SHD-…` purifiers, pick one, enter the **8-digit setup code** from the label. The app calls `POST /api/devices/claim` before touching Wi-Fi, so a wrong code fails fast.
3. Pick a network from the purifier's own Wi-Fi scan and enter the password.
4. Send it over BLE, then **poll the backend** until the purifier is online and has sent a reading. Timeout is 90 s, then the failure screen shows the cause (Wi-Fi, Bluetooth or cloud).

## Not included yet

- Push notifications (FCM). The backend already stores tokens at `POST /api/me/push-token`; add `firebase_messaging` and the sending side.
- App icon / launcher assets.
- This code was written without a Flutter SDK available, so it has **not been compiled yet**. Run `flutter analyze` first and fix anything it reports. The part most likely to need changes is the `flutter_esp_ble_prov` call signatures in `services/provisioning_service.dart`, if the plugin's API has changed.

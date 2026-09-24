# Purifier firmware contract (ESP32)

The app and backend expect the purifier firmware to follow this contract. Firmware isn't built yet, so treat this as the spec.

## 1. Factory registration

Each unit is registered once, in the admin panel ("Register purifier") or with `npm run device:register -- SHD-A4F2C1`. This gives you:

| Value | Where it goes |
|---|---|
| **Device ID**, e.g. `SHD-A4F2C1` | Flashed into firmware. Also printed on the label. |
| **MQTT secret** (random, 32 chars) | Flashed into firmware (NVS, ideally with flash encryption). Never printed. |
| **Setup code** (8 digits) | Printed on the label / QR sticker. Flashed into firmware as the provisioning PoP. |

The server stores only hashes, so a lost secret means registering the unit again.

## 2. Bluetooth provisioning (ESP-IDF `wifi_provisioning`)

Use Espressif's standard component; the app uses the matching mobile library.

- Transport: **BLE** (`wifi_prov_scheme_ble`)
- Security: **`WIFI_PROV_SECURITY_1`** with **proof-of-possession = the 8-digit setup code**
- Service name (BLE advertised name): **the device ID**, e.g. `SHD-A4F2C1`. The app scans for the `SHD-` prefix.
- Enter setup mode when: there are no Wi-Fi credentials stored, OR the user holds the Wi-Fi button for 5 s (clear stored credentials, pulse the LED blue).
- Wi-Fi scan must be enabled (the app shows the networks the purifier sees).
- On provisioning failure (wrong password / AP not found) the component reports it to the app. Stay in setup mode so the user can retry.
- Stop BLE advertising once provisioned.

## 3. MQTT

| Setting | Value |
|---|---|
| Broker | `mqtt://<server>:1883` for development; **`mqtts://<server>:8883` in production** |
| Client ID | device ID |
| Username | device ID |
| Password | MQTT secret |
| Keepalive | 60 s |
| Last Will | topic `shuddham/devices/<id>/status`, payload `offline`, QoS 1, retained |

After connecting:

1. Publish `online` to `shuddham/devices/<id>/status` (QoS 1, retained).
2. Subscribe to `shuddham/devices/<id>/cmd` (QoS 1).
3. Publish telemetry **every 10 s** to `shuddham/devices/<id>/telemetry` (QoS 1):

```json
{ "tds": 42.0, "tdsIn": 380.0, "temp": 26.5, "fw": "1.0.0" }
```

- `tds`: purified-water TDS in ppm, temperature-compensated to 25 °C. **Required.**
- `tdsIn`: inlet TDS in ppm. Omit it if there is no inlet sensor.
- `temp`: water temperature in °C.
- `fw`: firmware version string.

Send the **first reading immediately after connecting**: the app's setup screen waits for it.

The broker rejects publishing to any other device's topics and disconnects the client.

## 4. Commands (server → purifier)

Payload on `shuddham/devices/<id>/cmd`:

| `cmd` | Purifier should |
|---|---|
| `identify` | Beep twice and blink the LED for 10 s |
| `factory_reset` | Erase Wi-Fi credentials and go back to setup mode (sent when the user removes the purifier in the app) |

## 5. Offline detection

The server marks a purifier offline when the MQTT connection drops (LWT), or when no telemetry has arrived for 120 s. Reconnect with exponential backoff (1 s → 60 s max).

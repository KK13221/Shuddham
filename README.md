# Shuddham RO Purifier App – UI Screens

Mobile app designs for the Shuddham Water Solutions RO purifier. The purifier is set up over Bluetooth, gets Wi-Fi credentials, and then streams **TDS** and **water temperature** to the app.

Open `index.html` in a browser to see all screens side by side. Every screen in `screens/` is a standalone HTML file (390 × 844, phone size), and the buttons link to each other so you can click through the flow.

## Screens

| # | File | Screen |
|---|------|--------|
| 00a | `screens/Splash.html` | Splash with animated logo |
| 00b | `screens/Login.html` | Log in with mobile number (OTP) |
| 00c | `screens/LoginEmail.html` | Log in with email |
| 00d | `screens/Signup.html` | Sign up |
| 01 | `screens/Main.html` | Home – no purifier yet (Add device) |
| 02 | `screens/Permissions.html` | Bluetooth permission |
| 03 | `screens/Scan.html` | Find purifier (several nearby) |
| 04 | `screens/WiFi.html` | Wi-Fi network + password |
| 05 | `screens/Provisioning.html` | Provisioning progress |
| 06a | `screens/SetupFailed.html` | Failure – wrong password |
| 06b | `screens/SetupDone.html` | Success – name & room |
| 07 | `screens/HomeSingle.html` | Home – 1 purifier |
| 08 | `screens/HomeMulti.html` | Home – multiple purifiers |
| 09 | `screens/DeviceDetail.html` | Purifier detail |
| 10 | `screens/Profile.html` | Profile tab |

## Flow rules

1. Home depends on the number of purifiers: 0 = empty state with **Add device**; 1 = full TDS dashboard; 2 or more = list, and tapping a card opens its detail.
2. Show data only after the **purifier confirms** it has reached the cloud and sent its first reading. A successful Bluetooth write is not enough.
3. Several purifiers nearby: show a short ID and signal strength for each. **Identify** makes that purifier beep and blink. Already-provisioned units are greyed out.
4. The Wi-Fi list comes from the purifier's own scan, so 5 GHz networks can be flagged. After a failure, keep Bluetooth connected so the user can retry without scanning again.
5. Provisioning timeout is about 60 s. After that, show the failure screen with the reason the purifier reported.
6. TDS: purified-water TDS is the main number. Show input TDS only if the hardware has an inlet sensor. Say "Within range", never "Safe to drink": TDS can't detect bacteria or heavy metals.
7. Profile holds the account, alert settings and support. There is no separate Settings tab.

## Brand colours

| Token | Hex |
|---|---|
| Primary (buttons, links) | `#1553B8` |
| Primary pressed | `#0F3F8F` |
| Navy (text, dark cards) | `#0F2A5C` |
| Muted text | `#56627A` |
| Background | `#F4F7FB` |
| Border | `#D5DEEB` |
| Primary tint | `#E3EDFB` |
| Warning | `#D97706` / text `#9A4A0B` |
| Error | `#B42318` |

Fonts: Bricolage Grotesque (headings), IBM Plex Sans (body).

## Still to design

- OTP entry screen (6 digits, resend, timer)
- Forgot password / reset (only if email + password login stays)

## Folders

- `screens/` – standalone HTML screens
- `assets/` – logo files (mark, wordmark, full) with transparent background
- `design-source/` – original design-canvas source files. These need the design editor runtime to render; use `screens/` for viewing.

Sample values (42 ppm, 26.5 °C, etc.) are placeholders.

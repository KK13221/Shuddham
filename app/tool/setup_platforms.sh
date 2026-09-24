#!/usr/bin/env bash
# Generates the android/ and ios/ folders and adds the Bluetooth permissions the app needs.
# Run once from the app/ folder:   bash tool/setup_platforms.sh
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create . --org in.shuddham --project-name shuddham --platforms android,ios
flutter pub get

python3 - <<'PY'
import re, pathlib

# ---- Android permissions ----
manifest = pathlib.Path('android/app/src/main/AndroidManifest.xml')
m = manifest.read_text()
perms = [
    '<uses-permission android:name="android.permission.INTERNET" />',
    '<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />',
    '<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />',
    '<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />',
    '<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />',
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
    '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />',
    '<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />',
]
missing = [p for p in perms if p not in m]
if missing:
    m = m.replace('<application', '\n    '.join(missing) + '\n    <application', 1)
# Allow plain HTTP to a local dev server. Remove for production (use HTTPS).
if 'usesCleartextTraffic' not in m:
    m = m.replace('<application', '<application android:usesCleartextTraffic="true"', 1)
manifest.write_text(m)

# ---- Android minSdk (ESP provisioning library needs 23+) ----
for name in ['android/app/build.gradle.kts', 'android/app/build.gradle']:
    p = pathlib.Path(name)
    if p.exists():
        g = p.read_text()
        g = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24', g)
        g = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24', g)
        p.write_text(g)

# ---- iOS usage descriptions ----
plist = pathlib.Path('ios/Runner/Info.plist')
s = plist.read_text()
keys = {
    'NSBluetoothAlwaysUsageDescription': 'Bluetooth is used to set up your Shuddham purifier’s Wi-Fi.',
    'NSBluetoothPeripheralUsageDescription': 'Bluetooth is used to set up your Shuddham purifier’s Wi-Fi.',
    'NSLocalNetworkUsageDescription': 'Used to talk to your purifier during setup.',
}
for k, v in keys.items():
    if k not in s:
        s = s.replace('<dict>', f'<dict>\n\t<key>{k}</key>\n\t<string>{v}</string>', 1)
plist.write_text(s)

# ---- iOS deployment target 13 ----
podfile = pathlib.Path('ios/Podfile')
if podfile.exists():
    pf = podfile.read_text()
    pf = re.sub(r"#\s*platform :ios, '[\d.]+'", "platform :ios, '13.0'", pf)
    podfile.write_text(pf)
print('Platform files patched.')
PY

echo "Done. Run: flutter run --dart-define=API_URL=http://<your-computer-ip>:4000"

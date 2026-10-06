/// Build-time settings. Override with --dart-define, e.g.
///   flutter run --dart-define=API_URL=http://192.168.1.20:4000
class AppConfig {
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:4000');

  /// Advertised name prefix from firmware (e.g. "SHUDDHAM" or "SHD-")
  static const bleNamePrefix = 'SHUDDHAM';
  static const bleAltPrefix = 'SHD-';

  /// Advertised Service UUID: 0xABF0
  static const bleAdvertisedServiceUuid = '0000abf0-0000-1000-8000-00805f9b34fb';

  /// Real GATT Service UUID: 0x00FF
  static const bleGattServiceUuid = '000000ff-0000-1000-8000-00805f9b34fb';

  /// GATT Characteristic UUID: 0xFF01 (Write & Notify)
  static const bleCharUuid = '0000ff01-0000-1000-8000-00805f9b34fb';

  /// How long to wait for the purifier to reach the server after Wi-Fi is set.
  static const cloudTimeout = Duration(seconds: 90);

  /// Dashboard refresh interval.
  static const pollInterval = Duration(seconds: 15);
}

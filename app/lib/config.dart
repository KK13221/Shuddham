/// Build-time settings. Override with --dart-define, e.g.
///   flutter run --dart-define=API_URL=http://192.168.1.20:4000
class AppConfig {
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:4000');

  /// Purifiers advertise over Bluetooth as "SHD-XXXXXX" while in setup mode.
  static const bleNamePrefix = String.fromEnvironment('BLE_PREFIX', defaultValue: 'SHD-');

  /// How long to wait for the purifier to reach the server after Wi-Fi is set.
  static const cloudTimeout = Duration(seconds: 90);

  /// Dashboard refresh interval.
  static const pollInterval = Duration(seconds: 15);
}

import '../../api/models.dart';

/// Everything collected while adding one purifier.
class SetupSession {
  SetupSession({required this.bleName, required this.deviceId, required this.setupCode, required this.device});

  final String bleName; // e.g. SHD-A4F2C1 (what the purifier advertises)
  final String deviceId; // backend ID (same as the BLE name)
  final String setupCode; // 8-digit code from the label = BLE proof-of-possession
  Device device; // claimed device record
  String ssid = '';
  String password = '';
}

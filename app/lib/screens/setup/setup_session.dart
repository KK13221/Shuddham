import '../../api/models.dart';

/// Everything collected while adding one purifier.
class SetupSession {
  SetupSession({
    required this.bleName,
    required this.deviceId,
    this.setupCode = '',
    this.device,
  });

  final String bleName; // e.g. SHUDDHAM or SHD-A4F2C1
  final String deviceId; // backend/device ID
  final String setupCode; // setup code
  Device? device; // claimed device record (if available)
  String ssid = '';
  String password = '';
}

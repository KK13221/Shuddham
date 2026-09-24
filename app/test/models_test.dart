import 'package:flutter_test/flutter_test.dart';
import 'package:shuddham/api/models.dart';
import 'package:shuddham/services/provisioning_service.dart';

void main() {
  test('Device parses API JSON including open alert objects', () {
    final d = Device.fromJson({
      'id': 'abc',
      'deviceId': 'SHD-A4F2C1',
      'name': 'Kitchen purifier',
      'room': 'Kitchen',
      'online': true,
      'lastReading': {'tds': 42, 'tdsIn': 380, 'temp': 26.5, 'at': '2026-09-24T10:00:00Z'},
      'openAlerts': [
        {'type': 'high_tds'}
      ],
    });
    expect(d.highTds, isTrue);
    expect(d.lastReading!.removedPercent, 89);
    expect(d.effectiveLimit, 100);
  });

  test('AppUser initials', () {
    expect(AppUser.fromJson({'id': '1', 'name': 'Shubham Jain'}).initials, 'SJ');
    expect(AppUser.fromJson({'id': '1', 'name': 'Asha'}).initials, 'A');
  });

  test('BLE name helpers', () {
    expect(ProvisioningService.deviceIdFromBleName(' shd-a4f2c1 '), 'SHD-A4F2C1');
    expect(ProvisioningService.shortId('SHD-A4F2C1'), 'F2C1');
  });
}

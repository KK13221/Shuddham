import 'package:flutter_test/flutter_test.dart';
import 'package:shuddham/services/provisioning_service.dart';

void main() {
  group('ESP32 Bluetooth Wi-Fi Parser Tests', () {
    final regex = RegExp(r'^\[(\d+)\]:(.*)\[(\d+)\]$');

    test('Parses standard Wi-Fi network format [1]:HomeNet[1]', () {
      final match = regex.firstMatch('[1]:HomeNet[1]');
      expect(match, isNotNull);
      expect(match!.group(1), '1');
      expect(match.group(2), 'HomeNet');
      expect(match.group(3), '1');

      final net = BleWifiNetwork(index: 1, ssid: match.group(2)!, security: int.parse(match.group(3)!));
      expect(net.ssid, 'HomeNet');
      expect(net.isSecured, isTrue);
      expect(net.isOpen, isFalse);
    });

    test('Parses open network [3]:Guest[0]', () {
      final match = regex.firstMatch('[3]:Guest[0]');
      expect(match, isNotNull);
      expect(match!.group(2), 'Guest');
      expect(match.group(3), '0');

      final net = BleWifiNetwork(index: 3, ssid: match.group(2)!, security: int.parse(match.group(3)!));
      expect(net.isOpen, isTrue);
      expect(net.isSecured, isFalse);
    });

    test('Parses network with special characters and spaces [2]:My_WiFi (2.4G) [1]', () {
      final match = regex.firstMatch('[2]:My_WiFi (2.4G) [1]');
      expect(match, isNotNull);
      expect(match!.group(2), 'My_WiFi (2.4G) ');
      expect(match.group(3), '1');
    });

    test('Handles SSID deduplication and drops empty networks', () {
      final rawLines = [
        '[1]:HomeNet[1]',
        '[2]:Office_2G[1]',
        '[3]:HomeNet[1]', // duplicate
        '[4]: [1]',       // empty SSID
        '[5]:Guest[0]',
      ];

      final seen = <String>{};
      final list = <BleWifiNetwork>[];

      for (final line in rawLines) {
        final m = regex.firstMatch(line);
        if (m != null) {
          final ssid = m.group(2)?.trim() ?? '';
          final sec = int.tryParse(m.group(3) ?? '0') ?? 0;
          final idx = int.tryParse(m.group(1) ?? '0') ?? 0;
          if (ssid.isNotEmpty && !seen.contains(ssid)) {
            seen.add(ssid);
            list.add(BleWifiNetwork(index: idx, ssid: ssid, security: sec));
          }
        }
      }

      expect(list.length, 3);
      expect(list[0].ssid, 'HomeNet');
      expect(list[1].ssid, 'Office_2G');
      expect(list[2].ssid, 'Guest');
    });

    test('BLE device helpers', () {
      expect(ProvisioningService.shortId('SHUDDHAM-A1B2'), 'A1B2');
      expect(ProvisioningService.shortId('SHD-TEST01'), 'ST01');
      expect(ProvisioningService.deviceIdFromBleName('  shuddham_01 '), 'SHUDDHAM_01');
    });
  });
}

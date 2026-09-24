import 'dart:io';

import 'package:flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config.dart';

/// Bluetooth Wi-Fi provisioning using Espressif's unified provisioning protocol
/// (ESP-IDF `wifi_provisioning` component, BLE transport, security 1 with a proof-of-possession).
/// The PoP is the 8-digit setup code printed on the purifier's label – see FIRMWARE.md.
class ProvisioningService {
  ProvisioningService({FlutterEspBleProv? plugin}) : _plugin = plugin ?? FlutterEspBleProv();

  final FlutterEspBleProv _plugin;

  /// Asks for the Bluetooth permissions the scan needs. Returns true when all are granted.
  Future<bool> requestPermissions() async {
    final perms = <Permission>[
      if (Platform.isAndroid) ...[Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse],
      if (Platform.isIOS) Permission.bluetooth,
    ];
    final results = await perms.request();
    return results.values.every((s) => s.isGranted || s.isLimited);
  }

  Future<bool> permissionsPermanentlyDenied() async {
    final perms = Platform.isAndroid ? [Permission.bluetoothScan, Permission.bluetoothConnect] : [Permission.bluetooth];
    for (final p in perms) {
      if (await p.isPermanentlyDenied) return true;
    }
    return false;
  }

  /// BLE names of purifiers currently in setup mode, e.g. ["SHD-A4F2C1"].
  Future<List<String>> scanDevices() async {
    final names = await _plugin.scanBleDevices(AppConfig.bleNamePrefix);
    final unique = names.toSet().toList()..sort();
    return unique;
  }

  /// Wi-Fi networks the purifier can see (ESP32 is 2.4 GHz only, so 5 GHz networks never appear).
  Future<List<String>> scanWifi(String bleName, String setupCode) async {
    final networks = await _plugin.scanWifiNetworks(bleName, setupCode);
    return networks.where((s) => s.trim().isNotEmpty).toSet().toList();
  }

  /// Sends the Wi-Fi credentials. Resolves true once the purifier reports it joined the network.
  Future<bool> provision(String bleName, String setupCode, String ssid, String password) async {
    final ok = await _plugin.provisionWifi(bleName, setupCode, ssid, password);
    return ok ?? false;
  }

  /// "SHD-A4F2C1" -> device ID used by the backend. The BLE name is the device ID.
  static String deviceIdFromBleName(String name) => name.trim().toUpperCase();

  /// Short ID shown to the user so they can match it with the label.
  static String shortId(String name) {
    final id = deviceIdFromBleName(name);
    return id.length > 4 ? id.substring(id.length - 4) : id;
  }
}

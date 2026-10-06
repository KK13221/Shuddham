import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/provisioning_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'setup_session.dart';
import 'wifi_screen.dart';

/// Step 1: Scan for nearby ESP32 Shuddham devices.
/// - Auto-connects if exactly 1 Shuddham purifier is discovered.
/// - Shows device selection list if multiple purifiers are in range.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<DiscoveredBleDevice> _found = [];
  DiscoveredBleDevice? _selected;
  bool _scanning = false;
  bool _connecting = false;
  String? _statusText;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _statusText = 'Scanning for nearby Shuddham purifiers...';
      _error = null;
    });

    try {
      final prov = context.read<ProvisioningService>();
      final found = await prov.scanDevices();
      if (!mounted) return;

      final shuddhamList = found.where((d) {
        final u = d.name.toUpperCase();
        return u.startsWith('SHUDDHAM') || u.startsWith('SHD');
      }).toList();

      setState(() {
        _found = found;
      });

      // Auto-connect if exactly 1 Shuddham device is in range
      if (shuddhamList.length == 1) {
        final target = shuddhamList.first;
        setState(() {
          _selected = target;
          _statusText = 'Found ${target.name}! Connecting automatically...';
        });
        await _connectDevice(target);
      } else if (shuddhamList.length > 1) {
        setState(() {
          _selected = shuddhamList.first;
          _statusText = '${shuddhamList.length} Shuddham devices found. Select one to connect.';
        });
      } else if (found.isNotEmpty) {
        setState(() {
          _selected = found.first;
          _statusText = '${found.length} BLE device(s) found.';
        });
      } else {
        setState(() {
          _statusText = 'No purifier found.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Scan failed: Make sure Bluetooth is ON and allowed in Settings.');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connectDevice(DiscoveredBleDevice dev) async {
    if (_connecting) return;
    setState(() {
      _selected = dev;
      _connecting = true;
      _statusText = 'Connecting to ${dev.name} (MTU 64 & Services)...';
      _error = null;
    });

    try {
      final prov = context.read<ProvisioningService>();
      await prov.connect(dev.device);
      if (!mounted) return;

      final session = SetupSession(
        bleName: dev.name,
        deviceId: dev.name.toUpperCase(),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => WifiScreen(session: session)),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to connect to ${dev.name}: $e';
          _statusText = null;
        });
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const StepBar(step: 1)),
      body: ScreenBody(
        bottom: BusyButton(
          busy: _connecting,
          label: _connecting
              ? 'Connecting to ${_selected?.name ?? 'Purifier'}...'
              : (_selected == null
                  ? 'Select a purifier'
                  : 'Connect to ${ProvisioningService.shortId(_selected!.name)}'),
          onPressed: _selected == null || _connecting ? null : () => _connectDevice(_selected!),
        ),
        children: [
          const Heading(
            'Connect Purifier',
            subtitle: 'Searching for nearby ESP32 Shuddham devices broadcasting in setup mode.',
          ),
          const SizedBox(height: 12),
          if (_statusText != null && !_connecting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.tint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  if (_scanning) ...[
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                  ] else ...[
                    const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      _statusText!,
                      style: const TextStyle(fontSize: 13, color: AppColors.navy, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          if (_connecting) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(strokeWidth: 4),
                  const SizedBox(height: 16),
                  Text(
                    'Connecting to ${_selected?.name ?? 'Purifier'}...',
                    style: display(18),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Negotiating MTU 64 and subscribing to notifications...',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Text('${_found.length} device(s) in range', style: const TextStyle(color: AppColors.muted, fontSize: 14)),
            const Spacer(),
            TextButton.icon(
              onPressed: _connecting ? null : _scan,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Scan again'),
            ),
          ]),
          const SizedBox(height: 8),
          if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 12)],
          for (final dev in _found) ...[
            _DeviceOption(
              dev: dev,
              selected: _selected?.device.remoteId == dev.device.remoteId,
              isConnecting: _connecting && _selected?.device.remoteId == dev.device.remoteId,
              onTap: _connecting ? () {} : () => _connectDevice(dev),
            ),
            const SizedBox(height: 12),
          ],
          if (!_scanning && _found.isEmpty && _error == null)
            CardBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('No purifier found yet.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  SizedBox(height: 6),
                  Text(
                    'Hold the BOOT button on the ESP32 device for 6 seconds, then release it to enter Bluetooth pairing mode.',
                    style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.touch_app_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: If only 1 Shuddham purifier is found, it will automatically connect and open the Wi-Fi setup.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceOption extends StatelessWidget {
  const _DeviceOption({
    required this.dev,
    required this.selected,
    required this.isConnecting,
    required this.onTap,
  });

  final DiscoveredBleDevice dev;
  final bool selected;
  final bool isConnecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isShuddham = dev.name.toUpperCase().startsWith('SHUDDHAM') || dev.name.toUpperCase().startsWith('SHD');

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isShuddham ? AppColors.tint : AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isShuddham ? Icons.water_drop : Icons.bluetooth_connected,
                  color: isShuddham ? AppColors.primary : AppColors.navy,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          dev.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isShuddham) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('PURIFIER', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Signal: ${dev.rssi} dBm • ${dev.device.remoteId}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
              if (isConnecting)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  onPressed: onTap,
                  child: const Text('Connect', style: TextStyle(fontSize: 13)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

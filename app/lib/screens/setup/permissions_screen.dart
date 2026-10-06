import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../services/provisioning_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'scan_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _busy = false;
  String? _error;
  bool _openSettings = false;

  @override
  void initState() {
    super.initState();
    _checkInitial();
  }

  Future<void> _checkInitial() async {
    final prov = context.read<ProvisioningService>();
    final alreadyGranted = await prov.hasPermissions();
    if (alreadyGranted && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ScanScreen()));
    }
  }

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final prov = context.read<ProvisioningService>();
    final granted = await prov.requestPermissions();
    if (!mounted) return;
    if (granted) {
      setState(() => _busy = false);
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ScanScreen()));
      return;
    }
    final permanent = await prov.permissionsPermanentlyDenied();
    setState(() {
      _busy = false;
      _openSettings = permanent;
      _error = permanent
          ? 'Bluetooth permission is turned off for Shuddham. Turn it on in Settings to add a purifier.'
          : 'Bluetooth permission is needed to find your purifier.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Close setup', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        title: const Text('Before we start', style: TextStyle(fontSize: 14, color: AppColors.muted)),
        centerTitle: true,
      ),
      body: ScreenBody(
        bottom: _openSettings
            ? const FilledButton(onPressed: openAppSettings, child: Text('Open Settings'))
            : BusyButton(label: 'Continue', busy: _busy, onPressed: _continue),
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.bluetooth, size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Heading(
            'Let the app find nearby purifiers',
            subtitle: 'Your purifier receives its Wi-Fi details over Bluetooth. Your phone will ask for permission next.',
          ),
          const SizedBox(height: 24),
          const _Reason(
            icon: Icons.bluetooth,
            title: 'Bluetooth',
            body: 'Required to discover and talk to the purifier during setup.',
          ),
          const SizedBox(height: 12),
          const _Reason(
            icon: Icons.location_on_outlined,
            title: 'Nearby devices (Android)',
            body: 'Android labels Bluetooth scanning this way. We don’t track your location.',
          ),
          if (_error != null) ...[const SizedBox(height: 16), ErrorBanner(_error!)],
        ],
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => CardBox(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: AppColors.navy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.muted)),
            ]),
          ),
        ]),
      );
}

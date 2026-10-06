import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/provisioning_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'provisioning_screen.dart';
import 'setup_session.dart';

/// Step 2: Choose a 2.4 GHz Wi-Fi network discovered by the purifier or enter manually.
class WifiScreen extends StatefulWidget {
  const WifiScreen({super.key, required this.session, this.errorMessage});
  final SetupSession session;
  final String? errorMessage;

  @override
  State<WifiScreen> createState() => _WifiScreenState();
}

class _WifiScreenState extends State<WifiScreen> {
  List<BleWifiNetwork> _networks = [];
  BleWifiNetwork? _selectedNetwork;
  String? _ssid;
  bool _scanning = false;
  bool _obscure = true;
  bool _manual = false;
  String? _error;
  late final _password = TextEditingController(text: widget.session.password);
  final _manualSsid = TextEditingController();

  @override
  void initState() {
    super.initState();
    _error = widget.errorMessage;
    _ssid = widget.session.ssid.isEmpty ? null : widget.session.ssid;
    _scan();
  }

  @override
  void dispose() {
    _password.dispose();
    _manualSsid.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final list = await context.read<ProvisioningService>().scanWifiNetworks();
      if (!mounted) return;
      setState(() {
        _networks = list;
        if (_ssid == null && list.isNotEmpty) {
          _selectedNetwork = list.first;
          _ssid = list.first.ssid;
        } else if (_ssid != null) {
          _selectedNetwork = list.where((n) => n.ssid == _ssid).firstOrNull;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not retrieve Wi-Fi networks from purifier: $e');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _connect() {
    final ssid = _manual ? _manualSsid.text.trim() : _ssid?.trim();
    if (ssid == null || ssid.isEmpty) {
      setState(() => _error = 'Please select or enter a Wi-Fi network name (SSID).');
      return;
    }

    var pass = _password.text.trim();
    // Safety check: firmware reboots if password is empty. If open network and empty, send "none"
    if (pass.isEmpty) {
      if (_selectedNetwork?.isOpen == true) {
        pass = 'none';
      } else {
        setState(() => _error = 'Please enter the Wi-Fi password.');
        return;
      }
    }

    widget.session
      ..ssid = ssid
      ..password = pass;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ProvisioningScreen(session: widget.session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _manual ? 'Password' : 'Password for ${_ssid ?? 'network'}';
    return Scaffold(
      appBar: AppBar(title: const StepBar(step: 2)),
      body: ScreenBody(
        bottom: FilledButton(onPressed: _connect, child: const Text('Connect')),
        children: [
          const Heading(
            'Connect to Wi-Fi',
            subtitle: 'Select a 2.4 GHz network discovered by your purifier.',
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 12)],
          CardBox(
            padding: EdgeInsets.zero,
            child: Column(children: [
              if (_scanning)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Purifier is scanning for 2.4GHz Wi-Fi...', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    ],
                  ),
                )
              else
                for (final n in _networks)
                  _NetworkTile(
                    network: n,
                    selected: !_manual && n.ssid == _ssid,
                    onTap: () => setState(() {
                      _manual = false;
                      _selectedNetwork = n;
                      _ssid = n.ssid;
                    }),
                  ),
              if (!_scanning && _networks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No networks reported by purifier. Tap "Scan again" or enter manually.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.add, color: AppColors.primary),
                title: const Text('Hidden or other network', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                onTap: () => setState(() {
                  _manual = true;
                  _selectedNetwork = null;
                }),
              ),
              ListTile(
                leading: const Icon(Icons.refresh, color: AppColors.primary),
                title: const Text('Scan again', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                onTap: _scanning ? null : _scan,
              ),
            ]),
          ),
          const SizedBox(height: 20),
          if (_manual) ...[
            const FieldLabel('Network name (SSID)'),
            TextField(
              controller: _manualSsid,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'e.g. Home_WiFi_2.4G'),
            ),
            const SizedBox(height: 16),
          ],
          FieldLabel(label),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: _selectedNetwork?.isOpen == true ? 'Optional for open network' : 'Enter Wi-Fi password',
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkTile extends StatelessWidget {
  const _NetworkTile({required this.network, required this.selected, required this.onTap});
  final BleWifiNetwork network;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        child: ListTile(
          tileColor: selected ? AppColors.tint : null,
          leading: Icon(
            network.isSecured ? Icons.wifi_lock : Icons.wifi,
            color: selected ? AppColors.primary : AppColors.navy,
          ),
          title: Text(network.ssid, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          trailing: selected
              ? const Icon(Icons.check_circle, color: AppColors.primary)
              : (network.isSecured ? const Icon(Icons.lock_outline, size: 16, color: AppColors.muted) : null),
          onTap: onTap,
        ),
      );
}

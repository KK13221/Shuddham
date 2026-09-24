import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/provisioning_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'provisioning_screen.dart';
import 'setup_session.dart';

/// Step 2: choose a network the purifier can see and enter its password.
class WifiScreen extends StatefulWidget {
  const WifiScreen({super.key, required this.session, this.errorMessage});
  final SetupSession session;
  final String? errorMessage;

  @override
  State<WifiScreen> createState() => _WifiScreenState();
}

class _WifiScreenState extends State<WifiScreen> {
  List<String> _networks = [];
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
    setState(() => _scanning = true);
    try {
      final list = await context.read<ProvisioningService>().scanWifi(widget.session.bleName, widget.session.setupCode);
      if (!mounted) return;
      setState(() {
        _networks = list;
        if (_ssid == null && list.isNotEmpty) _ssid = list.first;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t get the network list from the purifier. Keep your phone close and try again.');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _connect() {
    final ssid = _manual ? _manualSsid.text.trim() : _ssid;
    if (ssid == null || ssid.isEmpty) {
      setState(() => _error = 'Choose a Wi-Fi network');
      return;
    }
    widget.session
      ..ssid = ssid
      ..password = _password.text;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ProvisioningScreen(session: widget.session)));
  }

  @override
  Widget build(BuildContext context) {
    final label = _manual ? 'Password' : 'Password for ${_ssid ?? 'network'}';
    return Scaffold(
      appBar: AppBar(title: const StepBar(step: 2)),
      body: ScreenBody(
        bottom: FilledButton(onPressed: _connect, child: const Text('Connect')),
        children: [
          const Heading('Connect to Wi-Fi', subtitle: 'Networks your purifier can see. It works on 2.4 GHz Wi-Fi only.'),
          const SizedBox(height: 20),
          if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 12)],
          CardBox(
            padding: EdgeInsets.zero,
            child: Column(children: [
              if (_scanning)
                const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
              else
                for (final n in _networks)
                  _NetworkTile(
                    ssid: n,
                    selected: !_manual && n == _ssid,
                    onTap: () => setState(() {
                      _manual = false;
                      _ssid = n;
                    }),
                  ),
              if (!_scanning && _networks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No networks found. Move closer to your router and scan again.', style: TextStyle(color: AppColors.muted)),
                ),
              ListTile(
                leading: const Icon(Icons.add, color: AppColors.primary),
                title: const Text('Hidden or other network', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                onTap: () => setState(() => _manual = true),
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
            TextField(controller: _manualSsid, autocorrect: false),
            const SizedBox(height: 16),
          ],
          FieldLabel(label),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
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
  const _NetworkTile({required this.ssid, required this.selected, required this.onTap});
  final String ssid;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        child: ListTile(
          tileColor: selected ? AppColors.tint : null,
          leading: Icon(Icons.wifi, color: selected ? AppColors.primary : AppColors.navy),
          title: Text(ssid, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          trailing: selected ? const Icon(Icons.check, color: AppColors.primary) : null,
          onTap: onTap,
        ),
      );
}

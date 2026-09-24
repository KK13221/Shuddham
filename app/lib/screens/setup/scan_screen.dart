import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../services/provisioning_service.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'setup_session.dart';
import 'wifi_screen.dart';

/// Step 1: find purifiers in setup mode, pick one, enter the setup code from its label.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<String> _found = [];
  String? _selected;
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final found = await context.read<ProvisioningService>().scanDevices();
      if (!mounted) return;
      setState(() {
        _found = found;
        if (!found.contains(_selected)) _selected = found.length == 1 ? found.first : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Couldn’t scan for purifiers. Make sure Bluetooth is on and try again.');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect() async {
    final name = _selected;
    if (name == null) return;
    final session = await showModalBottomSheet<SetupSession>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SetupCodeSheet(bleName: name),
    );
    if (session != null && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => WifiScreen(session: session)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const StepBar(step: 1)),
      body: ScreenBody(
        bottom: FilledButton(
          onPressed: _selected == null ? null : _connect,
          child: Text(_selected == null ? 'Select a purifier' : 'Connect to ${ProvisioningService.shortId(_selected!)}'),
        ),
        children: [
          const Heading('Choose your purifier'),
          const SizedBox(height: 8),
          Row(children: [
            if (_scanning) ...[
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: 8),
              const Text('Searching…', style: TextStyle(color: AppColors.muted, fontSize: 15)),
            ] else ...[
              Text('${_found.length} found', style: const TextStyle(color: AppColors.muted, fontSize: 15)),
              const Spacer(),
              TextButton.icon(onPressed: _scan, icon: const Icon(Icons.refresh, size: 18), label: const Text('Scan again')),
            ],
          ]),
          const SizedBox(height: 12),
          if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 12)],
          for (final name in _found) ...[
            _DeviceOption(
              name: name,
              selected: name == _selected,
              onTap: () => setState(() => _selected = name),
            ),
            const SizedBox(height: 12),
          ],
          if (!_scanning && _found.isEmpty && _error == null)
            const CardBox(
              child: Text('No purifier found yet.', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 4),
          const Text(
            'Several purifiers nearby? Match the last 4 characters with the ID on the purifier’s label. '
            'Don’t see yours? Hold its Wi-Fi button for 5 s until the light pulses blue, then scan again.',
            style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _DeviceOption extends StatelessWidget {
  const _DeviceOption({required this.name, required this.selected, required this.onTap});
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
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
                decoration: BoxDecoration(color: selected ? AppColors.tint : AppColors.bg, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.water_drop_outlined, color: selected ? AppColors.primary : AppColors.navy),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('RO Purifier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text('ID ${ProvisioningService.shortId(name)}',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted, fontFamily: 'monospace')),
                ]),
              ),
              if (selected) const Icon(Icons.check_circle, color: AppColors.primary),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Asks for the 8-digit setup code and links the purifier to this account.
class _SetupCodeSheet extends StatefulWidget {
  const _SetupCodeSheet({required this.bleName});
  final String bleName;

  @override
  State<_SetupCodeSheet> createState() => _SetupCodeSheetState();
}

class _SetupCodeSheetState extends State<_SetupCodeSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.length != 8) {
      setState(() => _error = 'Enter the 8-digit code from the label');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final deviceId = ProvisioningService.deviceIdFromBleName(widget.bleName);
    try {
      final device = await context.read<AppState>().api.claim(deviceId, code);
      if (!mounted) return;
      Navigator.of(context).pop(SetupSession(bleName: widget.bleName, deviceId: deviceId, setupCode: code, device: device));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enter setup code', style: display(24)),
          const SizedBox(height: 8),
          Text(
            'Find the 8-digit code on the label of purifier ${ProvisioningService.shortId(widget.bleName)}. '
            'It proves the purifier is yours.',
            style: const TextStyle(color: AppColors.muted, height: 1.45),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
            textAlign: TextAlign.center,
            style: display(26).copyWith(letterSpacing: 6),
            decoration: const InputDecoration(hintText: '00000000'),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
          const SizedBox(height: 20),
          BusyButton(label: 'Continue', busy: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../config.dart';
import '../../services/provisioning_service.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'setup_done_screen.dart';
import 'setup_failed_screen.dart';
import 'setup_session.dart';

/// Step 3: send Wi-Fi over Bluetooth, then wait until the SERVER confirms the purifier is online
/// and has sent a reading. A successful Bluetooth write alone is not success.
class ProvisioningScreen extends StatefulWidget {
  const ProvisioningScreen({super.key, required this.session});
  final SetupSession session;

  @override
  State<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends State<ProvisioningScreen> {
  /// Rows before this index are done, this row is in progress.
  int _progress = 0;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  void _fail(FailureReason reason) {
    if (_cancelled || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SetupFailedScreen(session: widget.session, reason: reason)),
    );
  }

  Future<void> _run() async {
    final s = widget.session;
    final prov = context.read<ProvisioningService>();
    final api = context.read<AppState>().api;
    final started = DateTime.now();

    // 1–2. Bluetooth: send credentials; the call resolves when the purifier reports joined / failed.
    bool joined;
    try {
      joined = await prov.provision(s.bleName, s.setupCode, s.ssid, s.password);
    } catch (_) {
      return _fail(FailureReason.bluetooth);
    }
    if (!joined) return _fail(FailureReason.wifi);
    if (_cancelled) return;

    // 3–4. Cloud: poll the backend until the purifier is online with a fresh reading.
    setState(() => _progress = 2);
    final deadline = DateTime.now().add(AppConfig.cloudTimeout);
    while (!_cancelled && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 3));
      try {
        final d = await api.device(s.deviceId);
        if (!mounted || _cancelled) return;
        if (d.online && _progress == 2) setState(() => _progress = 3);
        final at = d.lastReading?.at;
        if (d.online && at != null && at.isAfter(started.subtract(const Duration(seconds: 5)))) {
          s.device = d;
          setState(() => _progress = 4);
          await Future<void>.delayed(const Duration(milliseconds: 600));
          if (!mounted || _cancelled) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SetupDoneScreen(session: s)));
          return;
        }
      } on ApiException {
        // Phone may be switching networks; keep trying until the deadline.
      }
    }
    _fail(FailureReason.cloud);
  }

  @override
  Widget build(BuildContext context) {
    final ssid = widget.session.ssid;
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, title: const StepBar(step: 3)),
        body: ScreenBody(
          bottom: OutlinedButton(
            onPressed: () {
              _cancelled = true;
              Navigator.of(context).pop();
            },
            child: const Text('Cancel setup'),
          ),
          children: [
            const SizedBox(height: 12),
            const Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(child: CircularProgressIndicator(strokeWidth: 8, color: AppColors.primary, backgroundColor: AppColors.tint)),
                  Icon(Icons.wifi, size: 48, color: AppColors.primary),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            Text('Connecting to $ssid', style: display(26), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Keep the app open and your phone near the purifier. This can take up to a minute.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 24),
            CardBox(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                _StepRow('Wi-Fi details sent securely', _state(0)),
                _StepRow('Purifier joining your network', _state(1)),
                _StepRow('Connecting to cloud', _state(2)),
                _StepRow('Receiving first reading', _state(3)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  _RowState _state(int row) {
    // While Bluetooth provisioning runs, the first two rows happen together.
    if (_progress == 0) return row <= 1 ? _RowState.active : _RowState.pending;
    if (row < _progress) return _RowState.done;
    return row == _progress ? _RowState.active : _RowState.pending;
  }
}

enum _RowState { pending, active, done }

class _StepRow extends StatelessWidget {
  const _StepRow(this.label, this.state);
  final String label;
  final _RowState state;

  @override
  Widget build(BuildContext context) {
    Widget icon;
    switch (state) {
      case _RowState.done:
        icon = const CircleAvatar(radius: 14, backgroundColor: AppColors.primary, child: Icon(Icons.check, size: 16, color: Colors.white));
      case _RowState.active:
        icon = const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3));
      case _RowState.pending:
        icon = Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border, width: 2)),
        );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        icon,
        const SizedBox(width: 14),
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontSize: 16,
                color: state == _RowState.pending ? AppColors.muted : AppColors.navy,
                fontWeight: state == _RowState.active ? FontWeight.w600 : FontWeight.w400,
              )),
        ),
      ]),
    );
  }
}

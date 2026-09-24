import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tds_chart.dart';
import '../setup/permissions_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});
  final String deviceId;

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  Device? _device;
  List<HistoryPoint> _history = [];
  String _range = '24h';
  String _metric = 'tds';
  String? _error;

  ApiClient get _api => context.read<AppState>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_api.device(widget.deviceId), _api.history(widget.deviceId, _range)]);
      if (!mounted) return;
      setState(() {
        _device = results[0] as Device;
        _history = results[1] as List<HistoryPoint>;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _setRange(String r) async {
    setState(() => _range = r);
    try {
      final h = await _api.history(widget.deviceId, r);
      if (mounted) setState(() => _history = h);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _rename() async {
    final d = _device!;
    final name = TextEditingController(text: d.name);
    final room = TextEditingController(text: d.room);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename purifier'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: room, decoration: const InputDecoration(labelText: 'Room')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) await _patch({'name': name.text.trim(), 'room': room.text.trim()});
  }

  Future<void> _editLimit() async {
    final d = _device!;
    final ctrl = TextEditingController(text: d.effectiveLimit.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('TDS alert limit'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('You get an alert when purified-water TDS goes above this value.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(suffixText: 'ppm'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final v = int.tryParse(ctrl.text);
    if (ok == true && v != null) await _patch({'tdsLimit': v});
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    try {
      await _api.updateDevice(widget.deviceId, patch);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove purifier?'),
        content: const Text('It will be unlinked from your account and will forget its Wi-Fi. You can add it again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.bad),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.removeDevice(widget.deviceId);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _device;
    final unit = context.watch<AppState>().user?.tempUnit ?? 'C';
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (d != null) IconButton(tooltip: 'Rename', onPressed: _rename, icon: const Icon(Icons.edit_outlined)),
        ],
      ),
      body: d == null
          ? Center(child: _error != null ? Padding(padding: const EdgeInsets.all(24), child: ErrorBanner(_error!)) : const CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                children: [
                  Text(d.name, style: display(28)),
                  const SizedBox(height: 6),
                  Row(children: [
                    StatusDot(color: d.online ? AppColors.primary : AppColors.bad),
                    const SizedBox(width: 6),
                    Text(d.online ? 'Online · updated ${timeAgo(d.lastReading?.at)}' : 'Offline · last seen ${timeAgo(d.lastSeen)}',
                        style: const TextStyle(color: AppColors.muted)),
                  ]),
                  if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: _MetricButton(
                        label: 'TDS (purified)',
                        value: fmt(d.lastReading?.tds),
                        unit: 'ppm',
                        selected: _metric == 'tds',
                        onTap: () => setState(() => _metric = 'tds'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricButton(
                        label: 'Water temp',
                        value: fmtTemp(d.lastReading?.temp, unit).replaceAll(RegExp(r' °[CF]'), ''),
                        unit: unit == 'F' ? '°F' : '°C',
                        selected: _metric == 'temp',
                        onTap: () => setState(() => _metric = 'temp'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  CardBox(
                    padding: const EdgeInsets.fromLTRB(12, 12, 16, 16),
                    child: Column(children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: '24h', label: Text('24 h')),
                          ButtonSegment(value: '7d', label: Text('7 d')),
                          ButtonSegment(value: '30d', label: Text('30 d')),
                        ],
                        selected: {_range},
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => _setRange(s.first),
                      ),
                      const SizedBox(height: 12),
                      HistoryChart(points: _history, metric: _metric, limit: d.effectiveLimit, height: 180, showAxis: true),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  CardBox(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      _InfoRow('Input TDS',
                          d.lastReading?.tdsIn == null ? 'No inlet sensor' : '${fmt(d.lastReading!.tdsIn)} ppm · ${d.lastReading!.removedPercent ?? '—'}% removed'),
                      _InfoRow('TDS alert limit', '${d.effectiveLimit.toStringAsFixed(0)} ppm', onTap: _editLimit),
                      _InfoRow('Room', d.room.isEmpty ? '—' : d.room),
                      _InfoRow('Device ID', d.deviceId),
                      _InfoRow('Firmware', d.firmware ?? '—'),
                      _InfoRow('Change Wi-Fi network', '', action: true, onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PermissionsScreen()));
                      }),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: _remove,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.bad, side: const BorderSide(color: Color(0xFFF0C8C2))),
                    child: const Text('Remove purifier'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MetricButton extends StatelessWidget {
  const _MetricButton({required this.label, required this.value, required this.unit, required this.selected, required this.onTap});
  final String label;
  final String value;
  final String unit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.navy;
    final sub = selected ? AppColors.onDarkMuted : AppColors.muted;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.navy : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: selected ? BorderSide.none : const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 13, color: sub)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(value, style: display(30, color: fg)),
                const SizedBox(width: 4),
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(unit, style: TextStyle(fontSize: 15, color: sub))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.onTap, this.action = false});
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool action;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    color: action ? AppColors.primary : AppColors.muted,
                    fontWeight: action ? FontWeight.w600 : FontWeight.w400,
                  )),
            ),
            if (value.isNotEmpty) Flexible(child: Text(value, textAlign: TextAlign.right)),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 18, color: action ? AppColors.primary : AppColors.muted),
            ],
          ]),
        ),
      );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../config.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tds_chart.dart';
import '../setup/permissions_screen.dart';
import 'device_detail_screen.dart';

/// Home: 0 purifiers → empty state, 1 → full dashboard, 2+ → list.
class DevicesTab extends StatefulWidget {
  const DevicesTab({super.key});

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> with WidgetsBindingObserver {
  Timer? _poll;
  List<HistoryPoint> _singleHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _poll = Timer.periodic(AppConfig.pollInterval, (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final state = context.read<AppState>();
    await state.loadDevices();
    if (state.devices.length == 1) {
      try {
        final h = await state.api.history(state.devices.first.id, '24h');
        if (mounted) setState(() => _singleHistory = h);
      } catch (_) {}
    }
  }

  void _addDevice() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PermissionsScreen()));
    _refresh();
  }

  void _open(Device d) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeviceDetailScreen(deviceId: d.id)));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final devices = state.devices;

    Widget body;
    if (!state.devicesLoaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (devices.isEmpty) {
      body = _EmptyState(onAdd: _addDevice, error: state.devicesError);
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            if (state.devicesError != null) ...[ErrorBanner(state.devicesError!), const SizedBox(height: 12)],
            if (devices.length == 1)
              ..._single(devices.first, state.user?.tempUnit ?? 'C')
            else
              ..._multi(devices, state.user?.tempUnit ?? 'C'),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
            child: Row(
              children: [
                Expanded(child: Text('Home', style: display(32))),
                if (devices.isNotEmpty) RoundIconButton(icon: Icons.add, tooltip: 'Add device', dark: true, onPressed: _addDevice),
              ],
            ),
          ),
          if (devices.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(_summary(devices), style: const TextStyle(color: AppColors.muted, fontSize: 14)),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }

  String _summary(List<Device> devices) {
    final attention = devices.where((d) => !d.online || d.openAlerts.isNotEmpty).length;
    return '${devices.length} purifiers${attention > 0 ? ' · $attention need attention' : ''}';
  }

  List<Widget> _single(Device d, String unit) {
    final r = d.lastReading;
    return [
      Semantics(
        button: true,
        label: 'Open ${d.name}',
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _open(d),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Row(children: [
                            StatusDot(color: d.online ? AppColors.lightBlue : AppColors.bad),
                            const SizedBox(width: 6),
                            Text(d.online ? 'Online · updated ${timeAgo(r?.at)}' : 'Offline · last seen ${timeAgo(d.lastSeen)}',
                                style: const TextStyle(color: AppColors.onDarkMuted, fontSize: 13)),
                          ]),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.onDarkMuted),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('TDS · PURIFIED WATER',
                    style: TextStyle(color: AppColors.onDarkMuted, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmt(r?.tds), style: display(72, color: Colors.white)),
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 12),
                      child: Text('ppm', style: TextStyle(color: AppColors.onDarkMuted, fontSize: 22)),
                    ),
                    const Spacer(),
                    if (r?.tds != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _RangeChip(high: d.highTds || r!.tds! > d.effectiveLimit),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                HistoryChart(points: _singleHistory, metric: 'tds', limit: d.effectiveLimit, dark: true, height: 64),
                const SizedBox(height: 6),
                Text('Last 24 h · dashed line = alert at ${d.effectiveLimit.toStringAsFixed(0)} ppm',
                    style: const TextStyle(color: AppColors.onDarkMuted, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(child: _Tile(icon: Icons.thermostat, label: 'Water temp', value: fmtTemp(r?.temp, unit))),
          const SizedBox(width: 12),
          Expanded(
            child: _Tile(
              icon: Icons.water_drop_outlined,
              label: 'Input TDS',
              value: r?.tdsIn == null ? '—' : '${fmt(r!.tdsIn)} ppm',
              sub: r?.removedPercent == null ? null : '${r!.removedPercent}% removed',
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(onPressed: _addDevice, icon: const Icon(Icons.add), label: const Text('Add another purifier')),
    ];
  }

  List<Widget> _multi(List<Device> devices, String unit) {
    final sorted = [...devices]..sort((a, b) => _rank(a).compareTo(_rank(b)));
    return [
      for (final d in sorted) ...[
        _DeviceRow(device: d, unit: unit, onTap: () => _open(d)),
        const SizedBox(height: 10),
      ],
    ];
  }

  // Offline first, then high TDS, then the rest.
  int _rank(Device d) => !d.online ? 0 : (d.highTds ? 1 : 2);
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.high});
  final bool high;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: high ? AppColors.warn : AppColors.lightBlue, borderRadius: BorderRadius.circular(20)),
        // TDS alone can't confirm water is safe, so we never say "safe to drink".
        child: Text(high ? 'Above limit' : 'Within range',
            style: const TextStyle(color: AppColors.navy, fontSize: 13, fontWeight: FontWeight.w600)),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value, this.sub});
  final IconData icon;
  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) => CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            Text(value, style: display(24)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ],
        ),
      );
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.unit, required this.onTap});
  final Device device;
  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = device;
    final r = d.lastReading;
    final Color statusColor;
    final String status;
    Color border = AppColors.border;
    if (!d.online) {
      statusColor = AppColors.bad;
      status = 'Offline · ${timeAgo(d.lastSeen)}';
      border = const Color(0xFFF0C8C2);
    } else if (d.highTds) {
      statusColor = AppColors.warn;
      status = 'TDS above limit · ${fmtTemp(r?.temp, unit)}';
      border = const Color(0xFFF3D3B0);
    } else {
      statusColor = AppColors.primary;
      status = '${d.room.isEmpty ? 'Online' : d.room} · ${fmtTemp(r?.temp, unit)}';
    }

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(children: [
                      StatusDot(color: statusColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(status,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: !d.online ? AppColors.bad : (d.highTds ? AppColors.warnText : AppColors.muted),
                              fontWeight: !d.online || d.highTds ? FontWeight.w600 : FontWeight.w400,
                            )),
                      ),
                    ]),
                  ],
                ),
              ),
              if (!d.online)
                const Text('Fix', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmt(r?.tds), style: display(26, color: d.highTds ? AppColors.warnText : AppColors.navy)),
                    const Text('ppm', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, this.error});
  final VoidCallback onAdd;
  final String? error;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(color: AppColors.tint, shape: BoxShape.circle),
              child: const Icon(Icons.bluetooth_searching, size: 70, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text('Connect Your Purifier', style: display(26), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
              'Pair with your ESP32 TDS Monitor over Bluetooth to configure Wi-Fi and view live TDS metrics.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.45, color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.bluetooth),
                label: const Text('Setup Purifier over Bluetooth', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(
                'Note: Standalone mode (Server not connected). You can still pair and configure ESP32 directly via Bluetooth.',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ErrorBanner(message),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
}

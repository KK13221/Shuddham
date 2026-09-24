import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'permissions_screen.dart';
import 'setup_session.dart';

class SetupDoneScreen extends StatefulWidget {
  const SetupDoneScreen({super.key, required this.session});
  final SetupSession session;

  @override
  State<SetupDoneScreen> createState() => _SetupDoneScreenState();
}

class _SetupDoneScreenState extends State<SetupDoneScreen> {
  static const _rooms = ['Kitchen', 'Dining', 'Pantry', 'Office'];
  late final _name = TextEditingController(text: 'Kitchen purifier');
  String _room = 'Kitchen';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<bool> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<AppState>();
    try {
      await state.api.updateDevice(widget.session.deviceId, {'name': _name.text.trim().isEmpty ? 'My purifier' : _name.text.trim(), 'room': _room});
      await state.loadDevices();
      return true;
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newRoom() async {
    final ctrl = TextEditingController();
    final room = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New room'),
        content: TextField(controller: ctrl, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (room != null && room.isNotEmpty) setState(() => _room = room);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.session.device.lastReading;
    final rooms = {..._rooms, _room}.toList();
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: ScreenBody(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
          bottom: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BusyButton(
              label: 'Done',
              busy: _busy,
              onPressed: () async {
                if (await _save() && context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
              },
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      if (await _save() && context.mounted) {
                        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PermissionsScreen()));
                      }
                    },
              child: const Text('Add another purifier'),
            ),
          ]),
          children: [
            const CircleAvatar(radius: 32, backgroundColor: AppColors.primary, child: Icon(Icons.check, size: 32, color: Colors.white)),
            const SizedBox(height: 14),
            Text('Your purifier is online', style: display(30)),
            const SizedBox(height: 22),
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('First reading · just now', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 14, children: [
                      Text('${fmt(r?.tds)} ppm TDS', style: display(26)),
                      Text(fmtTemp(r?.temp, context.watch<AppState>().user?.tempUnit ?? 'C'), style: display(20)),
                    ]),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    StatusDot(color: AppColors.primary),
                    SizedBox(width: 6),
                    Text('Live', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            const FieldLabel('Name'),
            TextField(controller: _name, textCapitalization: TextCapitalization.sentences),
            const SizedBox(height: 18),
            const FieldLabel('Room'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final room in rooms)
                ChoiceChip(
                  label: Text(room),
                  selected: room == _room,
                  onSelected: (_) => setState(() => _room = room),
                  selectedColor: AppColors.navy,
                  labelStyle: TextStyle(color: room == _room ? Colors.white : AppColors.navy, fontWeight: FontWeight.w600),
                  showCheckmark: false,
                ),
              ActionChip(label: const Text('+ New room'), onPressed: _newRoom),
            ]),
            if (_error != null) ...[const SizedBox(height: 14), ErrorBanner(_error!)],
          ],
        ),
      ),
    );
  }
}

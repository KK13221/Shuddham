import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _update(BuildContext context, Map<String, dynamic> patch) async {
    try {
      await context.read<AppState>().updatePrefs(patch);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editProfile(BuildContext context) async {
    final user = context.read<AppState>().user!;
    final name = TextEditingController(text: user.name);
    final email = TextEditingController(text: user.email ?? '');
    final pincode = TextEditingController(text: user.pincode ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: pincode, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pincode')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _update(context, {'name': name.text.trim(), 'email': email.text.trim(), 'pincode': pincode.text.trim()});
    }
  }

  Future<void> _setPassword(BuildContext context) async {
    final state = context.read<AppState>();
    if (state.user?.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add an email to your profile first')));
      return;
    }
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email login password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password', helperText: 'At least 8 characters'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await state.api.setPassword(ctrl.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password saved. You can now log in with email.')));
      }
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    if (user == null) return const Center(child: CircularProgressIndicator());
    final contact = [if (user.phone != null) '+91 ${user.phone}', if (user.email != null) user.email!].join(' · ');

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Text('Profile', style: display(32)),
          const SizedBox(height: 20),
          CardBox(
            child: InkWell(
              onTap: () => _editProfile(context),
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary,
                  child: Text(user.initials, style: display(22, color: Colors.white)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(contact, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                  ]),
                ),
                const Text('Edit', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const _Section('Alerts'),
          CardBox(
            padding: EdgeInsets.zero,
            child: Column(children: [
              SwitchListTile(
                title: const Text('High TDS alerts'),
                value: user.highTdsAlerts,
                onChanged: (v) => _update(context, {'prefs': {'highTdsAlerts': v}}),
              ),
              const Divider(height: 1, color: AppColors.line),
              SwitchListTile(
                title: const Text('Purifier offline alerts'),
                value: user.offlineAlerts,
                onChanged: (v) => _update(context, {'prefs': {'offlineAlerts': v}}),
              ),
              const Divider(height: 1, color: AppColors.line),
              ListTile(
                title: const Text('Temperature unit'),
                trailing: SegmentedButton<String>(
                  segments: const [ButtonSegment(value: 'C', label: Text('°C')), ButtonSegment(value: 'F', label: Text('°F'))],
                  selected: {user.tempUnit},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => _update(context, {'prefs': {'tempUnit': s.first}}),
                ),
              ),
            ]),
          ),
          const _Section('Account'),
          CardBox(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                title: const Text('My purifiers'),
                trailing: Text('${state.devices.length}', style: const TextStyle(color: AppColors.muted)),
              ),
              const Divider(height: 1, color: AppColors.line),
              ListTile(
                title: const Text('Email login password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _setPassword(context),
              ),
              const Divider(height: 1, color: AppColors.line),
              ListTile(
                title: const Text('Help & support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Help & support'),
                    content: const Text('[Support phone / WhatsApp / email – add Shuddham’s contact details here]'),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => context.read<AppState>().logout(),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.bad, side: const BorderSide(color: Color(0xFFF0C8C2))),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 0, 8),
        child: Text(title.toUpperCase(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: AppColors.muted)),
      );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../home/home_shell.dart';

/// Enter the 6-digit code. For sign-up, [profile] carries name/email/pincode.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone, this.profile});
  final String phone;
  final Map<String, String>? profile;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _resendIn = 30;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendIn = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendIn <= 1) t.cancel();
      if (mounted) setState(() => _resendIn = (_resendIn - 1).clamp(0, 30));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<AppState>();
    try {
      final (token, user) = await state.api.verifyOtp(widget.phone, _code.text, profile: widget.profile);
      await state.setSession(token, user);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeShell()), (_) => false);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      await context.read<AppState>().api.sendOtp(widget.phone, signup: widget.profile != null);
      _startTimer();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New OTP sent')));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masked = '+91 ${widget.phone.substring(0, 5)} ${widget.phone.substring(5)}';
    return Scaffold(
      appBar: AppBar(),
      body: ScreenBody(
        bottom: BusyButton(label: widget.profile != null ? 'Verify & create account' : 'Verify', busy: _busy, onPressed: _verify),
        children: [
          Heading('Enter the code', subtitle: 'We sent a 6-digit code to $masked.'),
          const SizedBox(height: 28),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            textAlign: TextAlign.center,
            style: display(32).copyWith(letterSpacing: 14),
            decoration: const InputDecoration(hintText: '••••••', semanticCounterText: 'One-time code'),
            onChanged: (v) {
              if (v.length == 6) _verify();
            },
          ),
          if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
          const SizedBox(height: 16),
          Center(
            child: _resendIn > 0
                ? Text('Resend code in $_resendIn s', style: const TextStyle(color: AppColors.muted))
                : TextButton(onPressed: _resend, child: const Text('Resend code')),
          ),
          Center(
            child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Change number')),
          ),
        ],
      ),
    );
  }
}

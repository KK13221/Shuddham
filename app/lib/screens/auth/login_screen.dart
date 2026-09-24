import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'login_email_screen.dart';
import 'otp_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().api.sendOtp(phone, signup: false);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtpScreen(phone: phone)));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenBody(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
        bottom: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('New to Shuddham?', style: TextStyle(color: AppColors.muted, fontSize: 15)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
                  child: const Text('Create an account'),
                ),
              ],
            ),
            const Text(
              'By continuing you agree to our Terms and Privacy Policy.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        children: [
          Center(child: Image.asset('assets/images/logo_mark.png', width: 84, height: 85)),
          const SizedBox(height: 12),
          Center(child: Image.asset('assets/images/logo_wordmark.png', width: 200, semanticLabel: 'Shuddham Water Solutions')),
          const SizedBox(height: 32),
          const Heading('Welcome back', subtitle: 'Log in with your mobile number. We’ll send you a one-time code.'),
          const SizedBox(height: 28),
          const FieldLabel('Mobile number'),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            style: const TextStyle(fontSize: 17),
            decoration: const InputDecoration(
              hintText: '10-digit number',
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 16, right: 10),
                child: Text('+91', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.navy)),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
            ),
            onSubmitted: (_) => _sendOtp(),
          ),
          if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
          const SizedBox(height: 20),
          BusyButton(label: 'Send OTP', busy: _busy, onPressed: _sendOtp),
          const SizedBox(height: 20),
          const Row(children: [
            Expanded(child: Divider(color: AppColors.border)),
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: AppColors.muted))),
            Expanded(child: Divider(color: AppColors.border)),
          ]),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginEmailScreen())),
            icon: const Icon(Icons.mail_outline, size: 20),
            label: const Text('Log in with email'),
          ),
        ],
      ),
    );
  }
}

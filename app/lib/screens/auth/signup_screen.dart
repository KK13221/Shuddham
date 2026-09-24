import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'otp_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pincode = TextEditingController();
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_agreed) {
      setState(() => _error = 'Please accept the Terms and Privacy Policy');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final phone = _phone.text;
    try {
      await context.read<AppState>().api.sendOtp(phone, signup: true);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OtpScreen(phone: phone, profile: {
          'name': _name.text.trim(),
          if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
          'pincode': _pincode.text,
        }),
      ));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Image.asset('assets/images/logo_mark.png', width: 40, height: 40), centerTitle: true),
      body: Form(
        key: _form,
        child: ScreenBody(
          bottom: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BusyButton(label: 'Create account', busy: _busy, onPressed: _submit),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Already have an account?', style: TextStyle(color: AppColors.muted, fontSize: 15)),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Log in')),
                ],
              ),
            ],
          ),
          children: [
            const Heading('Create your account',
                subtitle: 'Track your purifier’s TDS and temperature, and get alerts when something’s off.'),
            const SizedBox(height: 22),
            const FieldLabel('Full name'),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(hintText: 'Your name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            const FieldLabel('Mobile number'),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              decoration: const InputDecoration(
                hintText: '10-digit number',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 16, right: 10),
                  child: Text('+91', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.navy)),
                ),
                prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
              ),
              validator: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v ?? '') ? null : 'Enter a valid 10-digit mobile number',
            ),
            const SizedBox(height: 16),
            const FieldLabel('Email (optional)'),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(hintText: 'name@example.com'),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s) ? null : 'Enter a valid email';
              },
            ),
            const SizedBox(height: 16),
            const FieldLabel('Pincode'),
            TextFormField(
              controller: _pincode,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              decoration: const InputDecoration(hintText: '6-digit pincode', helperText: 'Used to assign service in your area.'),
              validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '') ? null : 'Enter a 6-digit pincode',
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I agree to the Terms and Privacy Policy', style: TextStyle(fontSize: 14, color: AppColors.muted)),
            ),
            if (_error != null) ErrorBanner(_error!),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'auth/login_screen.dart';
import 'home/home_shell.dart';

/// Animated logo: the drop falls in and bounces, ripples spread, the wordmark fades up.
/// Meanwhile the saved session is restored; the app moves on once both are done.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));

  late final Animation<double> _dropY = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: -260.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0).chain(CurveTween(curve: Curves.easeOut)), weight: 12),
    TweenSequenceItem(tween: Tween(begin: -12.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 12),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 36),
  ]).animate(_c);

  late final Animation<double> _dropOpacity =
      CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.2, curve: Curves.easeOut));
  late final Animation<double> _ripple = CurvedAnimation(parent: _c, curve: const Interval(0.38, 0.9, curve: Curves.easeOut));
  late final Animation<double> _word = CurvedAnimation(parent: _c, curve: const Interval(0.5, 0.8, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final anim = reduceMotion ? Future<void>.value() : _c.forward().orCancel.catchError((_) {});
    if (reduceMotion) _c.value = 1;
    final state = context.read<AppState>();
    final results = await Future.wait([state.restore(), anim]);
    if (!mounted) return;
    final loggedIn = results.first as bool;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => loggedIn ? const HomeShell() : const LoginScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 220,
                height: 200,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    for (final delay in [0.0, 0.15])
                      Positioned(
                        bottom: 8,
                        child: Opacity(
                          opacity: (1 - ((_ripple.value - delay).clamp(0.0, 1.0))) * (_ripple.value > delay ? 0.7 : 0),
                          child: Transform.scale(
                            scale: 0.3 + 1.6 * (_ripple.value - delay).clamp(0.0, 1.0),
                            child: Container(
                              width: 170,
                              height: 34,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.all(Radius.elliptical(85, 17)),
                                border: Border.all(color: delay == 0 ? const Color(0xFF1E73D8) : AppColors.navy, width: 2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Transform.translate(
                      offset: Offset(0, _dropY.value),
                      child: Opacity(
                        opacity: _dropOpacity.value,
                        child: Image.asset('assets/images/logo_mark.png', width: 190, height: 192, semanticLabel: 'Shuddham'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Opacity(
                opacity: _word.value,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - _word.value)),
                  child: Image.asset('assets/images/logo_wordmark.png', width: 260, semanticLabel: 'Shuddham Water Solutions'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

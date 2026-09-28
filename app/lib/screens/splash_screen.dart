import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'auth/login_screen.dart';
import 'home/home_shell.dart';

/// Splash screen faithfully matching the design in design/screens/Splash.html:
/// - Water drop logo mark with dynamic gravity drop, impact squash, and settling bounce
/// - Expanding concentric water ripples (vibrant blue & deep navy)
/// - Sliding & fading brand wordmark
/// - Slim bottom progress loading bar
/// - Fully compatible across Android 9 to Android 13/14+
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _navigated = false;
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateNext();
      }
    });

    // Start background session restore immediately
    _initSession();

    // Ensure animation starts only after the first frame has painted on device
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Precache images to prevent any frame drops or decode stutter
      precacheImage(const AssetImage('assets/images/logo_mark.png'), context);
      precacheImage(const AssetImage('assets/images/logo_wordmark.png'), context);

      final reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
      if (reduceMotion) {
        _controller.value = 1.0;
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) _navigateNext();
        });
      } else {
        _controller.forward();
      }
    });
  }

  Future<void> _initSession() async {
    try {
      final state = context.read<AppState>();
      final loggedIn = await state.restore();
      if (mounted) {
        _isLoggedIn = loggedIn;
      }
    } catch (_) {
      if (mounted) {
        _isLoggedIn = false;
      }
    }
  }

  void _navigateNext() {
    if (_navigated || !mounted) return;
    _navigated = true;

    final loggedIn = _isLoggedIn ?? false;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            loggedIn ? const HomeShell() : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- Animation Interpolation Helpers ---
  double _lerp(double t, double t0, double t1, double y0, double y1) {
    if (t <= t0) return y0;
    if (t >= t1) return y1;
    final progress = ((t - t0) / (t1 - t0)).clamp(0.0, 1.0);
    return y0 + (y1 - y0) * progress;
  }

  double _curvedLerp(double t, double t0, double t1, double y0, double y1, Curve curve) {
    if (t <= t0) return y0;
    if (t >= t1) return y1;
    final progress = curve.transform(((t - t0) / (t1 - t0)).clamp(0.0, 1.0));
    return y0 + (y1 - y0) * progress;
  }

  // Keyframes matching design/screens/Splash.html:
  // 0% -> translateY(-260px) scale(.55) opacity: 0
  // 18% -> opacity: 1
  // 30% -> translateY(0) scale(1.06, .94)
  // 37% -> translateY(-10px) scale(.98, 1.02)
  // 44% -> translateY(0) scale(1)
  double _getDropY(double t) {
    if (t < 0.30) {
      return _curvedLerp(t, 0.0, 0.30, -260.0, 0.0, Curves.easeIn);
    } else if (t < 0.37) {
      return _curvedLerp(t, 0.30, 0.37, 0.0, -10.0, Curves.easeOut);
    } else if (t < 0.44) {
      return _curvedLerp(t, 0.37, 0.44, -10.0, 0.0, Curves.easeInOut);
    }
    return 0.0;
  }

  double _getDropScaleX(double t) {
    if (t < 0.30) {
      return _curvedLerp(t, 0.0, 0.30, 0.55, 1.06, Curves.easeIn);
    } else if (t < 0.37) {
      return _curvedLerp(t, 0.30, 0.37, 1.06, 0.98, Curves.easeInOut);
    } else if (t < 0.44) {
      return _curvedLerp(t, 0.37, 0.44, 0.98, 1.0, Curves.easeInOut);
    }
    return 1.0;
  }

  double _getDropScaleY(double t) {
    if (t < 0.30) {
      return _curvedLerp(t, 0.0, 0.30, 0.55, 0.94, Curves.easeIn);
    } else if (t < 0.37) {
      return _curvedLerp(t, 0.30, 0.37, 0.94, 1.02, Curves.easeInOut);
    } else if (t < 0.44) {
      return _curvedLerp(t, 0.37, 0.44, 1.02, 1.0, Curves.easeInOut);
    }
    return 1.0;
  }

  double _getDropOpacity(double t) {
    if (t < 0.18) {
      return _curvedLerp(t, 0.0, 0.18, 0.0, 1.0, Curves.easeIn);
    }
    return 1.0;
  }

  // Ripple 1: 30% hit -> scale .2 to 1.9, opacity 0 to .7 to 0
  double _getRipple1Scale(double t) {
    if (t < 0.30) return 0.2;
    if (t < 0.34) {
      return _lerp(t, 0.30, 0.34, 0.2, 0.45);
    }
    if (t < 0.70) {
      return _curvedLerp(t, 0.34, 0.70, 0.45, 1.9, Curves.easeOut);
    }
    return 1.9;
  }

  double _getRipple1Opacity(double t) {
    if (t < 0.30) return 0.0;
    if (t < 0.34) {
      return _lerp(t, 0.30, 0.34, 0.0, 0.70);
    }
    if (t < 0.70) {
      return _curvedLerp(t, 0.34, 0.70, 0.70, 0.0, Curves.easeOut);
    }
    return 0.0;
  }

  // Ripple 2: delayed by ~6% (.25s / 4.2s)
  double _getRipple2Scale(double t) {
    if (t < 0.36) return 0.2;
    if (t < 0.40) {
      return _lerp(t, 0.36, 0.40, 0.2, 0.45);
    }
    if (t < 0.76) {
      return _curvedLerp(t, 0.40, 0.76, 0.45, 1.9, Curves.easeOut);
    }
    return 1.9;
  }

  double _getRipple2Opacity(double t) {
    if (t < 0.36) return 0.0;
    if (t < 0.40) {
      return _lerp(t, 0.36, 0.40, 0.0, 0.70);
    }
    if (t < 0.76) {
      return _curvedLerp(t, 0.40, 0.76, 0.70, 0.0, Curves.easeOut);
    }
    return 0.0;
  }

  // Wordmark: 42% -> 58% translateY(18px -> 0px), opacity(0 -> 1)
  double _getWordmarkY(double t) {
    if (t < 0.42) return 18.0;
    if (t < 0.58) {
      return _curvedLerp(t, 0.42, 0.58, 18.0, 0.0, Curves.easeOut);
    }
    return 0.0;
  }

  double _getWordmarkOpacity(double t) {
    if (t < 0.42) return 0.0;
    if (t < 0.58) {
      return _curvedLerp(t, 0.42, 0.58, 0.0, 1.0, Curves.easeIn);
    }
    return 1.0;
  }

  // Progress Bar: 45% -> 88% width 0 -> 100%
  double _getProgressBarWidthFactor(double t) {
    if (t < 0.45) return 0.0;
    if (t < 0.88) {
      return _curvedLerp(t, 0.45, 0.88, 0.0, 1.0, Curves.easeInOut);
    }
    return 1.0;
  }

  Widget _buildRipple({
    required double scale,
    required double opacity,
    required Color color,
  }) {
    if (opacity <= 0.005 || scale <= 0.01) {
      return const SizedBox(width: 170, height: 34);
    }

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: CustomPaint(
          size: const Size(170, 34),
          painter: _RipplePainter(color: color, strokeWidth: 2.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _navigateNext, // Tap anywhere to skip smoothly
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;

              final dropY = _getDropY(t);
              final dropScaleX = _getDropScaleX(t);
              final dropScaleY = _getDropScaleY(t);
              final dropOpacity = _getDropOpacity(t);

              final r1Scale = _getRipple1Scale(t);
              final r1Opacity = _getRipple1Opacity(t);

              final r2Scale = _getRipple2Scale(t);
              final r2Opacity = _getRipple2Opacity(t);

              final wordmarkY = _getWordmarkY(t);
              final wordmarkOpacity = _getWordmarkOpacity(t);

              final progressFactor = _getProgressBarWidthFactor(t);

              return Stack(
                children: [
                  // Center Branding Content
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo Mark Container with Ripples
                        SizedBox(
                          width: 190,
                          height: 192,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // Ripple 2: Dark Blue (#173A8C), phase delayed
                              Positioned(
                                bottom: 8,
                                left: (190 - 170) / 2,
                                child: _buildRipple(
                                  scale: r2Scale,
                                  opacity: r2Opacity,
                                  color: const Color(0xFF173A8C),
                                ),
                              ),

                              // Ripple 1: Vibrant Water Blue (#1E73D8)
                              Positioned(
                                bottom: 8,
                                left: (190 - 170) / 2,
                                child: _buildRipple(
                                  scale: r1Scale,
                                  opacity: r1Opacity,
                                  color: const Color(0xFF1E73D8),
                                ),
                              ),

                              // Dropping Water Mark Logo
                              Transform.translate(
                                offset: Offset(0, dropY),
                                child: Transform.scale(
                                  scaleX: dropScaleX,
                                  scaleY: dropScaleY,
                                  alignment: Alignment.center,
                                  child: Opacity(
                                    opacity: dropOpacity.clamp(0.0, 1.0),
                                    child: Image.asset(
                                      'assets/images/logo_mark.png',
                                      width: 190,
                                      height: 192,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 26),

                        // Logo Wordmark with Upward Slide & Fade
                        Transform.translate(
                          offset: Offset(0, wordmarkY),
                          child: Opacity(
                            opacity: wordmarkOpacity.clamp(0.0, 1.0),
                            child: Image.asset(
                              'assets/images/logo_wordmark.png',
                              width: 260,
                              height: 52,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Progress Bar
                  Positioned(
                    bottom: math.max(
                      64.0,
                      MediaQuery.of(context).padding.bottom + 24.0,
                    ),
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Container(
                          width: 120,
                          height: 4,
                          color: const Color(0xFFE4ECF7),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progressFactor.clamp(0.0, 1.0),
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1553B8),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the water ripple ellipse
class _RipplePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _RipplePainter({
    required this.color,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    final rect = Offset.zero & size;
    canvas.drawOval(rect.deflate(strokeWidth / 2), paint);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
  }
}

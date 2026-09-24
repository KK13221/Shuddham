import 'package:flutter/material.dart';

import '../theme.dart';

/// Screen padding + scroll that keeps the primary button at the bottom on tall phones.
class ScreenBody extends StatelessWidget {
  const ScreenBody({super.key, required this.children, this.bottom, this.padding = const EdgeInsets.fromLTRB(24, 8, 24, 24)});

  final List<Widget> children;
  final Widget? bottom;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - padding.vertical),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...children,
                  if (bottom != null) ...[const Spacer(), const SizedBox(height: 24), bottom!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Heading extends StatelessWidget {
  const Heading(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: display(30)),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.muted)),
        ],
      ],
    );
  }
}

/// Three-segment progress bar used during setup.
class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.step, this.total = 3});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= total; i++) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i <= step ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < total) const SizedBox(width: 6),
        ],
        const SizedBox(width: 12),
        Text('$step of $total', style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color = Colors.white, this.borderColor = AppColors.border});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor)),
      child: child,
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      );
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.badBg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 18, color: Color(0xFF9B1C1C)),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF9B1C1C), fontSize: 14, height: 1.4))),
          ],
        ),
      );
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Primary button with a loading state.
class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(label),
      );
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onPressed, required this.tooltip, this.dark = false});
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool dark;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        style: IconButton.styleFrom(
          fixedSize: const Size(44, 44),
          backgroundColor: dark ? AppColors.navy : Colors.white,
          foregroundColor: dark ? Colors.white : AppColors.navy,
          side: dark ? null : const BorderSide(color: AppColors.border),
        ),
      );
}

String timeAgo(DateTime? t) {
  if (t == null) return 'never';
  final s = DateTime.now().difference(t).inSeconds;
  if (s < 10) return 'just now';
  if (s < 60) return '$s s ago';
  final m = (s / 60).round();
  if (m < 60) return '$m min ago';
  final h = (m / 60).round();
  if (h < 24) return '$h h ago';
  return '${(h / 24).round()} d ago';
}

String fmt(double? v, {int decimals = 0}) => v == null ? '—' : v.toStringAsFixed(decimals);

String fmtTemp(double? c, String unit) {
  if (c == null) return '—';
  return unit == 'F' ? '${(c * 9 / 5 + 32).toStringAsFixed(1)} °F' : '${c.toStringAsFixed(1)} °C';
}

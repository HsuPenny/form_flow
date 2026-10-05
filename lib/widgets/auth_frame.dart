import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common.dart';

/// The brand backdrop with a back button, the logo and a white card, shared
/// by the pages pushed from the login page.
class AuthFrame extends StatelessWidget {
  const AuthFrame({super.key, required this.child});

  /// The card's content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const BrandBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                child: Column(
                  children: [
                    const LogoMark(size: 56, bare: true),
                    const SizedBox(height: 24),
                    _card(),
                  ],
                ),
              ),
            ),
          ),
          // Align keeps the button its own size; the expanding Stack would
          // otherwise stretch it over the whole card.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: '返回',
                  color: Colors.white,
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.base + 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
    );
  }
}

/// Bold title and a muted line under it, at the top of an [AuthFrame] card.
class AuthHeading extends StatelessWidget {
  const AuthHeading(this.title, this.subtitle, {super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            height: 1.6,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// Full-width filled button that shows a spinner while [busy].
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool busy;

  /// Null disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        iconAlignment: IconAlignment.end,
        icon: busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Lightweight press-scale wrapper used by every actionable surface in the
/// app (home hero CTA, learn cards, check tiles, profile menu rows, etc.).
///
/// Scales to 0.97 while a pointer is down, springs back on release, and
/// runs a 120ms ease-out animation so taps feel identical no matter
/// which screen the user is on. Purely cosmetic — no state is leaked to
/// the parent.
///
/// Behaviour intentionally matches the four private `_Pressable` copies
/// that previously lived inline in `home_page.dart`, `learn_screen.dart`,
/// `check_screen.dart`, and `profile_screen.dart`. They were byte-for-byte
/// equivalent; centralising them keeps future micro-interaction tweaks
/// (e.g. swapping the curve or adding a haptic) to a single edit.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

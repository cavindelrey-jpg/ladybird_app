// lib/widgets/app_background.dart
// Every page in the design-system audit either used a flat C.bg color
// or nothing at all (43 confirmed page files, only 8 with any gradient
// anywhere). Rather than hand-edit 43 files with 43 slightly different
// gradients, this is the one shared wrapper the design doc's own
// "Design Tokens" / "Consistency" principles call for — every page
// wraps its Scaffold body in this instead of a bare color.
//
// Usage:
//   Scaffold(
//     body: AppBackground(child: <your existing page content>),
//   )
// Replaces `backgroundColor: C.bg` on the Scaffold — leave that off (or
// keep it as a fallback) since this paints the real background itself.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppBackgroundTint { blue, navy }

class AppBackground extends StatelessWidget {
  final Widget child;
  final AppBackgroundTint tint;
  const AppBackground({super.key, required this.child, this.tint = AppBackgroundTint.blue});

  @override
  Widget build(BuildContext context) {
    final topColor = tint == AppBackgroundTint.navy
        ? C.navy.withValues(alpha: .06)
        : C.primary.withValues(alpha: .05);

    return Stack(children: [
      // The gradient itself: a soft tint at the top fading to the
      // standard flat background by roughly a third of the way down —
      // subtle enough not to fight card content, present enough that
      // the screen doesn't read as flat white/gray.
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [topColor, C.bg],
              stops: const [0.0, 0.35],
            ),
          ),
        ),
      ),
      // Very low-opacity academic watermark shapes, per the design
      // doc's "Educational Personality" rule — decorative only, must
      // never sit where it could reduce text contrast, so it's pinned
      // to the top-right corner, out of the way of body content.
      const Positioned(
        top: 60, right: -20,
        child: Opacity(
          opacity: 0.04,
          child: Icon(Icons.auto_stories_rounded, size: 140, color: C.navy),
        ),
      ),
      child,
    ]);
  }
}

// lib/widgets/app_background.dart
// The shared background wrapper behind ~43 pages. Previous version was a
// flat, near-invisible linear tint (alpha .05) fading to the base gray —
// "subtle enough not to fight card content" was the design goal, and the
// result reads as an unstyled default rather than a designed surface.
//
// This version keeps the exact same contract (Positioned.fill decoration
// behind whatever the page already draws, zero layout impact) but gives
// it real visual character: a warm, asymmetric two-glow lighting setup in
// the brand navy/gold instead of a flat pastel wash — closer to how
// premium apps (Stripe, Linear, Vercel) light a page than to a generic
// "light blue at the top" template gradient.
//
// Usage unchanged:
//   Scaffold(
//     body: AppBackground(child: <your existing page content>),
//   )

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum AppBackgroundTint { blue, navy }

class AppBackground extends StatelessWidget {
  final Widget child;
  final AppBackgroundTint tint;
  const AppBackground({super.key, required this.child, this.tint = AppBackgroundTint.blue});

  @override
  Widget build(BuildContext context) {
    // Reads the dark-aware token set so this doesn't paint a light
    // background underneath a page that switched itself to dark —
    // AppColors.of() falls back to the light palette on pages that
    // haven't been converted yet, so this is safe either way.
    final c = AppColors.of(context);
    final glowA = tint == AppBackgroundTint.navy
        ? c.navy.withValues(alpha: .16)
        : c.primary.withValues(alpha: .13);

    return Stack(children: [
      Positioned.fill(child: ColoredBox(color: c.bg)),
      // Primary light source: an off-center radial glow anchored high and
      // slightly right of center, the way a studio key-light is placed —
      // not dead-center, which reads as a flat "template gradient".
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.4, -1.05),
              radius: 1.15,
              colors: [glowA, glowA.withValues(alpha: 0), Colors.transparent],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ),
      // Fill light: a second, smaller, cooler-toned glow low on the
      // opposite side — this asymmetric two-source setup is what keeps a
      // gradient from reading as a flat "light-blue-at-the-top" wash; it
      // gives the canvas actual depth instead of a single uniform fade.
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.9, -0.55),
              radius: 0.9,
              colors: [
                c.gold.withValues(alpha: .07),
                c.gold.withValues(alpha: 0),
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
      // Decorative watermark — larger and more present than a barely-there
      // 0.04-alpha accent, but still fully out of the way of body content
      // (top-right corner, above where any card grid starts).
      Positioned(
        top: 44, right: -34,
        child: Transform.rotate(
          angle: -0.12,
          child: Opacity(
            opacity: 0.05,
            child: Icon(Icons.auto_stories_rounded, size: 190, color: c.navy),
          ),
        ),
      ),
      Positioned(
        top: 150, right: 60,
        child: Opacity(
          opacity: 0.035,
          child: Icon(Icons.workspace_premium_rounded, size: 56, color: c.gold),
        ),
      ),
      child,
    ]);
  }
}

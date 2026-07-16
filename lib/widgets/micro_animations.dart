// lib/widgets/micro_animations.dart
// Small, self-contained visual polish widgets for the Home redesign
// (TASKS_LOOP6 section 4a) — pure animation, no backend/data of their
// own. Kept separate from the general-purpose widgets.dart library since
// these are Home-specific rather than reused app-wide (yet).

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Scales [child] down slightly while pressed — the "lift" a card gets on
/// tap. Uses a raw [Listener] (not a [GestureDetector]) so it never
/// competes with an inner InkWell/GestureDetector for the tap gesture —
/// it only watches pointer down/up to drive the scale, nothing more.
class TapScale extends StatefulWidget {
  final Widget child;
  const TapScale({super.key, required this.child});

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fades + slides [child] in on first build, staggered by [index] — used
/// for the Quick Access row so icons animate in one after another rather
/// than popping in all at once.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(_fade);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Rotates [child] in a short wiggle, repeated every few seconds while
/// [active] is true — used on the notification bell when there's a real
/// unread count. Never invents the count itself; purely reacts to it.
class WiggleIcon extends StatefulWidget {
  final Widget child;
  final bool active;
  const WiggleIcon({super.key, required this.child, required this.active});

  @override
  State<WiggleIcon> createState() => _WiggleIconState();
}

class _WiggleIconState extends State<WiggleIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.active) _scheduleWiggle();
  }

  @override
  void didUpdateWidget(covariant WiggleIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _scheduleWiggle();
    if (!widget.active && oldWidget.active) _timer?.cancel();
  }

  void _scheduleWiggle() {
    _timer?.cancel();
    _ctrl.forward(from: 0);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _ctrl.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final decay = 1 - _ctrl.value;
        final angle = math.sin(_ctrl.value * math.pi * 6) * 0.18 * decay;
        return Transform.rotate(angle: angle, child: child);
      },
      child: widget.child,
    );
  }
}

/// Slow continuous zoom on [image] — the classic "Ken Burns" effect for a
/// static hero/banner image so it doesn't feel completely inert.
class KenBurnsImage extends StatefulWidget {
  final ImageProvider image;
  const KenBurnsImage({super.key, required this.image});

  @override
  State<KenBurnsImage> createState() => _KenBurnsImageState();
}

class _KenBurnsImageState extends State<KenBurnsImage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))
        ..repeat(reverse: true);
  late final Animation<double> _scale =
      Tween<double>(begin: 1.0, end: 1.09).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
      child: Image(image: widget.image, fit: BoxFit.cover),
    );
  }
}

/// A slim progress bar whose fill animates smoothly whenever [value]
/// changes, instead of jumping — for small real-data indicators like
/// "today's XP toward the daily cap".
class AnimatedMiniBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  const AnimatedMiniBar({super.key, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: v, minHeight: 5,
          backgroundColor: color.withValues(alpha: .15),
          color: color,
        ),
      ),
    );
  }
}

/// Very low-opacity decorative academic-symbol watermark for section
/// backgrounds — decoration only, ignores pointer events so it can never
/// intercept taps meant for real content.
class SectionWatermark extends StatelessWidget {
  final IconData icon;
  final double size;
  final Alignment alignment;
  const SectionWatermark({
    super.key, required this.icon,
    this.size = 120, this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: Icon(icon, size: size, color: Colors.black.withValues(alpha: .035)),
        ),
      ),
    );
  }
}

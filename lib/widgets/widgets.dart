// lib/widgets/widgets.dart
// Academia shared widget library — Material 3, animated, accessible.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ════════════════════════════════════════════════════════════════════════════
// BUTTONS
// ════════════════════════════════════════════════════════════════════════════

class PrimaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  final IconData? icon;
  const PrimaryBtn({
    super.key, required this.label, required this.onTap,
    this.loading = false, this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        child: loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                Text(label, style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
      ),
    );
  }
}

class SecondaryBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  const SecondaryBtn({super.key, required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CARDS
// ════════════════════════════════════════════════════════════════════════════

/// Standard Academia card with consistent shadow and border. Tappable cards
/// get a real Material ripple + a light haptic tick — GestureDetector gives
/// zero visual/tactile response on tap, which is the single biggest reason
/// the app read as unresponsive; this fixes it everywhere ACard is reused.
class ACard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  final double borderRadius;
  const ACard({
    super.key, required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color, this.onTap, this.borderRadius = Rad.md,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final decoratedChild = Container(
      decoration: BoxDecoration(
        color: color ?? C.surf,
        borderRadius: radius,
        border: Border.all(color: C.bdr),
        boxShadow: Shad.sm,
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return decoratedChild;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap!();
        },
        child: decoratedChild,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EMPTY STATES
// ════════════════════════════════════════════════════════════════════════════

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({
    super.key, required this.icon, required this.title,
    this.subtitle, this.actionLabel, this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: C.surf3, borderRadius: BorderRadius.circular(Rad.xl)),
            child: Icon(icon, size: 36, color: C.muted),
          ),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.sora(
              fontSize: 16, fontWeight: FontWeight.w700, color: C.txt),
              textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: GoogleFonts.inter(fontSize: 13, color: C.txt2),
                textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: 160,
              child: ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LOADING STATES
// ════════════════════════════════════════════════════════════════════════════

/// Animated shimmer placeholder for loading lists.
class ShimmerCard extends StatefulWidget {
  final double height;
  const ShimmerCard({super.key, this.height = 80});
  @override State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: widget.height,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Color.lerp(C.bdr2, C.bdr, _anim.value)!,
            Color.lerp(C.bdr, C.bdr2, _anim.value)!,
          ]),
          borderRadius: BorderRadius.circular(Rad.md),
        ),
      ),
    );
  }
}

/// A single shimmering rounded line — for text placeholders. Width can be
/// fixed or fractional (pass a width, or wrap in Expanded/SizedBox).
class ShimmerLine extends StatefulWidget {
  final double width;
  final double height;
  const ShimmerLine({super.key, this.width = double.infinity, this.height = 14});
  @override State<ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<ShimmerLine> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  late final Animation<double> _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(C.bdr2, C.bdr, _anim.value),
          borderRadius: BorderRadius.circular(Rad.xs / 2),
        ),
      ),
    );
  }
}

/// A shimmering circle — for avatar placeholders.
class ShimmerCircle extends StatefulWidget {
  final double size;
  const ShimmerCircle({super.key, this.size = 40});
  @override State<ShimmerCircle> createState() => _ShimmerCircleState();
}

class _ShimmerCircleState extends State<ShimmerCircle> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  late final Animation<double> _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          color: Color.lerp(C.bdr2, C.bdr, _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// A shimmering block — for image/thumbnail placeholders. Same primitive
/// as ShimmerCard but without the bottom margin, so it composes cleanly
/// inside a larger skeleton layout.
class ShimmerBlock extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;
  const ShimmerBlock({super.key, this.width, this.height = 80, this.borderRadius = Rad.md});
  @override State<ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<ShimmerBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  late final Animation<double> _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(C.bdr2, C.bdr, _anim.value),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// Standard loading spinner with optional message.
class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(message!, style: GoogleFonts.inter(color: C.txt2, fontSize: 13)),
        ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ERROR STATES
// ════════════════════════════════════════════════════════════════════════════

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: C.redb, borderRadius: BorderRadius.circular(Rad.xl)),
            child: const Icon(Icons.wifi_off_rounded, size: 32, color: C.red),
          ),
          const SizedBox(height: 16),
          Text('Something went wrong', style: GoogleFonts.sora(
              fontSize: 16, fontWeight: FontWeight.w700, color: C.txt)),
          const SizedBox(height: 8),
          Text(message, style: GoogleFonts.inter(fontSize: 13, color: C.txt2),
              textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BADGES & CHIPS
// ════════════════════════════════════════════════════════════════════════════

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bg;
  const StatusBadge({super.key, required this.label, required this.color, this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(Rad.xs),
      ),
      child: Text(label, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class GradeBadge extends StatelessWidget {
  final String grade;
  const GradeBadge({super.key, required this.grade});

  static Color _color(String g) {
    switch (g) {
      case 'A': return C.grn;
      case 'B': return C.blu;
      case 'C': return C.gold;
      case 'D': return C.org;
      default:  return C.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = _color(grade);
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
          color: col.withValues(alpha: .12), borderRadius: BorderRadius.circular(Rad.xs)),
      child: Center(child: Text(grade,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: col))),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ANNOUNCEMENT CARD
// ════════════════════════════════════════════════════════════════════════════

class AnnCard extends StatelessWidget {
  final String tag, title, body, date;
  final Color accent;
  final bool urgent;
  const AnnCard({
    super.key, required this.tag, required this.title,
    required this.body, required this.date,
    required this.accent, this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return ACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusBadge(label: tag, color: accent),
          if (urgent) ...[
            const SizedBox(width: 8),
            StatusBadge(label: 'URGENT', color: C.red, bg: C.redb),
          ],
          const Spacer(),
          Text(date, style: GoogleFonts.inter(fontSize: 11, color: C.muted)),
        ]),
        const SizedBox(height: 8),
        Text(title, style: GoogleFonts.sora(
            fontSize: 14, fontWeight: FontWeight.w700, color: C.txt)),
        const SizedBox(height: 5),
        Text(body, style: GoogleFonts.inter(
            fontSize: 13, color: C.txt2, height: 1.5),
            maxLines: 3, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// AVATARS
// ════════════════════════════════════════════════════════════════════════════

class UserAvatar extends StatelessWidget {
  final String initials;
  final double radius;
  final Color? bg;
  final Color? fg;
  final String? photoUrl;
  final VoidCallback? onTap;
  const UserAvatar({
    super.key, required this.initials, this.radius = 20,
    this.bg, this.fg, this.photoUrl, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = photoUrl != null
        ? CircleAvatar(
            radius: radius,
            backgroundImage: NetworkImage(photoUrl!),
            onBackgroundImageError: (_, __) {},
          )
        : CircleAvatar(
            radius: radius,
            backgroundColor: bg ?? C.primaryBg,
            child: Text(initials, style: TextStyle(
                fontSize: radius * 0.6, fontWeight: FontWeight.w700,
                color: fg ?? C.primary)),
          );
    if (onTap == null) return avatar;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: avatar),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SECTION HEADERS
// ════════════════════════════════════════════════════════════════════════════

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title, style: GoogleFonts.sora(
          fontSize: 14, fontWeight: FontWeight.w700, color: C.txt)),
      const Spacer(),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(action!, style: GoogleFonts.inter(
              fontSize: 12, color: C.primary, fontWeight: FontWeight.w600)),
        ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// STAT CARD
// ════════════════════════════════════════════════════════════════════════════

class StatCard extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color bg, color;
  final String? trend;
  const StatCard({
    super.key, required this.icon, required this.value,
    required this.label, required this.bg, required this.color, this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 20, color: color),
          const Spacer(),
          if (trend != null)
            Text(trend!, style: TextStyle(fontSize: 10, color: color.withValues(alpha: .7))),
        ]),
        const SizedBox(height: 10),
        Text(value, style: GoogleFonts.sora(
            fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: GoogleFonts.inter(
            fontSize: 11, color: color.withValues(alpha: .8))),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ACADEMIA LOGO
// ════════════════════════════════════════════════════════════════════════════

class AcademiaLogo extends StatelessWidget {
  final double size;
  const AcademiaLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logos/academia_logo.png',
      width: size, height: size, fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(size * 0.22)),
        child: Center(child: Text('A', style: GoogleFonts.sora(
            fontSize: size * 0.5, fontWeight: FontWeight.w800, color: C.gold))),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TOAST
// ════════════════════════════════════════════════════════════════════════════

void showToast(BuildContext context, String msg, {bool isError = false}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
    behavior: SnackBarBehavior.floating,
    backgroundColor: isError ? C.red : C.navy,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    duration: Duration(seconds: isError ? 4 : 2),
  ));
}

// ════════════════════════════════════════════════════════════════════════════
// GRADIENT CARD (dashboard hero)
// ════════════════════════════════════════════════════════════════════════════

class GradientCard extends StatelessWidget {
  final List<Color> colors;
  final Widget child;
  final double height;
  const GradientCard({super.key, required this.colors, required this.child, this.height = 130});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(Rad.lg),
        boxShadow: [BoxShadow(
          color: colors.first.withValues(alpha: .3),
          blurRadius: 20, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}

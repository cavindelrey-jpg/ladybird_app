// lib/widgets/widgets.dart
// Academia shared widget library — Material 3, animated, accessible.

import 'dart:io';
import 'package:flutter/material.dart';
import 'action_error_widget.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/public_course.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../config/branding.dart';
import 'chat_media_widgets.dart' show PresenceDot;

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
                Flexible(child: Text(label, style: AppText.button, maxLines: 1, overflow: TextOverflow.ellipsis)),
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
    final ac = AppColors.of(context);
    return SizedBox(
      width: double.infinity, height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Flexible(child: Text(label, style: AppText.subtitle.copyWith(fontSize: 14, color: ac.primary), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
/// A richer alternative to `Container(color: c.withValues(alpha: .1), shape:
/// circle)` — the flat single-alpha tint circle used almost everywhere in
/// the app for icon badges. That pattern is honest but reads as an
/// unstyled default; this adds a diagonal gradient, a hairline ring in the
/// same hue, and a soft color-matched glow so the badge has real depth
/// instead of sitting flush with the surface behind it.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final BorderRadius? radius; // null = circle
  const IconBadge({super.key, required this.icon, required this.color,
      this.size = 44, this.iconSize = 20, this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [color.withValues(alpha: .24), color.withValues(alpha: .09)],
        ),
        shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius,
        border: Border.all(color: color.withValues(alpha: .16), width: 1),
        boxShadow: [BoxShadow(color: color.withValues(alpha: .16),
            blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

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
    final ac = AppColors.of(context);
    final radius = BorderRadius.circular(borderRadius);
    final decoratedChild = Container(
      decoration: BoxDecoration(
        color: color ?? ac.surf,
        borderRadius: radius,
        border: Border.all(color: ac.bdr),
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
    final ac = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 76, height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ac.surf3,
              shape: BoxShape.circle,
              border: Border.all(color: ac.bdr2, width: 1),
            ),
            child: Icon(icon, size: 32, color: ac.muted),
          ),
          const SizedBox(height: 20),
          Text(title, style: AppText.title.copyWith(fontSize: 16),
              textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: AppText.bodySm,
                textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: 180, height: 44,
              child: ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!, style: AppText.button.copyWith(fontSize: 13)),
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
    final ac = AppColors.of(context);
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: widget.height,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Color.lerp(ac.bdr2, ac.bdr, _anim.value)!,
            Color.lerp(ac.bdr, ac.bdr2, _anim.value)!,
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
    final ac = AppColors.of(context);
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(ac.bdr2, ac.bdr, _anim.value),
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
    final ac = AppColors.of(context);
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(
          color: Color.lerp(ac.bdr2, ac.bdr, _anim.value),
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
    final ac = AppColors.of(context);
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(ac.bdr2, ac.bdr, _anim.value),
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
    final ac = AppColors.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 28, height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: ac.primary),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(message!, style: AppText.bodySm),
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
    return ActionErrorWidget(error: message, onRetry: onRetry);
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(Rad.xs),
      ),
      child: Text(label, style: AppText.label.copyWith(
          fontSize: 10, letterSpacing: 0.3, color: color)),
    );
  }
}

class GradeBadge extends StatelessWidget {
  final String grade;
  const GradeBadge({super.key, required this.grade});

  static Color _color(String g, AppColors ac) {
    switch (g) {
      case 'A': return ac.grn;
      case 'B': return ac.blu;
      case 'C': return ac.gold;
      case 'D': return ac.org;
      default:  return ac.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final col = _color(grade, ac);
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
          color: col.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(Rad.xs),
          border: Border.all(color: col.withValues(alpha: .18), width: 1)),
      child: Center(child: Text(grade,
          style: AppText.title.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: col))),
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
  final String? imageUrl;
  const AnnCard({
    super.key, required this.tag, required this.title,
    required this.body, required this.date,
    required this.accent, this.urgent = false, this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ACard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if ((imageUrl ?? '').isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.md)),
            child: Image.network(imageUrl!, height: 140, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              StatusBadge(label: tag, color: accent),
              if (urgent) ...[
                const SizedBox(width: 8),
                StatusBadge(label: 'URGENT', color: ac.red, bg: ac.redBg),
              ],
              const Spacer(),
              Text(date, style: AppText.caption),
            ]),
            const SizedBox(height: 10),
            Text(title, style: AppText.title.copyWith(fontSize: 14)),
            const SizedBox(height: 4),
            Text(body, style: AppText.bodySm,
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ]),
        ),
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

  /// Whether to draw the small presence dot in the bottom-right corner.
  /// Off by default so every existing call site is unaffected.
  final bool showPresenceDot;

  /// Only read when [showPresenceDot] is true. Callers should pass a
  /// REAL signal — e.g. Conversation.isRecentlyActive(userId) — never a
  /// hardcoded true. See messaging.dart's Conversation.activeAt doc
  /// comment for why this project treats presence this way.
  final bool online;

  /// Color the presence dot's ring is drawn in, so it reads as a "cutout"
  /// against whatever surface the avatar sits on. Defaults to
  /// AppColors.surf (the common case — ACard rows); pass ac.bg explicitly
  /// for avatars on the page/AppBar background instead of a card.
  final Color? presenceBorderColor;

  const UserAvatar({
    super.key, required this.initials, this.radius = 20,
    this.bg, this.fg, this.photoUrl, this.onTap,
    this.showPresenceDot = false, this.online = false, this.presenceBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final size = radius * 2;

    Widget avatar;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      avatar = ClipOval(
        child: Image.network(
          photoUrl!,
          width: size, height: size, fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _initialsCircle(ac);
          },
          // The actual fix: on failure, fall back to a REAL initials
          // circle instead of CircleAvatar's silent blank paint.
          errorBuilder: (context, error, stack) => _initialsCircle(ac),
        ),
      );
    } else {
      avatar = _initialsCircle(ac);
    }

    if (showPresenceDot) {
      avatar = Stack(clipBehavior: Clip.none, children: [
        avatar,
        Positioned(
          right: -1, bottom: -1,
          child: PresenceDot(online: online, size: (radius * 0.62).clamp(9, 16),
              borderColor: presenceBorderColor ?? ac.surf),
        ),
      ]);
    }

    if (onTap == null) return avatar;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: avatar),
    );
  }

  Widget _initialsCircle(AppColors ac) => CircleAvatar(
        radius: radius,
        backgroundColor: bg ?? ac.primaryBg,
        child: Text(initials, style: TextStyle(
            fontSize: radius * 0.6, fontWeight: FontWeight.w700,
            color: fg ?? ac.primary)),
      );
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
    final ac = AppColors.of(context);
    return Row(children: [
      Text(title, style: AppText.title.copyWith(fontSize: 14)),
      const Spacer(),
      if (action != null)
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.xs),
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(action!, style: AppText.subtitle.copyWith(fontSize: 12, color: ac.primary)),
            ),
          ),
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
        Text(value, style: AppText.display.copyWith(fontSize: 22, color: color)),
        Text(label, style: AppText.caption.copyWith(color: color.withValues(alpha: .8))),
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
    final ac = AppColors.of(context);
    return Image.asset(
      'assets/logos/academia_logo_square.png',
      width: size, height: size, fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: ac.navy, borderRadius: BorderRadius.circular(size * 0.22)),
        child: Center(child: Text('A', style: AppText.display.copyWith(
            fontSize: size * 0.5, color: ac.gold))),
      ),
    );
  }
}

/// The white-label counterpart to [AcademiaLogo] — reads
/// Branding.current.logoAssetPath instead of the hardcoded Academia
/// file. Falls back to an initials badge in the brand's own color when
/// that asset doesn't exist yet (e.g. Green Hill's real logo hasn't been
/// dropped in at assets/branding/green_hill_logo.png), same resilience
/// pattern as AcademiaLogo's own fallback.
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final b = Branding.current;
    return Image.asset(
      b.logoAssetPath,
      width: size, height: size, fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: b.secondaryColor, borderRadius: BorderRadius.circular(size * 0.22)),
        child: Center(child: Text(b.appName.isNotEmpty ? b.appName[0].toUpperCase() : '?',
            style: AppText.display.copyWith(fontSize: size * 0.5, color: b.accentColor))),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TOAST
// ════════════════════════════════════════════════════════════════════════════

void showToast(BuildContext context, String msg, {bool isError = false}) {
  final ac = AppColors.of(context);
  ScaffoldMessenger.of(context).clearSnackBars();

  // Strip technical exception details if they leaked into the message
  String cleanMsg = msg;
  if (cleanMsg.contains('Exception:') || cleanMsg.contains('PostgrestException')) {
    cleanMsg = 'Something didn\'t quite work. Please check your connection or try again later.';
  }

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(cleanMsg, style: AppText.subtitle.copyWith(color: Colors.white, fontSize: 13)),
    behavior: SnackBarBehavior.floating,
    backgroundColor: ac.navy, // Avoid red for errors per user feedback
    elevation: 6,
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

// ════════════════════════════════════════════════════════════════════════════
// TAG MULTI-SELECT (composer chips — Magazine + Course share this)
// ════════════════════════════════════════════════════════════════════════════

/// Multi-select tag chips with a suggested-list `+` picker and free-text
/// custom entry. Used by both the Magazine and Course composers, in
/// addition to their existing single-select category chips.
class TagMultiSelect extends StatelessWidget {
  final List<String> selected;
  final List<String> suggestions;
  final ValueChanged<List<String>> onChanged;
  const TagMultiSelect({
    super.key, required this.selected, required this.suggestions, required this.onChanged,
  });

  void _toggle(String tag) {
    final next = List<String>.from(selected);
    if (next.contains(tag)) {
      next.remove(tag);
    } else {
      next.add(tag);
    }
    onChanged(next);
  }

  Future<void> _addCustom(BuildContext context) async {
    final ctrl = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Add a tag'),
        content: TextField(
          controller: ctrl, autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Exam Prep'),
          onSubmitted: (v) => Navigator.pop(dCtx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dCtx, ctrl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (tag != null && tag.isNotEmpty && !selected.contains(tag)) {
      onChanged([...selected, tag]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    // Suggested tags first, then any already-selected custom tags not in
    // the suggested list, so a previously typed custom tag still shows up
    // (and can be un-toggled) after the composer reopens.
    final allChips = [...suggestions, ...selected.where((t) => !suggestions.contains(t))];
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        ...allChips.map((tag) {
          final active = selected.contains(tag);
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.selectionClick();
                _toggle(tag);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? ac.goldBg : ac.surf2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? ac.gold : ac.bdr),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (active) ...[
                    Icon(Icons.check_rounded, size: 13, color: ac.gold),
                    const SizedBox(width: 3),
                  ],
                  Text(tag, style: AppText.caption.copyWith(
                      fontSize: 11.5, fontWeight: FontWeight.w700,
                      color: active ? ac.gold : ac.txt2)),
                ]),
              ),
            ),
          );
        }),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _addCustom(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ac.surf2, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ac.bdr, style: BorderStyle.solid),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 14, color: ac.txt2),
                const SizedBox(width: 2),
                Text('Add tag', style: AppText.caption.copyWith(fontSize: 11.5, color: ac.txt2)),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single free-text field with autocomplete against whatever values
/// already exist at this level of the curriculum tree — e.g. typing
/// into the Subject field under "Social Studies" suggests "History"
/// once any course already uses it. Nothing stops a genuinely new
/// value; suggestions are just there to keep the tree from splintering
/// into near-duplicate spellings ("History" vs "history").
/// Curriculum-tree picker: shows existing values (Subject/Level/Topic)
/// as tappable chips so you SELECT one rather than retype it — the
/// only way a new value gets created is via the explicit "+ Create
/// new" chip. This is deliberately stricter than free-text
/// autocomplete: autocomplete still lets someone type "Cameroon" when
/// "Cameroonon" already exists and silently create a duplicate
/// sibling; forcing a tap removes that failure mode entirely.
/// Emoji choices offered when creating a new curriculum node — kept to
/// a small, broadly-applicable set rather than trying to cover every
/// subject; a picture beats "Uncategorized" even if it's only roughly
/// on-topic.
const kCurriculumIconChoices = [
  '📘','📗','📕','🔬','🧮','🌍','💻','🎨','📊','⚗️','🧬','📐','🏛️','🎭','🎵','⚽',
];

class HierarchyPicker extends StatefulWidget {
  final String label;
  final String value;
  final List<String> options;
  final bool enabled;
  final ValueChanged<String> onChanged;

  /// option label -> chosen look, for showing existing nodes as more
  /// than plain text. Missing entries fall back to a letter-avatar.
  final Map<String, CurriculumIcon> icons;

  /// Called with the chosen emoji whenever the user picks one while
  /// creating a new node (empty string if they clear it).
  final ValueChanged<String>? onIconPicked;

  /// Called with the chosen photo file while creating a new node
  /// (null if they clear it). Upload happens on save, not here.
  final ValueChanged<File?>? onImagePicked;

  /// The photo currently staged for the new node, so it survives
  /// rebuilds (e.g. periodic autosave) instead of resetting.
  final File? pickedImage;

  const HierarchyPicker({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icons = const {},
    this.onIconPicked,
    this.onImagePicked,
    this.pickedImage,
    this.enabled = true,
  });

  @override
  State<HierarchyPicker> createState() => _HierarchyPickerState();
}

class _HierarchyPickerState extends State<HierarchyPicker> {
  late bool _creatingNew = widget.value.isNotEmpty && !widget.options.contains(widget.value);
  late final TextEditingController _newCtrl = TextEditingController(text: _creatingNew ? widget.value : '');
  String _newIcon = '';

  @override
  void didUpdateWidget(covariant HierarchyPicker old) {
    super.didUpdateWidget(old);
    // If the value we're holding shows up in the (now-refreshed) options
    // list — e.g. someone else just created "History" while we were
    // mid-typing the same thing — drop out of "creating new" mode.
    if (_creatingNew && widget.options.contains(widget.value)) {
      setState(() => _creatingNew = false);
    }
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    // Photo and emoji are mutually exclusive so the tile shows exactly
    // one thing — picking a photo clears any emoji already chosen.
    setState(() => _newIcon = '');
    widget.onIconPicked?.call('');
    widget.onImagePicked?.call(File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: ac.txt2)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ...widget.options.map((o) {
            final active = !_creatingNew && o == widget.value;
            return _chip(ac, o, active, () {
              setState(() => _creatingNew = false);
              widget.onChanged(o);
            }, icon: widget.icons[o]?.emoji, thumbUrl: widget.icons[o]?.imageUrl);
          }),
          _chip(ac, '+ Create new', _creatingNew, () => setState(() => _creatingNew = true), outline: true),
        ]),
        if (_creatingNew) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _newCtrl,
            autofocus: true,
            enabled: widget.enabled,
            onChanged: widget.onChanged,
            style: AppText.body,
            decoration: InputDecoration(
              hintText: 'New ${widget.label.toLowerCase()}',
              hintStyle: AppText.body.copyWith(color: ac.muted),
              filled: true,
              fillColor: ac.surf2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ac.bdr)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ac.bdr)),
            ),
          ),
          if (widget.onIconPicked != null) ...[
            const SizedBox(height: 8),
            Text('Give it a look (optional) — an emoji, or your own photo',
                style: AppText.caption.copyWith(fontSize: 11, color: ac.txt2)),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Wrap(spacing: 6, runSpacing: 6, children: kCurriculumIconChoices.map((e) {
                  final active = e == _newIcon;
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      setState(() => _newIcon = active ? '' : e);
                      widget.onIconPicked!(_newIcon);
                      if (!active) widget.onImagePicked?.call(null); // mutually exclusive with a photo
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36, height: 36, alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? ac.primaryBg : ac.surf2,
                        shape: BoxShape.circle,
                        border: Border.all(color: active ? ac.primary : ac.bdr),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 17)),
                    ),
                  );
                }).toList()),
              ),
              const SizedBox(width: 10),
              if (widget.pickedImage != null)
                Stack(clipBehavior: Clip.none, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(widget.pickedImage!, width: 44, height: 44, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: -6, right: -6,
                    child: InkWell(
                      onTap: () => widget.onImagePicked?.call(null),
                      child: Container(
                        width: 20, height: 20, alignment: Alignment.center,
                        decoration: BoxDecoration(color: ac.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                      ),
                    ),
                  ),
                ])
              else if (widget.onImagePicked != null)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _pickImage,
                  child: Container(
                    width: 44, height: 44, alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: ac.surf2, borderRadius: BorderRadius.circular(10), border: Border.all(color: ac.bdr)),
                    child: Icon(Icons.add_photo_alternate_outlined, size: 20, color: ac.txt2),
                  ),
                ),
            ]),
          ],
        ],
      ],
    );
  }

  Widget _chip(AppColors ac, String label, bool active, VoidCallback onTap,
      {bool outline = false, String? icon, String? thumbUrl}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: widget.enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? ac.primary : (outline ? Colors.transparent : ac.surf2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? ac.primary : ac.bdr),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (thumbUrl != null && thumbUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(thumbUrl, width: 16, height: 16, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 16, height: 16)),
              ),
              const SizedBox(width: 5),
            ] else if (icon != null && icon.isNotEmpty) ...[
              Text(icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
            ],
            Text(label, style: AppText.caption.copyWith(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: active ? Colors.white : (outline ? ac.primary : ac.txt2))),
          ]),
        ),
      ),
    );
  }
}

/// A letter-avatar fallback for any curriculum node without a chosen
/// look — deterministic color from the label so the same subject
/// always gets the same tint, Wikipedia-card style rather than a bare
/// line of text. An uploaded photo (local file while composing, or a
/// network URL once saved) takes priority over the emoji, which in
/// turn takes priority over the letter.
class HierarchyAvatar extends StatelessWidget {
  final String label;
  final String? icon;
  final String? imageUrl;
  final File? localImage;
  final double size;

  /// When true, this fills whatever box its parent gives it (e.g. the
  /// full square of a grid tile) instead of rendering at a small fixed
  /// [size] — used for every full-width thumbnail slot from Subject
  /// level down (and now Level cards too), so a node without an
  /// uploaded photo yet still reads as "the whole card's visual", not a
  /// small icon floating in an otherwise-empty box. [size] is ignored
  /// when [fill] is true.
  final bool fill;

  const HierarchyAvatar({
    super.key, required this.label, this.icon, this.imageUrl, this.localImage, this.size = 44,
    this.fill = false,
  });

  static const _palette = [0xFF3B5BA9, 0xFF2E8B57, 0xFFB2531D, 0xFF7A4FB5, 0xFFB0446E, 0xFF1F8A8A];

  @override
  Widget build(BuildContext context) {
    final hasImage = localImage != null || (imageUrl != null && imageUrl!.isNotEmpty);
    final radius = BorderRadius.circular(fill ? 12 : size * 0.28);
    if (hasImage) {
      final image = localImage != null
          ? Image.file(localImage!, fit: BoxFit.cover,
              width: fill ? double.infinity : size, height: fill ? double.infinity : size)
          : Image.network(imageUrl!, fit: BoxFit.cover,
              width: fill ? double.infinity : size, height: fill ? double.infinity : size,
              errorBuilder: (_, __, ___) => _fallback(radius));
      return ClipRRect(borderRadius: radius, child: image);
    }
    return _fallback(radius);
  }

  Widget _fallback(BorderRadius radius) {
    final hasIcon = icon != null && icon!.isNotEmpty;
    final colorSeed = label.isEmpty ? 0 : label.codeUnitAt(0);
    final color = Color(_palette[colorSeed % _palette.length]);
    final letterOrIcon = hasIcon
        ? Text(icon!, style: TextStyle(fontSize: fill ? 34 : size * 0.5))
        : Text(label.isEmpty ? '?' : label[0].toUpperCase(),
            style: TextStyle(fontSize: fill ? 30 : size * 0.42, fontWeight: FontWeight.w800, color: Colors.white));
    return Container(
      width: fill ? double.infinity : size,
      height: fill ? double.infinity : size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hasIcon ? color.withValues(alpha: .12) : color,
        borderRadius: radius,
      ),
      child: letterOrIcon,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HIERARCHY VIEW TOGGLE — grid/list switch for the Courses browse screens
// ════════════════════════════════════════════════════════════════════════════

/// A two-way grid/list switch — the selection itself is owned by the
/// caller (backed by CoursesViewModeService so it persists and stays
/// consistent across pushed pages); this widget is purely the control.
class HierarchyViewToggle extends StatelessWidget {
  final bool isGrid;
  final ValueChanged<bool> onChanged;
  const HierarchyViewToggle({super.key, required this.isGrid, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: ac.surf2, borderRadius: BorderRadius.circular(10), border: Border.all(color: ac.bdr)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _segment(ac, icon: Icons.grid_view_rounded, active: isGrid, onTap: () => onChanged(true)),
        _segment(ac, icon: Icons.view_list_rounded, active: !isGrid, onTap: () => onChanged(false)),
      ]),
    );
  }

  Widget _segment(AppColors ac, {required IconData icon, required bool active, required VoidCallback onTap}) {
    return Material(
      color: active ? ac.surf : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: active ? ac.primary : ac.muted),
        ),
      ),
    );
  }
}

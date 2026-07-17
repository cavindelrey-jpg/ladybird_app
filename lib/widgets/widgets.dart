// lib/widgets/widgets.dart
// Academia shared widget library — Material 3, animated, accessible.

import 'dart:io';
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
            const StatusBadge(label: 'URGENT', color: C.red, bg: C.redb),
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

// ════════════════════════════════════════════════════════════════════════════
// COMPOSER SHELL (Magazine + Course creation pages share these)
// ════════════════════════════════════════════════════════════════════════════

/// Cover-image well with a clear empty-state prompt ("Add cover image /
/// Recommended 16:9") instead of a bare icon — used by every composer that
/// collects a hero image (article, course, and image-type Magazine posts).
class ComposerCoverPicker extends StatelessWidget {
  final File? pickedFile;
  final String? existingUrl;
  final VoidCallback onTap;
  final double height;
  final String label;
  const ComposerCoverPicker({
    super.key, required this.onTap,
    this.pickedFile, this.existingUrl,
    this.height = 160, this.label = 'Add cover image',
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = pickedFile != null || existingUrl != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Container(
          height: height, width: double.infinity,
          decoration: BoxDecoration(
            color: C.surf2,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: C.bdr, width: hasImage ? 0 : 1.4),
            image: pickedFile != null
                ? DecorationImage(image: FileImage(pickedFile!), fit: BoxFit.cover)
                : (existingUrl != null
                    ? DecorationImage(image: NetworkImage(existingUrl!), fit: BoxFit.cover)
                    : null),
          ),
          child: hasImage
              ? Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .45), shape: BoxShape.circle),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                  ),
                )
              : Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_photo_alternate_outlined, color: C.muted, size: 28),
                    const SizedBox(height: 8),
                    Text(label, style: AppText.title.copyWith(color: C.txt2, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Recommended 16:9', style: AppText.caption),
                  ]),
                ),
        ),
      ),
    );
  }
}

/// Bordered, boxed text field with a placeholder and optional character
/// counter — the "Add a compelling title…" style input used across
/// composer pages instead of a bare underline-less TextField.
class ComposerField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextStyle? style;
  final int maxLines;
  final int? maxLength;
  const ComposerField({
    super.key, required this.controller, required this.hint,
    this.style, this.maxLines = 1, this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: C.bdr)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        style: style ?? AppText.body,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: (style ?? AppText.body).copyWith(color: C.muted, fontWeight: FontWeight.w400),
          border: InputBorder.none,
          counterStyle: AppText.caption,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

/// Single-select category chip row that gracefully overflows: shows the
/// first [visibleCount] options plus a "More ▾" chip opening a bottom
/// sheet with the rest, instead of every category wrapping onto the
/// screen at once. The active category is always kept visible even if
/// it isn't among the first [visibleCount].
class CategoryChipSelector extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  final int visibleCount;
  const CategoryChipSelector({
    super.key, required this.options, required this.selected,
    required this.onChanged, this.visibleCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    final visible = options.take(visibleCount).toList();
    if (!visible.contains(selected) && options.contains(selected) && visible.isNotEmpty) {
      visible[visible.length - 1] = selected;
    }
    final hasMore = options.length > visibleCount;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      ...visible.map((cat) => _chip(cat, cat == selected)),
      if (hasMore) _moreChip(context),
    ]);
  }

  Widget _chip(String label, bool active) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () { HapticFeedback.selectionClick(); onChanged(label); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? C.primary : C.surf2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? C.primary : C.bdr),
          ),
          child: Text(label, style: AppText.caption.copyWith(
              fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : C.txt2)),
        ),
      ),
    );
  }

  Widget _moreChip(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openMoreSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
              color: C.surf2, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.bdr)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('More', style: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: C.txt2)),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: C.txt2),
          ]),
        ),
      ),
    );
  }

  void _openMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surf,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.lg))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Category', style: AppText.h2),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: options.map((cat) {
              final active = cat == selected;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () { HapticFeedback.selectionClick(); onChanged(cat); Navigator.pop(context); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? C.primary : C.surf2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? C.primary : C.bdr),
                    ),
                    child: Text(cat, style: AppText.caption.copyWith(
                        fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : C.txt2)),
                  ),
                ),
              );
            }).toList()),
          ]),
        ),
      ),
    );
  }
}

/// One tile in the "Create New" content-type picker (Text/Image/Video/
/// Audio) shown before a Magazine composer opens for a brand-new post.
class ContentTypeTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const ContentTypeTile({
    super.key, required this.icon, required this.color, required this.title,
    required this.subtitle, required this.onTap, this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Rad.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rad.md),
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: .08) : C.surf,
            borderRadius: BorderRadius.circular(Rad.md),
            border: Border.all(color: selected ? color : C.bdr, width: selected ? 1.6 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(Rad.sm)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(title, style: AppText.title),
            const SizedBox(height: 2),
            Text(subtitle, style: AppText.caption),
          ]),
        ),
      ),
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
                  color: active ? C.goldp : C.surf2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? C.gold : C.bdr),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (active) ...[
                    const Icon(Icons.check_rounded, size: 13, color: C.gold),
                    const SizedBox(width: 3),
                  ],
                  Text(tag, style: AppText.caption.copyWith(
                      fontSize: 11.5, fontWeight: FontWeight.w700,
                      color: active ? C.gold : C.txt2)),
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
                color: C.surf2, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: C.bdr, style: BorderStyle.solid),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, size: 14, color: C.txt2),
                const SizedBox(width: 2),
                Text('Add tag', style: AppText.caption.copyWith(fontSize: 11.5, color: C.txt2)),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

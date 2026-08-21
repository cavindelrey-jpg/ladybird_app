// lib/widgets/chat_media_widgets.dart
//
// Small, Messages-feature-scoped visual primitives. Split out from the
// shared lib/widgets/widgets.dart on purpose: widgets.dart is imported
// by ~40 other files across the app, and these additions
// (NetworkThumb / FullscreenImageViewer / PresenceDot / QuickAttachTile)
// are only meaningful for chat — no reason to grow that shared file's
// surface area or its blast radius. See UserAvatar_patch.md for the one
// change that DOES need to land in the shared file (the avatar
// fallback), kept as a minimal, explicit patch for the same reason.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';

/// Drop-in replacement for a bare `Image.network(url, fit: ...)`
/// anywhere a thumbnail needs to be GUARANTEED visible: chat image
/// bubbles, link previews, shared-content cards. Shows a shimmer while
/// loading and a clear "image unavailable" tile if the load fails —
/// never a blank box, never Flutter's default red-and-yellow error
/// rectangle. This is the concrete fix for "images and thumbnails
/// should be visible for all": every network image in the chat surfaces
/// now goes through here instead of a bare Image.network.
class NetworkThumb extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const NetworkThumb({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final radius = borderRadius ?? BorderRadius.circular(10);
    final iconSize = ((height ?? width ?? 80) * 0.28).clamp(16.0, 36.0);

    Widget image = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: ac.surf3,
          alignment: Alignment.center,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ac.muted,
              value: progress.expectedTotalBytes != null && progress.expectedTotalBytes! > 0
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stack) => Container(
        width: width,
        height: height,
        color: ac.surf3,
        alignment: Alignment.center,
        child: Icon(Icons.image_not_supported_rounded, color: ac.muted, size: iconSize),
      ),
    );

    image = ClipRRect(borderRadius: radius, child: image);

    if (onTap == null) return image;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: image),
    );
  }
}

/// Full-screen, pinch-to-zoom viewer for a tapped chat image — pushed on
/// top of the chat rather than opening the browser, so photos actually
/// feel like part of the conversation.
class FullscreenImageViewer extends StatelessWidget {
  final String url;
  const FullscreenImageViewer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.image_not_supported_rounded, color: Colors.white54, size: 48),
                SizedBox(height: 12),
                Text('This image is unavailable.', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small presence indicator — a filled dot with a border matching the
/// surface it sits on, WhatsApp/iMessage-style. Purely a rendering
/// primitive; callers decide what "online" means (see
/// Conversation.isRecentlyActive for the real, non-fake signal this
/// project uses it with).
class PresenceDot extends StatelessWidget {
  final bool online;
  final double size;
  final Color borderColor;
  const PresenceDot({super.key, required this.online, this.size = 12, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: online ? ac.grn : ac.muted.withValues(alpha: .55),
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: size * 0.16),
      ),
    );
  }
}

/// One tile in the chat's quick-attach row (Note / Course / Quiz /
/// Article / Past Paper) — matches the mockup's horizontal icon row
/// sitting directly above the input bar, always visible rather than
/// buried in a bottom sheet.
class QuickAttachTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const QuickAttachTile({
    super.key, required this.icon, required this.label,
    required this.color, required this.bg, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

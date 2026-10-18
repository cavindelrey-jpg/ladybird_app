import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// A robust, scalable, non-overflowing circular progress ring for desktop
/// and mobile contextual sidebars.
///
/// Features:
/// - Fitted layout with internal padding to prevent any text clipping.
/// - Rounded stroke cap.
/// - Auto-formatting percentage or custom center & subtitle labels.
class AcademicProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Color? progressColor;
  final Color? backgroundColor;
  final String? centerText;
  final String? subtitle;

  const AcademicProgressRing({
    super.key,
    required this.progress,
    this.size = 80,
    this.strokeWidth = 7,
    this.progressColor,
    this.backgroundColor,
    this.centerText,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final clamped = progress.clamp(0.0, 1.0);
    final percentVal = (clamped * 100).round();
    final fgColor = progressColor ?? const Color(0xFFE5A93C);
    final bgColor = backgroundColor ?? ac.bdr2;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Track & Foreground Arc
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: clamped,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: bgColor,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          // Inner Centered Text (Auto-scaling with FittedBox)
          Padding(
            padding: EdgeInsets.all(strokeWidth + 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    centerText ?? '$percentVal%',
                    style: GoogleFonts.inter(
                      fontSize: size * 0.24,
                      fontWeight: FontWeight.w800,
                      color: ac.txt,
                      height: 1.1,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      style: GoogleFonts.inter(
                        fontSize: size * 0.12,
                        fontWeight: FontWeight.w500,
                        color: ac.txt2,
                        height: 1.1,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

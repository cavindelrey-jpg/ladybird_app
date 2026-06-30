// lib/features/institution/institution_splash_screen.dart
// Branded splash shown after institution loads, before login.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/institution.dart';

class InstitutionSplashScreen extends StatefulWidget {
  final Institution institution;
  final VoidCallback onContinue;
  const InstitutionSplashScreen({super.key, required this.institution, required this.onContinue});

  @override
  State<InstitutionSplashScreen> createState() => _InstitutionSplashScreenState();
}

class _InstitutionSplashScreenState extends State<InstitutionSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) widget.onContinue();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final inst = widget.institution;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [inst.primary, inst.secondary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Logo
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 10))],
                    ),
                    child: inst.logoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.network(inst.logoUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _LogoFallback(inst: inst)))
                      : _LogoFallback(inst: inst),
                  ),
                  const SizedBox(height: 24),
                  Text(inst.schoolName,
                    textAlign: TextAlign.center,
                    style: _font(inst.fontFamily, fontSize: 28, weight: FontWeight.w800, color: Colors.white)),
                  if (inst.tagline != null) ...[
                    const SizedBox(height: 8),
                    Text(inst.tagline!,
                      textAlign: TextAlign.center,
                      style: _font(inst.fontFamily, fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
                  ],
                  const SizedBox(height: 48),
                  const SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                  const SizedBox(height: 20),
                  Text(inst.poweredByLabel,
                    style: _font(inst.fontFamily, fontSize: 11, color: Colors.white54)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static TextStyle _font(String family, {double fontSize = 14, FontWeight weight = FontWeight.w400, Color color = Colors.white}) {
    try { return GoogleFonts.getFont(family, fontSize: fontSize, fontWeight: weight, color: color); }
    catch (_) { return GoogleFonts.inter(fontSize: fontSize, fontWeight: weight, color: color); }
  }
}

class _LogoFallback extends StatelessWidget {
  final Institution inst;
  const _LogoFallback({required this.inst});
  @override
  Widget build(BuildContext context) => Center(
    child: Text(inst.schoolName.isNotEmpty ? inst.schoolName[0].toUpperCase() : 'A',
      style: GoogleFonts.sora(fontSize: 40, fontWeight: FontWeight.w800, color: inst.primary)),
  );
}

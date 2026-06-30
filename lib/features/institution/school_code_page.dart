// lib/features/institution/school_code_page.dart
// Animated onboarding entry page — enter school code to join an institution.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/institution_provider.dart';
import '../../theme/app_theme.dart';

class SchoolCodePage extends StatefulWidget {
  const SchoolCodePage({super.key});
  @override State<SchoolCodePage> createState() => _SchoolCodePageState();
}

class _SchoolCodePageState extends State<SchoolCodePage>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() { _animCtrl.dispose(); _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    await context.read<InstitutionProvider>().loadByCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<InstitutionProvider>();
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Icon mark
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [C.navy, C.navy2],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(Rad.xl),
                      boxShadow: Shad.md,
                    ),
                    child: const Icon(Icons.school_rounded, size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 28),

                  Text('Welcome to Academia',
                      style: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w800,
                          color: C.txt)),
                  const SizedBox(height: 8),
                  Text('Enter your school code to continue',
                      style: GoogleFonts.inter(fontSize: 14, color: C.txt2)),
                  const SizedBox(height: 40),

                  // Code input
                  TextField(
                    controller: _ctrl,
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700,
                        letterSpacing: 4, color: C.txt),
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'SCHOOL CODE',
                      hintStyle: GoogleFonts.sora(fontSize: 16, letterSpacing: 3,
                          color: C.muted, fontWeight: FontWeight.w600),
                      prefixIcon: const Icon(Icons.vpn_key_outlined, color: C.muted),
                      filled: true, fillColor: C.surf,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Rad.md),
                          borderSide: const BorderSide(color: C.bdr)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Rad.md),
                          borderSide: const BorderSide(color: C.bdr)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Rad.md),
                          borderSide: const BorderSide(color: C.primary, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),

                  // Error
                  if (prov.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: C.redb,
                          borderRadius: BorderRadius.circular(Rad.sm),
                          border: Border.all(color: C.red.withValues(alpha: .3))),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: C.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(prov.errorMessage!,
                            style: GoogleFonts.inter(color: C.red, fontSize: 13))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Enter button
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: prov.isValidating ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.navy, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Rad.md)),
                        elevation: 0,
                      ),
                      child: prov.isValidating
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text('Enter School', style: GoogleFonts.sora(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Help text
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: C.goldp,
                      borderRadius: BorderRadius.circular(Rad.sm),
                      border: Border.all(color: C.gold.withValues(alpha: .3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, color: C.gold, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        "Don't have a code? Contact your institution's administrator.",
                        style: GoogleFonts.inter(fontSize: 12, color: C.navy3))),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

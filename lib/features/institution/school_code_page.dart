// lib/features/institution/school_code_page.dart
// Onboarding entry: student types their personal serial number, not a
// shared school code. A serial number is {schoolCode}-{seatId}
// (e.g. "SM1234-0007") — the schoolCode half identifies the institution,
// the seatId half identifies one specific pre-paid seat.
//
// Flow:
//   1. Parse + validate the serial's shape.
//   2. Resolve the institution by schoolCode (branding).
//   3. Resolve the seat by seatId, scoped to that institution, and check
//      it's actually claimable (not suspended / not already activated /
//      not still awaiting payment confirmation from the school).
//   4. Only once both checks pass: activate the institution in
//      InstitutionProvider — this is the moment the app visibly re-brands
//      (logo, name, colors) — then hand off to ClaimSeatScreen so the
//      student personalizes their own seat into a real account.
//
// A code with no matching seat, or a seat that's unassigned/suspended/
// already claimed, never gets this far — closing the "anybody with the
// code can get in" gap.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/institution_provider.dart';
import '../../repositories/accounts_repository.dart';
import '../../core/result.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

import '../../widgets/app_background.dart';
import '../onboarding/claim_seat_screen.dart';

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

  bool _loading = false;
  String? _error;

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

  /// Splits "SM1234-0007" into ("SM1234", "0007"). Returns null if the
  /// shape is wrong (no dash, or either half empty) — a clearer, earlier
  /// error than letting it fail two network calls later.
  (String, String)? _parse(String raw) {
    final serial = raw.trim().toUpperCase();
    final dash = serial.lastIndexOf('-');
    if (dash <= 0 || dash == serial.length - 1) return null;
    final schoolCode = serial.substring(0, dash);
    final seatId = serial.substring(dash + 1);
    if (schoolCode.isEmpty || seatId.isEmpty) return null;
    return (schoolCode, seatId);
  }

  Future<void> _submit() async {
    final parsed = _parse(_ctrl.text);
    if (parsed == null) {
      setState(() => _error =
          'Serial numbers look like SCHOOLCODE-0007. Check the format your school gave you.');
      return;
    }
    final (schoolCode, seatId) = parsed;

    setState(() { _loading = true; _error = null; });

    final instProv = context.read<InstitutionProvider>();
    final instOk = await instProv.loadByCode(schoolCode);
    if (!instOk) {
      if (!mounted) return;
      setState(() { _loading = false; _error = instProv.errorMessage; });
      return;
    }

    final seatResult = await AccountsRepository.instance
        .resolveSeat(schoolId: schoolCode, seatId: seatId);
    if (!mounted) return;

    if (seatResult is! Success<StudentAccount>) {
      setState(() { _loading = false; _error = (seatResult as Failure).message; });
      // Don't leave the app half-branded to an institution the student
      // couldn't actually get into.
      await instProv.clear();
      return;
    }

    // Institution branding is now active — the app has visibly morphed.
    // Hand off to seat personalization.
    final seat = seatResult.value;
    setState(() => _loading = false);
    if (!mounted) return;
    final entered = Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ClaimSeatScreen(schoolCode: schoolCode, seat: seat),
    ));
    await entered;
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: AppBackground(child: SafeArea(
        child: Stack(children: [
          FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [C.navy, C.navy2],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(Rad.xl),
                      boxShadow: Shad.md,
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 28),

                  Text('Enter your serial number',
                      style: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w800,
                          color: C.txt)),
                  const SizedBox(height: 8),
                  Text('Given to you by your school after fees are confirmed',
                      style: GoogleFonts.inter(fontSize: 14, color: C.txt2),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 40),

                  TextField(
                    controller: _ctrl,
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700,
                        letterSpacing: 2, color: C.txt),
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'SCHOOLCODE-0007',
                      hintStyle: GoogleFonts.sora(fontSize: 15, letterSpacing: 1.5,
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

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: C.redb,
                          borderRadius: BorderRadius.circular(Rad.sm),
                          border: Border.all(color: C.red.withValues(alpha: .3))),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: C.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!,
                            style: GoogleFonts.inter(color: C.red, fontSize: 13))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.navy, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Rad.md)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text('Continue', style: GoogleFonts.sora(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 28),

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
                        "Don't have one? Contact your institution's administrator — it's issued once your fees are confirmed.",
                        style: GoogleFonts.inter(fontSize: 12, color: C.navy3))),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          ),
          if (Navigator.of(context).canPop())
            Positioned(
              top: 4, left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: C.txt2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
        ]),
      )),
    );
  }
}

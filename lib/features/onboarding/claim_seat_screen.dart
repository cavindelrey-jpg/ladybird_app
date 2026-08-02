// lib/features/onboarding/claim_seat_screen.dart
// Second half of serial-number onboarding: turns a pre-paid, pre-provisioned
// seat into a real, sign-in-able account. Reached only after
// SchoolCodePage has already verified the seat is claimable and activated
// the institution's branding — so this screen renders inside the school's
// own colors/logo already, via the Theme this route inherits.
//
// The student still has to prove they're the person the school actually
// assigned this seat to, by entering the temp password the school gave
// them alongside the serial number. AuthService.claimLinkedSeat re-checks
// that server-side and burns it one-way on success.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class ClaimSeatScreen extends StatefulWidget {
  final String schoolCode;
  final StudentAccount seat;
  const ClaimSeatScreen({super.key, required this.schoolCode, required this.seat});

  @override
  State<ClaimSeatScreen> createState() => _ClaimSeatScreenState();
}

class _ClaimSeatScreenState extends State<ClaimSeatScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.seat.studentName ?? '');
  final _emailCtrl = TextEditingController();
  final _tempPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _tempPwdCtrl.dispose(); _newPwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.instance.claimLinkedSeat(
        schoolCode: widget.schoolCode,
        seatId: widget.seat.accountId,
        tempPassword: _tempPwdCtrl.text.trim(),
        newEmail: _emailCtrl.text.trim(),
        newPassword: _newPwdCtrl.text,
        studentName: _nameCtrl.text.trim(),
      );
      if (!mounted) return;
      // AppRouter's _AuthGate picks up the new Firebase session and swaps
      // in automatically — just pop back to reveal it.
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, elevation: 0, iconTheme: const IconThemeData(color: C.txt)),
      body: AppBackground(child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: C.grnb, borderRadius: BorderRadius.circular(20)),
                child: Text('SEAT ${widget.schoolCode}-${widget.seat.accountId}',
                    style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w800,
                        letterSpacing: .6, color: C.grn)),
              ),
              const SizedBox(height: 16),
              Text('Make this account yours',
                  style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w800, color: C.txt)),
              const SizedBox(height: 6),
              Text(
                'Enter the temporary password your school gave you, then set '
                'your own email and password. Once you do, only you will be '
                'able to sign in with this seat.',
                style: GoogleFonts.inter(fontSize: 13, color: C.txt2),
              ),
              const SizedBox(height: 28),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: C.redb, borderRadius: BorderRadius.circular(Rad.sm),
                      border: Border.all(color: C.red.withValues(alpha: .3))),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: C.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: GoogleFonts.inter(color: C.red, fontSize: 13))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              _Field(
                controller: _tempPwdCtrl,
                hint: 'Temporary password from your school',
                icon: Icons.vpn_key_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _nameCtrl,
                hint: 'Full name',
                icon: Icons.person_outline_rounded,
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _emailCtrl,
                hint: 'Your personal email address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _newPwdCtrl,
                hint: 'Choose a new password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                onSubmitted: (_) => _submit(),
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                suffix: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: C.muted, size: 18),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 28),

              PrimaryBtn(label: 'Activate My Account', onTap: _submit, loading: _loading),
              const SizedBox(height: 16),
              Center(
                child: Text('This serial number can only be activated once.',
                    style: GoogleFonts.inter(fontSize: 11, color: C.muted)),
              ),
            ]),
          ),
        ),
      )),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  const _Field({
    required this.controller, required this.hint, required this.icon,
    this.obscureText = false, this.keyboardType, this.suffix,
    this.validator, this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 14, color: C.txt),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: C.muted),
        prefixIcon: Icon(icon, color: C.muted, size: 20),
        suffixIcon: suffix,
        filled: true, fillColor: C.surf,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
            borderSide: const BorderSide(color: C.bdr)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
            borderSide: const BorderSide(color: C.bdr)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
            borderSide: const BorderSide(color: C.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
            borderSide: const BorderSide(color: C.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
            borderSide: const BorderSide(color: C.red, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

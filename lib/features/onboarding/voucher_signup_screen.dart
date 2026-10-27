// lib/features/onboarding/voucher_signup_screen.dart
// The account-creation screen reached from VoucherEntryScreen after a
// voucher code has been validated. Supports automatic class-list placement
// using separate account usernames and official student names.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../core/result.dart';
import '../../models/academic_content.dart' show kAcademicLevels;
import '../../repositories/academia_voucher_repository.dart';
import '../../repositories/school_access_repository.dart';
import '../../repositories/student_roster_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class VoucherSignUpScreen extends StatefulWidget {
  /// Already normalized/format-validated by VoucherEntryScreen.
  final String voucherCode;
  const VoucherSignUpScreen({super.key, required this.voucherCode});

  @override
  State<VoucherSignUpScreen> createState() => _VoucherSignUpScreenState();
}

class _VoucherSignUpScreenState extends State<VoucherSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _officialNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  late String _selectedClass = kAcademicLevels.first;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  bool get _isAcademiaCode => widget.voucherCode.startsWith('AC-');
  bool get _isStudentCode {
    if (_isAcademiaCode) return false;
    final parts = widget.voucherCode.split('-');
    return parts.length >= 2 && (parts[1] == 'S' || parts[1] == 'STUDENT');
  }

  @override
  void dispose() {
    _officialNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final username = _isStudentCode ? _usernameCtrl.text.trim() : _officialNameCtrl.text.trim();
      final officialName = _officialNameCtrl.text.trim();

      final user = await AuthService.instance.signUpIndependent(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        name: username,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext();

      final redeemResult = _isAcademiaCode
          ? await AcademiaVoucherRepository.instance
              .redeemVoucher(userId: user.id, rawCode: widget.voucherCode)
          : await SchoolAccessRepository.instance.redeemSchoolVoucher(
              userId: user.id,
              rawCode: widget.voucherCode,
              classLevel: _isStudentCode ? _selectedClass : null,
            );

      if (!mounted) return;
      switch (redeemResult) {
        case Success(:final value):
          showToast(context, 'Account activated');
          // Automatic class-list placement for enrolled school students
          if (_isStudentCode && value is SchoolRedemptionOutcome) {
            final schoolId = value.school.id;
            try {
              await StudentRosterRepository.instance.ensureStudentOnClassList(
                schoolId: schoolId,
                classLevel: _selectedClass,
                officialName: officialName,
                username: username,
                userId: user.id,
              );
            } catch (_) {}
          }
        case Failure(:final message):
          showToast(context, 'Account created, but the code failed: $message', isError: true);
      }
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      TextInput.finishAutofillContext(shouldSave: false);
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
      ),
      body: AppBackground(child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: ac.goldBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(widget.voucherCode,
                      style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w800,
                          letterSpacing: .6, color: ac.navy)),
                ),
                const SizedBox(height: 16),
                Text('Create your account',
                    style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w800, color: ac.txt)),
                const SizedBox(height: 6),
                Text(
                  _isStudentCode
                      ? 'Enter your official student name for class lists, and choose an account username for app login.'
                      : 'Your code already grants your role and Premium tier — just fill in your details to finish.',
                  style: GoogleFonts.inter(fontSize: 13, color: ac.txt2),
                ),
                const SizedBox(height: 24),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: ac.redBg, borderRadius: BorderRadius.circular(Rad.sm),
                        border: Border.all(color: ac.red.withValues(alpha: .3))),
                    child: Row(children: [
                      Icon(Icons.error_outline, color: ac.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!,
                          style: GoogleFonts.inter(color: ac.red, fontSize: 13))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],

                // 1. Official Student Name
                _VoucherField(
                  controller: _officialNameCtrl,
                  hint: _isStudentCode ? 'Official Full Name (e.g. Brice Ngono)' : 'Full Name',
                  icon: Icons.badge_outlined,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your official name' : null,
                ),
                const SizedBox(height: 12),

                // 2. Separate Account Username (for students)
                if (_isStudentCode) ...[
                  _VoucherField(
                    controller: _usernameCtrl,
                    hint: 'Account Username (e.g. brice2026)',
                    icon: Icons.alternate_email_rounded,
                    autofillHints: const [AutofillHints.username],
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Enter an account username' : null,
                  ),
                  const SizedBox(height: 12),

                  // 3. Class Level Placement
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: ac.surf,
                      borderRadius: BorderRadius.circular(Rad.md),
                      border: Border.all(color: ac.bdr),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedClass,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down_rounded, color: ac.txt2),
                        dropdownColor: ac.surf,
                        items: kAcademicLevels.take(7).map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: GoogleFonts.inter(fontSize: 14, color: ac.txt)),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedClass = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 4. Email address
                _VoucherField(
                  controller: _emailCtrl,
                  hint: 'Email address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.newUsername, AutofillHints.email],
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 12),

                // 5. Password
                _VoucherField(
                  controller: _passwordCtrl,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _submit(),
                  validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: ac.muted, size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: 28),

                PrimaryBtn(label: 'Activate Account', onTap: _submit, loading: _loading),
              ]),
            ),
          ),
        ),
      )),
    );
  }
}

class _VoucherField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  const _VoucherField({
    required this.controller, required this.hint, required this.icon,
    this.obscureText = false, this.keyboardType, this.suffix,
    this.validator, this.onSubmitted, this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      autofillHints: autofillHints,
      keyboardType: keyboardType,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 14, color: ac.txt),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: ac.muted),
        prefixIcon: Icon(icon, color: ac.muted, size: 20),
        suffixIcon: suffix,
        filled: true, fillColor: ac.surf,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md), borderSide: BorderSide(color: ac.bdr)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md), borderSide: BorderSide(color: ac.bdr)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md), borderSide: BorderSide(color: ac.primary, width: 2)),
      ),
    );
  }
}

// lib/features/onboarding/create_account_screen.dart
// Signup form shared by the Normal and Premium independent account paths.
// On success:
//   - Normal:  account created, straight into the app.
//   - Premium: account created, then the MoMo/Orange Money unlock sheet
//              is shown immediately.
// Either way, once Firebase Auth reports the new session, AppRouter (which
// sits underneath this pushed route) swaps to HomeShell — so on success we
// pop back to the root to reveal it.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../widgets/premium_unlock_sheet.dart';
import '../../widgets/google_sign_in_button.dart';

class CreateAccountScreen extends StatefulWidget {
  final bool isPremium;
  const CreateAccountScreen({super.key, required this.isPremium});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.instance.signUpIndependent(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        name: _nameCtrl.text.trim(),
      );
      if (!mounted) return;

      if (widget.isPremium) {
        final uid = AuthService.instance.firebaseUser?.uid ?? '';
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: C.surf,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl))),
          builder: (_) => PremiumUnlockSheet(userId: uid, onUnlockSuccess: () {}),
        );
      }

      if (!mounted) return;
      // Reveal root AppRouter, which has already swapped to HomeShell now
      // that Firebase Auth reports a signed-in independent user.
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _afterGoogleSignIn(AppUser user) async {
    if (widget.isPremium) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: C.surf,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl))),
        builder: (_) => PremiumUnlockSheet(userId: user.id, onUnlockSuccess: () {}),
      );
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: C.txt),
      ),
      body: AppBackground(child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: widget.isPremium ? C.goldp : C.grnb,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.isPremium ? 'PREMIUM INDIVIDUAL' : 'NORMAL ACCOUNT',
                  style: GoogleFonts.sora(
                      fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6,
                      color: widget.isPremium ? C.navy : C.grn),
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.isPremium ? 'Go Premium' : 'Create your account',
                  style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w800, color: C.txt)),
              const SizedBox(height: 6),
              Text(
                widget.isPremium
                    ? "Create your identity first — you'll pay via MoMo or "
                      'Orange Money on the next step.'
                    : 'Just a name, email, and password. No payment needed.',
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

              GoogleSignInButton(
                onSignedIn: _afterGoogleSignIn,
                onError: (msg) => setState(() => _error = msg),
              ),
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(child: Divider(color: C.bdr)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('or', style: GoogleFonts.inter(fontSize: 12, color: C.muted)),
                ),
                const Expanded(child: Divider(color: C.bdr)),
              ]),
              const SizedBox(height: 18),

              _Field(
                controller: _nameCtrl,
                hint: 'Full name',
                icon: Icons.person_outline_rounded,
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _emailCtrl,
                hint: 'Email address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _passwordCtrl,
                hint: 'Password',
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

              PrimaryBtn(
                label: widget.isPremium ? 'Continue to Payment' : 'Create Free Account',
                onTap: _submit,
                loading: _loading,
              ),
              const SizedBox(height: 16),
              Center(
                child: Text('By continuing you agree to Academia\'s guidelines.',
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

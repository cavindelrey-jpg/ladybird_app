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
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../models/app_user.dart';
import '../../models/entitlement.dart';
import '../../services/auth_service.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../widgets/premium_unlock_sheet.dart';
import '../../widgets/google_sign_in_button.dart';

class CreateAccountScreen extends StatefulWidget {
  /// EntitlementTier.free = Individual (no payment step). Silver/Gold both
  /// go straight to the direct-payment sheet after signup, preselected to
  /// this tier (the user can still switch there).
  final EntitlementTier tier;
  const CreateAccountScreen({super.key, required this.tier});

  bool get isPremium => tier != EntitlementTier.free;

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
      // Commits the autofill session so the platform password manager
      // offers to save the newly-created credentials.
      TextInput.finishAutofillContext();

      if (widget.isPremium) {
        final uid = AuthService.instance.firebaseUser?.id ?? '';
        final ac = AppColors.of(context);
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: ac.surf,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl))),
          builder: (_) => PremiumUnlockSheet(
              userId: uid, initialTier: widget.tier, onUnlockSuccess: () {}),
        );
      }

      if (!mounted) return;
      // Reveal root AppRouter, which has already swapped to HomeShell now
      // that Firebase Auth reports a signed-in independent user.
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

  Future<void> _afterGoogleSignIn(AppUser user) async {
    if (widget.isPremium) {
      final ac = AppColors.of(context);
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: ac.surf,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.xl))),
        builder: (_) => PremiumUnlockSheet(
            userId: user.id, initialTier: widget.tier, onUnlockSuccess: () {}),
      );
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
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
                decoration: BoxDecoration(
                  color: widget.isPremium ? ac.goldBg : ac.grnBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.tier == EntitlementTier.gold
                      ? 'PREMIUM GOLD'
                      : widget.tier == EntitlementTier.silver
                          ? 'PREMIUM SILVER'
                          : 'INDIVIDUAL',
                  style: GoogleFonts.sora(
                      fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6,
                      color: widget.isPremium ? ac.navy : ac.grn),
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.isPremium ? 'Go Premium' : 'Create your account',
                  style: GoogleFonts.sora(fontSize: 24, fontWeight: FontWeight.w800, color: ac.txt)),
              const SizedBox(height: 6),
              Text(
                widget.isPremium
                    ? "Create your identity first — you'll pay via MoMo or "
                      'Orange Money on the next step.'
                    : 'Just a name, email, and password. No payment needed.',
                style: GoogleFonts.inter(fontSize: 13, color: ac.txt2),
              ),
              const SizedBox(height: 28),

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

              GoogleSignInButton(
                onSignedIn: _afterGoogleSignIn,
                onError: (msg) => setState(() => _error = msg),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: Divider(color: ac.bdr)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('or', style: GoogleFonts.inter(fontSize: 12, color: ac.muted)),
                ),
                Expanded(child: Divider(color: ac.bdr)),
              ]),
              const SizedBox(height: 18),

              _Field(
                controller: _nameCtrl,
                hint: 'Full name',
                icon: Icons.person_outline_rounded,
                autofillHints: const [AutofillHints.name],
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _emailCtrl,
                hint: 'Email address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                // "new" hints (not plain username/password) -- this is
                // an account-creation form, so the password manager
                // should offer to GENERATE a strong password, not just
                // recall an existing one.
                autofillHints: const [AutofillHints.newUsername, AutofillHints.email],
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 12),
              _Field(
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

              PrimaryBtn(
                label: widget.isPremium ? 'Continue to Payment' : 'Create Free Account',
                onTap: _submit,
                loading: _loading,
              ),
              const SizedBox(height: 16),
              Center(
                child: Text('By continuing you agree to our guidelines.',
                    style: GoogleFonts.inter(fontSize: 11, color: ac.muted)),
              ),
              ]),
            ),
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
  final Iterable<String>? autofillHints;
  const _Field({
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
            borderSide: BorderSide(color: ac.bdr)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
            borderSide: BorderSide(color: ac.bdr)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
            borderSide: BorderSide(color: ac.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
            borderSide: BorderSide(color: ac.red)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
            borderSide: BorderSide(color: ac.red, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

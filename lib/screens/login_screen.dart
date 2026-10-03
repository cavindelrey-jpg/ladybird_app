// lib/screens/login_screen.dart
// Modernized login — immersive navy gradient, animated entry, email+password.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../config/branding.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose(); _emailCtrl.dispose(); _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = await AuthService.instance.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      if (user == null) {
        // Wrong credentials -- close the autofill session without
        // prompting a save (shouldSave: false is the default, stated
        // explicitly here since saving a rejected password would be
        // actively wrong, not just unhelpful).
        TextInput.finishAutofillContext(shouldSave: false);
        setState(() { _error = 'Account not found. Check your credentials.'; _loading = false; });
        return;
      }
      // Commits the autofill session -- this is what actually triggers
      // Android/iOS/browser's "Save password?" prompt after a
      // successful sign-in. autofillHints on the fields alone only
      // covers the READ side (offering saved credentials); this is the
      // WRITE side.
      TextInput.finishAutofillContext();
      // AppRouter's root StreamBuilder swaps the underlying screen on auth
      // change, but when LoginScreen was reached via Navigator.push (e.g.
      // the drawer's "Sign In" entry for guests) that pushed route stays on
      // top and never dismisses itself — pop it so the updated screen
      // underneath becomes visible instead of leaving the spinner stuck.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      try { TextInput.finishAutofillContext(shouldSave: false); } catch (_) {}
      
      String errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (errorMsg.contains('Invalid login credentials') || errorMsg.contains('invalid_grant')) {
        errorMsg = 'Hmm, that email and password combination didn\'t work. Have you forgotten your password? Try tapping "Forgot Password?" below.';
      } else if (errorMsg.contains('SocketException') || errorMsg.contains('ClientException')) {
        errorMsg = 'We couldn\'t connect to the internet. Please check your connection and try again.';
      } else {
        errorMsg = 'Something didn\'t quite work. Please try again in a moment.';
      }
      
      setState(() {
        _error = errorMsg;
        _loading = false;
      });
    }
  }

  Future<void> _showForgotPasswordSheet(BuildContext context) async {
    final ac = AppColors.of(context);
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    bool sending = false;
    String? localError;
    bool sent = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ac.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(builder: (dCtx, setM) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(dCtx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text('Reset your password', style: AppText.h2.copyWith(fontSize: 17)),
          const SizedBox(height: 8),
          Text(
            sent
                ? 'If an account exists for that email, a reset link is on its way. Check your inbox (and spam folder).'
                : "Enter the email on your account. We'll send you a link to reset your password.",
            style: AppText.bodySm,
          ),
          const SizedBox(height: 16),
          if (!sent) ...[
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: AppText.body.copyWith(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Email address',
                filled: true,
                fillColor: ac.surf,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
                    borderSide: BorderSide(color: ac.bdr)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
                    borderSide: BorderSide(color: ac.bdr)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
                    borderSide: BorderSide(color: ac.primary)),
              ),
            ),
            if (localError != null) ...[
              const SizedBox(height: 10),
              Text(localError!, style: AppText.bodySm.copyWith(fontSize: 12, color: ac.red)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: sending
                    ? null
                    : () async {
                        final email = emailCtrl.text.trim();
                        if (!email.contains('@')) {
                          setM(() => localError = 'Enter a valid email address.');
                          return;
                        }
                        setM(() { sending = true; localError = null; });
                        try {
                          await AuthService.instance.sendPasswordResetEmail(email);
                          setM(() { sending = false; sent = true; });
                        } catch (e) {
                          setM(() {
                            sending = false;
                            localError = 'Could not send reset email. Check the address and try again.';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ac.gold, foregroundColor: ac.navy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
                  elevation: 0,
                  overlayColor: Colors.black.withValues(alpha: .08),
                ),
                child: sending
                    ? SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: ac.navy))
                    : Text('Send reset link', style: AppText.button.copyWith(
                        fontSize: 14, color: ac.navy)),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity, height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(dCtx).pop(),
                child: Text('Done', style: AppText.subtitle.copyWith(
                    fontSize: 14, fontWeight: FontWeight.w700, color: ac.primary)),
              ),
            ),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      body: Container(
        // Fill the screen: the gradient used to stop under the form,
        // leaving the lower half flat grey.
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [ac.navy, ac.navy2, Color.lerp(ac.navy2, ac.primary, 0.5)!],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Form(
                  key: _formKey,
                  // Groups the email/password fields so the platform
                  // password manager (Android/iOS/Chrome autofill) can
                  // both offer saved credentials on focus AND prompt to
                  // save new ones after a successful sign-in -- without
                  // this, autofillHints alone on the individual fields
                  // isn't reliably picked up.
                  child: AutofillGroup(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Opened from the voucher screen: give a way back to it.
                    if (Navigator.of(context).canPop())
                      IconButton(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    else
                      const SizedBox(height: 48),

                    // Brand name + subline -- no logo mark on this screen
                    // by design (correction pass: sign-in should present
                    // Green Hills identity via clean text, not an image
                    // mark), reads from Branding so it's never hardcoded
                    // to a specific product name.
                    Text(Branding.current.appName,
                        style: AppText.display.copyWith(fontSize: 26, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Sign in to your account',
                        style: AppText.bodySm.copyWith(
                            color: Colors.white.withValues(alpha: .55))),
                    const SizedBox(height: 48),

                    // Section label
                    Text('SIGN IN', style: AppText.label.copyWith(
                        fontSize: 10.5, letterSpacing: 1.5, color: ac.gold)),
                    const SizedBox(height: 16),

                    // Error banner
                    if (_error != null) ...[
                      _ErrorBanner(message: _error!),
                      const SizedBox(height: 16),
                    ],

                    // Email
                    _GlassField(
                      controller: _emailCtrl,
                      hint: 'Email address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      validator: (v) => v == null || !v.contains('@')
                          ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 12),

                    // Password
                    _GlassField(
                      controller: _passwordCtrl,
                      hint: 'Password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _login(),
                      validator: (v) => v == null || v.length < 6
                          ? 'Enter your password' : null,
                      suffix: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: Colors.white38, size: 18),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : () => _showForgotPasswordSheet(context),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 4)),
                        child: Text('Forgot password?',
                            style: AppText.subtitle.copyWith(fontSize: 12.5, color: ac.gold)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sign in button
                    _loading
                        ? Center(child: CircularProgressIndicator(color: ac.gold))
                        : _SignInButton(onTap: _login),

                    const SizedBox(height: 40),

                    // Footer
                    Center(child: Text(Branding.current.tagline,
                        style: AppText.caption.copyWith(
                            color: Colors.white.withValues(alpha: .3)))),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  const _GlassField({
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
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: .08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: ac.gold.withValues(alpha: .2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .12))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: ac.gold, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: ac.red, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: ac.red, width: 1.5)),
        errorStyle: const TextStyle(color: Color(0xFFFC8181)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ac.bdr),
      ),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, color: ac.gold, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: AppText.bodySm.copyWith(color: ac.txt))),
      ]),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignInButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final radius = BorderRadius.circular(14);
    return Container(
      width: double.infinity, height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [ac.gold, const Color(0xFFEBB83A)]),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: ac.gold.withValues(alpha: .15),
              blurRadius: 4, offset: const Offset(0, 1)),
          BoxShadow(color: ac.gold.withValues(alpha: .32),
              blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      // Material+InkWell instead of a bare GestureDetector — matches the
      // ripple + haptic feedback every other tappable surface in the app
      // gives (ACard, buttons), so the highest-stakes tap in the whole
      // flow doesn't feel deader than everything around it.
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          splashColor: ac.navy.withValues(alpha: .08),
          highlightColor: ac.navy.withValues(alpha: .05),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Center(child: Text('Sign In →', style: AppText.button.copyWith(
              fontSize: 16, fontWeight: FontWeight.w800, color: ac.navy))),
        ),
      ),
    );
  }
}

// lib/screens/login_screen.dart
// Modernized login — immersive navy gradient, animated entry, email+password.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  final SchoolConfig school;
  const LoginScreen({super.key, required this.school});
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
        setState(() { _error = 'Account not found. Check your credentials.'; _loading = false; });
      }
      // AppRouter stream takes over on success.
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [C.navy, C.navy2, Color(0xFF1A3A70)],
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 20),
                    // Logo
                    AcademiaLogo(size: 52),
                    const SizedBox(height: 28),

                    // School name + motto
                    Text(widget.school.name,
                        style: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(widget.school.motto,
                        style: GoogleFonts.inter(fontSize: 13,
                            color: Colors.white.withValues(alpha: .55))),
                    const SizedBox(height: 48),

                    // Section label
                    Text('SIGN IN', style: GoogleFonts.sora(fontSize: 10,
                        fontWeight: FontWeight.w700, letterSpacing: 1.5,
                        color: C.gold)),
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
                    const SizedBox(height: 28),

                    // Sign in button
                    _loading
                        ? const Center(child: CircularProgressIndicator(color: C.gold))
                        : _SignInButton(onTap: _login),

                    const SizedBox(height: 40),

                    // Footer
                    Center(child: Text('Powered by Academia',
                        style: GoogleFonts.inter(fontSize: 11,
                            color: Colors.white.withValues(alpha: .3)))),
                  ]),
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
  const _GlassField({
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
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: .08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: C.gold.withValues(alpha: .2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .12))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: C.gold, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: C.red, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: C.red, width: 1.5)),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.red.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.red.withValues(alpha: .3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: C.red, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: .9)))),
      ]),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignInButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [C.gold, Color(0xFFEBB83A)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color: C.gold.withValues(alpha: .35),
            blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Center(child: Text('Sign In →',
            style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800,
                color: C.navy))),
      ),
    );
  }
}

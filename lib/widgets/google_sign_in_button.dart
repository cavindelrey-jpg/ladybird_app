// lib/widgets/google_sign_in_button.dart
// Reusable "Continue with Google" button. Used on CreateAccountScreen (and
// anywhere else an independent sign-in entry point is added later). Does
// not navigate — AppRouter's authStateChanges StreamBuilder reacts to the
// new session automatically once sign-in succeeds.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

class GoogleSignInButton extends StatefulWidget {
  final void Function(AppUser user)? onSignedIn;
  final void Function(String message)? onError;
  const GoogleSignInButton({super.key, this.onSignedIn, this.onError});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _loading = false;

  Future<void> _handleTap() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        widget.onSignedIn?.call(user);
      }
      // user == null -> picker was cancelled, nothing to do.
    } catch (e) {
      widget.onError?.call(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _loading ? null : _handleTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: ac.bdr),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
        ),
        child: _loading
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.g_mobiledata_rounded, size: 26, color: ac.navy),
                  const SizedBox(width: 6),
                  Text('Continue with Google',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600, color: ac.navy)),
                ],
              ),
      ),
    );
  }
}

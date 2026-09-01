// lib/pages/change_password_page.dart
// Real Supabase Auth flow: reauthenticate with current password, then
// set the new one.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/widgets.dart';

import '../widgets/app_background.dart';
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true, _obscureNew = true, _obscureConfirm = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await AuthService.instance.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;
      showToast(context, 'Password updated.');
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Change Password', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
      ),
      body: AppBackground(child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Update your sign-in password', style: GoogleFonts.sora(
                fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt)),
            const SizedBox(height: 6),
            Text("You'll need to confirm your current password first.",
                style: GoogleFonts.inter(fontSize: 13, color: ac.txt2)),
            const SizedBox(height: 24),
            _field(
              controller: _currentCtrl,
              label: 'Current Password',
              obscure: _obscureCurrent,
              onToggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ac: ac,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _newCtrl,
              label: 'New Password',
              obscure: _obscureNew,
              onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) {
                if (v == null || v.length < 6) return 'At least 6 characters';
                return null;
              },
              ac: ac,
            ),
            const SizedBox(height: 14),
            _field(
              controller: _confirmCtrl,
              label: 'Confirm New Password',
              obscure: _obscureConfirm,
              onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v != _newCtrl.text) return 'Passwords do not match';
                return null;
              },
              ac: ac,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: ac.redBg, borderRadius: BorderRadius.circular(Rad.sm)),
                child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: ac.red)),
              ),
            ],
            const SizedBox(height: 28),
            PrimaryBtn(label: 'Update Password', onTap: _submit, loading: _saving),
          ],
        ),
      )),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
    required AppColors ac,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 14, color: ac.txt),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: ac.surf3,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20, color: ac.muted),
          onPressed: onToggleObscure,
        ),
      ),
    );
  }
}

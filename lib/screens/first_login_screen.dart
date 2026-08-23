// lib/screens/first_login_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../widgets/widgets.dart';

class FirstLoginScreen extends StatefulWidget {
  final AppUser user;
  const FirstLoginScreen({super.key, required this.user});
  @override
  State<FirstLoginScreen> createState() => _FirstLoginScreenState();
}

class _FirstLoginScreenState extends State<FirstLoginScreen> {
  bool _done = false;

  Future<void> _complete() async {
    setState(() => _done = true);
    await AuthService.markFirstLoginComplete(widget.user.id);
    // AppRouter StreamBuilder reacts to isFirstLogin change automatically
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BrandLogo(size: 72),
              const SizedBox(height: 24),
              Text('Welcome, ${widget.user.name.split(' ').first}!',
                style: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w800, color: ac.txt),
                textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text('Your school account is ready.\nLet\'s get you started.',
                style: GoogleFonts.inter(fontSize: 15, color: ac.txt2, height: 1.5),
                textAlign: TextAlign.center),
              const SizedBox(height: 48),
              PrimaryBtn(label: 'Get Started', loading: _done, onTap: _complete),
            ],
          ),
        ),
      ),
    );
  }
}

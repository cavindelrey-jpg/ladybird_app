// lib/pages/help_support_page.dart
// Replaces the ComingSoonPage stub. Static FAQ + contact — no backend
// needed; update the FAQ list here as real support questions come in.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';

import '../widgets/app_background.dart';
class _Faq {
  final String q, a;
  const _Faq(this.q, this.a);
}

const _faqs = [
  _Faq('How do I link my account to my school?',
      "Go to Settings or the welcome screen and choose 'I have a school code'. "
      'Enter the code your school administrator gave you, then sign in or create '
      'your account to link it.'),
  _Faq('I forgot my password. What do I do?',
      "On the sign-in screen, tap 'Forgot password?' and enter your email. "
      "You'll get a reset link from Firebase. If you signed in with Google, "
      "there's no password to reset — just use 'Sign in with Google' again."),
  _Faq('What does Premium unlock?',
      'A one-time payment unlocks full access to past exam questions and '
      'papers across every subject, instead of the limited free preview.'),
  _Faq('How do I pay for Premium?',
      'Payment is via MTN Mobile Money or Orange Money, right in the app, '
      'on the Premium unlock screen.'),
  _Faq('Can I use the app without a school?',
      'Yes — create an independent account to access the Content Library, '
      'Past Questions, Groups, and (soon) the Academia Magazine without '
      'being linked to any institution.'),
  _Faq('How do I switch to a different school?',
      "Open Settings and tap 'Switch School' (only shown for school-linked "
      'accounts) to leave your current institution and enter a new code.'),
];

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Help & Support', style: GoogleFonts.sora(
            fontSize: 16, fontWeight: FontWeight.w700, color: ac.txt)),
      ),
      body: AppBackground(child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Frequently Asked Questions', style: GoogleFonts.sora(
              fontSize: 14, fontWeight: FontWeight.w800, color: ac.txt)),
          const SizedBox(height: 12),
          ..._faqs.map((f) => _FaqTile(faq: f)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Still need help?', style: GoogleFonts.sora(
                  fontSize: 14, fontWeight: FontWeight.w700, color: ac.txt)),
              const SizedBox(height: 6),
              Text('Reach our support team directly and we\'ll get back to you.',
                  style: GoogleFonts.inter(fontSize: 12, color: ac.txt2)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(
                      'mailto:support@academia.cm?subject=Academia%20Support')),
                  icon: const Icon(Icons.email_outlined, size: 18),
                  label: const Text('Email support@academia.cm'),
                ),
              ),
            ]),
          ),
        ],
      )),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final _Faq faq;
  const _FaqTile({required this.faq});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: ac.surf, borderRadius: BorderRadius.circular(Rad.md), border: Border.all(color: ac.bdr)),
      child: Column(children: [
        ListTile(
          title: Text(widget.faq.q, style: GoogleFonts.inter(
              fontSize: 13.5, fontWeight: FontWeight.w600, color: ac.txt)),
          trailing: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: ac.muted),
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.faq.a,
                  style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2, height: 1.5)),
            ),
          ),
      ]),
    );
  }
}

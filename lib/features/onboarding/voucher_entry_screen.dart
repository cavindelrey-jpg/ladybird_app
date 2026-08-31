// lib/features/onboarding/voucher_entry_screen.dart
// The front door for a signed-out user (2026-09 correction to the
// 2026-08-31 redesign): a fresh install shows this FIRST, before any
// guest browsing. Two real choices — activate with a voucher code, or
// sign in to an account that already has one redeemed — plus a small
// "continue as guest" escape hatch, not removed, just no longer primary.
//
// Why this exists (vs. just going straight to guest/AccountChoiceScreen):
// a student who redeemed their voucher once should never be asked for it
// again — reopening the app (same install, same session) skips this
// screen entirely because AppRouter only shows it when signed out.
// Deleting and reinstalling the app DOES sign them out (session storage
// is gone), but the account itself and its school-membership/entitlement
// are server-side, untouched — "I already have an account" signs back
// into the SAME account, no new code needed, since the school won't
// hand out a second one.
//
// A voucher code entered here does NOT lead to the general Academia
// Individual/Silver/Gold picker (account_choice_screen.dart) — that
// flow is for someone choosing a tier to pay for. A voucher already
// carries its tier in its own code (see school_voucher.dart's
// VoucherPremiumTier), so it goes straight to voucher_signup_screen.dart
// instead.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/school_voucher.dart';
import '../../models/academia_voucher.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../config/branding.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'voucher_signup_screen.dart';
import '../../screens/login_screen.dart';

class VoucherEntryScreen extends StatefulWidget {
  final VoidCallback onBrowseAsGuest;
  const VoucherEntryScreen({super.key, required this.onBrowseAsGuest});

  @override
  State<VoucherEntryScreen> createState() => _VoucherEntryScreenState();
}

class _VoucherEntryScreenState extends State<VoucherEntryScreen> {
  final _codeCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  /// A code is either an Academia code (AC-...) or a school code
  /// (this app's own prefix, e.g. GH-.../LB-...) — both share the same
  /// alphabet/normalize rules, so either parser's format check is
  /// authoritative for its own prefix.
  String? _validateAndNormalize() {
    final raw = _codeCtrl.text;
    final normalized = SchoolVoucher.normalizeCode(raw);
    final isAcademia = normalized.startsWith('AC-');
    final valid = isAcademia ? AcademiaVoucher.isPlausibleCode(raw) : SchoolVoucher.isPlausibleCode(raw);
    if (!valid) return null;
    return normalized;
  }

  void _activate() {
    final normalized = _validateAndNormalize();
    if (normalized == null) {
      setState(() => _error = 'That code doesn\'t look right — check it and try again.');
      return;
    }
    setState(() => _error = null);
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VoucherSignUpScreen(voucherCode: normalized)));
  }

  void _login() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: AppBackground(child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Center(child: BrandLogo(size: 64)),
            const SizedBox(height: 20),
            Text('Activate Your Account',
                style: AppText.h1.copyWith(fontSize: 24, color: ac.txt)),
            const SizedBox(height: 8),
            Text(
              'Enter the code ${Branding.current.appName} gave you. It '
              'identifies your role and Premium tier — you\'ll only see '
              'what\'s relevant to you.',
              style: AppText.body.copyWith(color: ac.txt2),
            ),
            const SizedBox(height: 28),

            Text('Voucher code', style: AppText.title.copyWith(fontSize: 13, color: ac.txt)),
            const SizedBox(height: 8),
            TextField(
              controller: _codeCtrl,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              style: AppText.body.copyWith(fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.w700, color: ac.txt),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '${Branding.current.voucherPrefix}-S-XXXXXX-G',
                hintStyle: AppText.body.copyWith(fontSize: 20, letterSpacing: 2, color: ac.muted),
                filled: true,
                fillColor: ac.surf3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: AppText.bodySm.copyWith(color: ac.red)),
            ],

            const SizedBox(height: 24),
            PrimaryBtn(label: 'Activate', onTap: _activate),

            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Divider(color: ac.bdr)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('or', style: AppText.bodySm.copyWith(color: ac.muted)),
              ),
              Expanded(child: Divider(color: ac.bdr)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _login,
                child: const Text('I already have an account — Log In'),
              ),
            ),

            const SizedBox(height: 28),
            Center(
              child: TextButton(
                onPressed: widget.onBrowseAsGuest,
                child: Text('Continue browsing without a code',
                    style: AppText.body.copyWith(color: ac.txt2, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      )),
    );
  }
}

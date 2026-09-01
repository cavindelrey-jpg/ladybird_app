// lib/widgets/premium_unlock_sheet.dart
// "Create Premium Account" — the ordinary premium purchase options
// (MoMo/Orange Money direct payment) PLUS, at the bottom, an optional
// voucher code field (2026-08-31 redesign, item 5: the voucher is never
// a first-screen obstacle — it's entered from here, after the user has
// already chosen to go premium). Direct payment writes a pending payment
// record (see supabase/migrations/20260829340000_payments.sql,
// 20260829500000_payments_tier_package.sql) that nothing currently
// processes — no backend integration exists to actually launch the
// MoMo/Orange Money USSD prompt yet. A voucher code, by contrast, grants
// the entitlement immediately and for real: entering a valid one skips
// tier/duration/payment selection entirely (the code is the authority —
// item 6) and calls the matching redeem RPC server-side.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/result.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../models/entitlement.dart';
import '../models/purchase.dart';
import '../models/academia_voucher.dart';
import '../models/school_voucher.dart';
import '../repositories/academia_voucher_repository.dart';
import '../repositories/school_access_repository.dart';
import 'widgets.dart' show showToast;

class PremiumUnlockSheet extends StatefulWidget {
  final String userId;
  final VoidCallback onUnlockSuccess;

  /// Which tier this sheet opens on — callers that know exactly why the
  /// user is here (e.g. a locked Video Course) should preselect Gold;
  /// general "Go Premium" entry points default to Silver, the cheaper
  /// first step. Either way the user can switch tiers before paying.
  final EntitlementTier initialTier;

  const PremiumUnlockSheet({
    super.key,
    required this.userId,
    required this.onUnlockSuccess,
    this.initialTier = EntitlementTier.silver,
  });

  @override
  State<PremiumUnlockSheet> createState() => _PremiumUnlockSheetState();
}

class _PremiumUnlockSheetState extends State<PremiumUnlockSheet> {
  final _phoneController = TextEditingController();
  final _voucherController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedProvider = 'mtn'; // default
  late EntitlementTier _tier = widget.initialTier == EntitlementTier.free
      ? EntitlementTier.silver
      : widget.initialTier;
  int _months = 1; // 1 / 3 / 6 / 12
  bool _isLoading = false;
  String? _errorMessage;

  bool _showVoucherField = false;
  bool _redeemingVoucher = false;
  String? _voucherError;

  EntitlementPackage get _package {
    switch ((_tier, _months)) {
      case (EntitlementTier.silver, 1):  return EntitlementPackage.silver1Month;
      case (EntitlementTier.silver, 3):  return EntitlementPackage.silver3Months;
      case (EntitlementTier.silver, 6):  return EntitlementPackage.silver6Months;
      case (EntitlementTier.silver, 12): return EntitlementPackage.silver1Year;
      case (EntitlementTier.gold, 1):    return EntitlementPackage.gold1Month;
      case (EntitlementTier.gold, 3):    return EntitlementPackage.gold3Months;
      case (EntitlementTier.gold, 6):    return EntitlementPackage.gold6Months;
      case (EntitlementTier.gold, 12):   return EntitlementPackage.gold1Year;
      default:                           return EntitlementPackage.silver1Month;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  /// A code's own prefix determines which table/RPC it belongs to
  /// (redesign item 7): 'AC' is Academia, anything else is a school
  /// code. This build's [Branding.current.voucherPrefix] is what the
  /// server-side tenant check actually enforces — this local branch is
  /// just choosing which client call to make, not a security boundary.
  Future<void> _redeemVoucher() async {
    FocusScope.of(context).unfocus();
    final raw = _voucherController.text;
    setState(() {
      _redeemingVoucher = true;
      _voucherError = null;
    });

    final normalized = raw.toUpperCase().trim();
    final isAcademiaCode = normalized.startsWith('AC-');

    if (isAcademiaCode) {
      final result = await AcademiaVoucherRepository.instance.redeemVoucher(
        userId: widget.userId,
        rawCode: raw,
      );
      if (!mounted) return;
      setState(() => _redeemingVoucher = false);
      switch (result) {
        case Success(:final value):
          HapticFeedback.mediumImpact();
          showToast(context, '${value.premiumTier.label} unlocked — welcome, ${value.role.label}');
          widget.onUnlockSuccess();
          if (mounted) Navigator.of(context).pop();
        case Failure(:final message):
          setState(() => _voucherError = message);
      }
      return;
    }

    final result = await SchoolAccessRepository.instance.redeemSchoolVoucher(
      userId: widget.userId,
      rawCode: raw,
    );
    if (!mounted) return;
    setState(() => _redeemingVoucher = false);
    switch (result) {
      case Success(:final value):
        HapticFeedback.mediumImpact();
        final premiumLabel = value.premiumTier?.label ?? 'Free';
        showToast(context,
            'Connected to ${value.school.name} as a ${value.role.label} — $premiumLabel unlocked');
        widget.onUnlockSuccess();
        if (mounted) Navigator.of(context).pop();
      case Failure(:final message):
        setState(() => _voucherError = message);
    }
  }

  Future<void> _handlePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final package = _package;
      await Supabase.instance.client.from('payments').insert({
        'user_id': widget.userId,
        'phone_number': _phoneController.text.trim(),
        'provider': _selectedProvider,
        'tier': package.tier.name,
        'package': package.name,
        'duration_days': package.durationDays,
        'amount': package.suggestedPriceFcfa,
        'currency': 'XAF',
        'status': 'pending',
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => _PendingDialog(provider: _selectedProvider, tier: package.tier),
      );
      widget.onUnlockSuccess();
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final package = _package;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 12, left: 24, right: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: ac.bdr, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Row(children: [
              Container(
                width: 44, height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: ac.goldBg, borderRadius: BorderRadius.circular(Rad.sm)),
                child: Icon(Icons.workspace_premium_rounded, color: ac.gold, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Unlock Premium', style: AppText.h2.copyWith(fontSize: 17)),
                  Text('Choose Silver or Gold, and how long.', style: AppText.bodySm),
                ]),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: ac.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
            const SizedBox(height: 20),

            Text('PLAN', style: AppText.label.copyWith(letterSpacing: 1)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _TierCard(
                  label: 'Silver',
                  sub: 'No Video Courses',
                  isSelected: _tier == EntitlementTier.silver,
                  onTap: () => setState(() => _tier = EntitlementTier.silver),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TierCard(
                  label: 'Gold',
                  sub: 'Everything, incl. Video',
                  isSelected: _tier == EntitlementTier.gold,
                  onTap: () => setState(() => _tier = EntitlementTier.gold),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            Text('DURATION', style: AppText.label.copyWith(letterSpacing: 1)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [1, 3, 6, 12].map((m) {
              final selected = _months == m;
              return ChoiceChip(
                label: Text(m == 1 ? '1 month' : '$m months'),
                selected: selected,
                onSelected: (_) => setState(() => _months = m),
                selectedColor: ac.primaryBg,
                labelStyle: AppText.subtitle.copyWith(
                    fontSize: 12, color: selected ? ac.primary : ac.txt2),
                side: BorderSide(color: selected ? ac.primary : ac.bdr),
              );
            }).toList()),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: ac.goldBg,
                borderRadius: BorderRadius.circular(Rad.md),
                border: Border.all(color: ac.gold.withValues(alpha: .18)),
              ),
              child: Text('${package.suggestedPriceFcfa} FCFA — ${package.label}',
                  textAlign: TextAlign.center,
                  style: AppText.display.copyWith(fontSize: 16, color: ac.navy)),
            ),
            const SizedBox(height: 20),

            Text('PAYMENT METHOD', style: AppText.label.copyWith(letterSpacing: 1)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _ProviderCard(
                  label: 'MTN MoMo',
                  color: const Color(0xFFFFCC00),
                  isSelected: _selectedProvider == 'mtn',
                  onTap: () => setState(() => _selectedProvider = 'mtn'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ProviderCard(
                  label: 'Orange Money',
                  color: const Color(0xFFFF6600),
                  isSelected: _selectedProvider == 'orange',
                  onTap: () => setState(() => _selectedProvider = 'orange'),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: AppText.body.copyWith(fontSize: 14),
              decoration: InputDecoration(
                hintText: '6XX XXX XXX',
                hintStyle: AppText.body.copyWith(fontSize: 14, color: ac.muted),
                prefixText: '+237 ',
                prefixStyle: AppText.body.copyWith(fontSize: 14),
                filled: true, fillColor: ac.surf3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter your phone number';
                if (value.length < 9) return 'Enter a valid Cameroon phone number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null) ...[
              Text(_errorMessage!,
                  style: AppText.bodySm.copyWith(color: ac.red), textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handlePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ac.navy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
                  elevation: 0,
                  overlayColor: Colors.white.withValues(alpha: .1),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text('Pay Now', style: AppText.button),
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: ac.bdr),
            const SizedBox(height: 12),

            if (!_showVoucherField)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _showVoucherField = true),
                  child: Text('Have a voucher code? Enter voucher code',
                      style: AppText.subtitle.copyWith(fontSize: 13)),
                ),
              )
            else ...[
              Text('VOUCHER CODE', style: AppText.label.copyWith(letterSpacing: 1)),
              const SizedBox(height: 10),
              TextField(
                controller: _voucherController,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                style: AppText.body.copyWith(fontSize: 16, letterSpacing: 1.5, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'GH-T-XXXXXX-G',
                  hintStyle: AppText.body.copyWith(fontSize: 16, letterSpacing: 1.5, color: ac.muted),
                  filled: true, fillColor: ac.surf3,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.md), borderSide: BorderSide.none),
                ),
              ),
              if (_voucherError != null) ...[
                const SizedBox(height: 8),
                Text(_voucherError!, style: AppText.bodySm.copyWith(color: ac.red), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _redeemingVoucher ? null : _redeemVoucher,
                  child: _redeemingVoucher
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Redeem code'),
                ),
              ),
            ],

            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Skip for now', style: AppText.subtitle.copyWith(fontSize: 13)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _PendingDialog extends StatelessWidget {
  final String provider;
  final EntitlementTier tier;
  const _PendingDialog({required this.provider, required this.tier});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final providerLabel = provider == 'mtn' ? 'MTN MoMo' : 'Orange Money';
    final tierLabel = tier == EntitlementTier.gold ? 'Premium Gold' : 'Premium Silver';
    return AlertDialog(
      backgroundColor: ac.surf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.lg)),
      title: Row(children: [
        Icon(Icons.check_circle_outline_rounded, color: ac.grn),
        const SizedBox(width: 8),
        Expanded(child: Text('Prompt sent', style: AppText.h2.copyWith(fontSize: 16))),
      ]),
      content: Text(
        'Check your phone for the $providerLabel PIN prompt to approve the '
        'payment. $tierLabel access unlocks automatically once it\'s confirmed.',
        style: AppText.bodySm.copyWith(height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // dialog
            Navigator.of(context).pop(); // sheet
          },
          child: Text('Got it', style: AppText.subtitle.copyWith(color: ac.primary)),
        ),
      ],
    );
  }
}

class _TierCard extends StatelessWidget {
  final String label;
  final String sub;
  final bool isSelected;
  final VoidCallback onTap;
  const _TierCard({
    required this.label, required this.sub,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final radius = BorderRadius.circular(Rad.md);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () { HapticFeedback.selectionClick(); onTap(); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? ac.goldBg : ac.surf3,
            border: Border.all(color: isSelected ? ac.gold : ac.bdr, width: isSelected ? 1.6 : 1),
            borderRadius: radius,
          ),
          child: Column(children: [
            Text(label, style: AppText.title.copyWith(fontSize: 14)),
            const SizedBox(height: 2),
            Text(sub, style: AppText.caption.copyWith(fontSize: 10.5), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProviderCard({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final radius = BorderRadius.circular(Rad.md);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: .12) : ac.surf3,
            border: Border.all(color: isSelected ? color : ac.bdr, width: isSelected ? 1.6 : 1),
            borderRadius: radius,
          ),
          child: Column(children: [
            CircleAvatar(radius: 10, backgroundColor: color),
            const SizedBox(height: 8),
            Text(label, style: AppText.title.copyWith(fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

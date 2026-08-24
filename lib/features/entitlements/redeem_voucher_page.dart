// lib/features/entitlements/redeem_voucher_page.dart
// production_plan.md §9 — the redeemer's side of the gifting flow.
//
// This is the ONLY part of §9 an ordinary user ever sees. A parent bought
// a voucher in person; the child types the code here and their account
// receives Premium. Per §9, "the child does not need to know anything
// about the underlying transaction" — so this page never shows the
// amount paid, the payment method, the buyer, or the sales agent. It
// shows what was granted and for how long, and nothing about the money.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../repositories/entitlement_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class RedeemVoucherPage extends StatefulWidget {
  final AppUser user;
  const RedeemVoucherPage({super.key, required this.user});

  @override
  State<RedeemVoucherPage> createState() => _RedeemVoucherPageState();
}

class _RedeemVoucherPageState extends State<RedeemVoucherPage> {
  final _codeCtrl = TextEditingController();
  bool _redeeming = false;
  String? _error;
  RedemptionOutcome? _outcome;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() {
      _redeeming = true;
      _error = null;
      _outcome = null;
    });

    final result = await EntitlementRepository.instance.redeemVoucher(
      user: widget.user,
      rawCode: _codeCtrl.text,
    );

    if (!mounted) return;
    setState(() => _redeeming = false);

    switch (result) {
      case Success(:final value):
        setState(() => _outcome = value);
        _codeCtrl.clear();
        showToast(context, 'Premium unlocked');
      case Failure(:final message):
        setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final ent = widget.user.entitlement;
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Redeem a Voucher', style: AppText.title),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Current status, from the real user document.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: ac.surf2, borderRadius: BorderRadius.circular(Rad.sm)),
              child: Row(children: [
                Icon(
                  widget.user.isPremium
                      ? Icons.workspace_premium_rounded
                      : Icons.lock_open_rounded,
                  size: 18,
                  color: widget.user.isPremium ? ac.gold : ac.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current plan: ${widget.user.entitlementLabel}',
                            style: AppText.body.copyWith(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        if (ent.isActive && ent.expiresAt != null)
                          Text(
                            'Active until ${_fmtDate(ent.expiresAt!)}'
                            '${ent.daysRemaining != null ? ' · ${ent.daysRemaining} days left' : ''}',
                            style: AppText.caption,
                          ),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            Text('Voucher code', style: AppText.title.copyWith(fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _codeCtrl,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              style: AppText.body.copyWith(
                  fontSize: 20, letterSpacing: 3, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'XXXX-XXXX-XXXX',
                hintStyle: AppText.body.copyWith(
                    fontSize: 20, letterSpacing: 3, color: ac.muted),
                filled: true,
                fillColor: ac.surf3,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Rad.sm),
                    borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _redeeming ? null : _redeem(),
            ),
            const SizedBox(height: 8),
            Text(
              'Type the code exactly as printed. Capitals and dashes don\'t '
              'matter — the codes never contain the letter O or the digits '
              '0 and 1, so nothing is easy to mistype.',
              style: AppText.caption,
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: ac.redBg, borderRadius: BorderRadius.circular(Rad.sm)),
                child:
                    Text(_error!, style: AppText.bodySm.copyWith(color: ac.red)),
              ),
            ],

            const SizedBox(height: 24),
            PrimaryBtn(
              label: 'Redeem',
              loading: _redeeming,
              onTap: _redeem,
            ),

            if (_outcome != null) ...[
              const SizedBox(height: 24),
              _SuccessCard(outcome: _outcome!),
            ],

            const SizedBox(height: 32),
            Text('Where do vouchers come from?',
                style: AppText.title.copyWith(fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              'Someone can buy Premium for you at a sales point and '
              'give you the code. Redeeming it here adds Premium to this '
              'account — if you already have Premium, the new time is added '
              'to what you have left rather than replacing it.',
              style: AppText.caption,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _SuccessCard extends StatelessWidget {
  final RedemptionOutcome outcome;
  const _SuccessCard({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final ent = outcome.entitlement;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ac.grnBg,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.grn.withValues(alpha: .4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.check_circle_rounded, size: 20, color: ac.grn),
          const SizedBox(width: 8),
          Text(
            outcome.wasExtension ? 'Premium extended' : 'Premium unlocked',
            style: AppText.title.copyWith(fontSize: 15, color: ac.grn),
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          outcome.wasExtension
              ? 'Your ${outcome.voucher.durationDays} extra days have been '
                  'added on top of the time you already had.'
              : 'You now have ${outcome.voucher.durationDays} days of Premium.',
          style: AppText.bodySm,
        ),
        if (ent.expiresAt != null) ...[
          const SizedBox(height: 6),
          Text('Active until ${_RedeemVoucherPageState._fmtDate(ent.expiresAt!)}',
              style: AppText.caption),
        ],
        const SizedBox(height: 10),
        Text(
          'It may take a moment to appear everywhere in the app.',
          style: AppText.caption,
        ),
      ]),
    );
  }
}

/// Convenience so Profile can offer redemption without importing the page
/// type directly at every call site.
Future<void> openRedeemVoucher(BuildContext context, AppUser user) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RedeemVoucherPage(user: user)));

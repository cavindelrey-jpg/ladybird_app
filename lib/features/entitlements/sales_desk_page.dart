// lib/features/entitlements/sales_desk_page.dart
// production_plan.md §9 — the sales-agent side of physical sales.
//
// This page is BOOKKEEPING, not commerce. The money in §9 changes hands
// in person: a parent pays an agent cash at an office, and the agent then
// opens this page to record what already happened and print/hand over the
// voucher code it generates. Nothing here charges anyone, and there is no
// payment provider anywhere in this feature.
//
// Role gate: departmentAdmin and above (AppUser.canManageUsers). There is
// no dedicated `salesAgent` role in the 6-tier system yet, and inventing
// one would mean touching the role enum, its Firestore parsing, and
// firestore.rules' roleLevel() ladder — a much larger blast radius than
// §9 asks for. canManageUsers is the closest existing "trusted staff who
// can act on other people's accounts" gate, which is exactly the
// authority issuing a voucher requires. Logged in docs/AUTOPILOT_LOG.md.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/purchase.dart';
import '../../models/voucher.dart';
import '../../repositories/entitlement_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class SalesDeskPage extends StatefulWidget {
  final AppUser user;
  const SalesDeskPage({super.key, required this.user});

  @override
  State<SalesDeskPage> createState() => _SalesDeskPageState();
}

class _SalesDeskPageState extends State<SalesDeskPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tc = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    // Defence in depth. The entry point in AdminPanelPage is already
    // gated, but a page that grants premium shouldn't rely on its caller
    // being the only way in.
    if (!widget.user.canManageUsers) {
      return Scaffold(
        backgroundColor: ac.bg,
        appBar: AppBar(
          backgroundColor: ac.bg,
          elevation: 0,
          iconTheme: IconThemeData(color: ac.txt),
          title: Text('Sales Desk', style: AppText.title),
        ),
        body: AppBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'You don\'t have permission to issue vouchers.',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: ac.txt2),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Sales Desk', style: AppText.title),
        bottom: TabBar(controller: _tc, tabs: const [
          Tab(text: 'RECORD A SALE'),
          Tab(text: 'VOUCHERS'),
        ]),
      ),
      body: AppBackground(
        child: TabBarView(controller: _tc, children: [
          _RecordSaleTab(agent: widget.user),
          const _VouchersTab(),
        ]),
      ),
    );
  }
}

// ══ Record a sale ═══════════════════════════════════════════════════════

class _RecordSaleTab extends StatefulWidget {
  final AppUser agent;
  const _RecordSaleTab({required this.agent});

  @override
  State<_RecordSaleTab> createState() => _RecordSaleTabState();
}

class _RecordSaleTabState extends State<_RecordSaleTab> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _buyerCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  EntitlementPackage _package = EntitlementPackage.gold1Year;
  PaymentMethod _method = PaymentMethod.cash;
  PurchaseStatus _status = PurchaseStatus.completed;

  bool _saving = false;
  String? _error;

  /// The voucher just issued — shown so the agent can read the code out
  /// to the buyer / write it on the receipt. Real document, straight from
  /// the repository write; never a placeholder.
  Voucher? _issued;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _buyerCtrl.dispose();
    _sourceCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = true;
      _error = null;
      _issued = null;
    });

    final result =
        await EntitlementRepository.instance.recordPurchaseAndIssueVoucher(
      agent: widget.agent,
      amount: num.parse(_amountCtrl.text.trim()),
      paymentMethod: _method,
      package: _package,
      purchaseSource: _sourceCtrl.text.trim(),
      buyerName: _buyerCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
      status: _status,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case Success(:final value):
        setState(() {
          _issued = value;
          _amountCtrl.clear();
          _buyerCtrl.clear();
          _noteCtrl.clear();
        });
        showToast(context, 'Voucher issued — ${value.code}');
      case Failure(:final message):
        setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: ac.surf2, borderRadius: BorderRadius.circular(Rad.sm)),
            child: Text(
              'Record a payment that has already been collected in person. '
              'This does not charge anyone — it files the sale and generates '
              'the voucher code to hand to the buyer.',
              style: AppText.caption,
            ),
          ),
          const SizedBox(height: 20),

          Text('Package *', style: AppText.title.copyWith(fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<EntitlementPackage>(
            initialValue: _package,
            decoration: _dec(ac),
            style: AppText.body.copyWith(fontSize: 14),
            dropdownColor: ac.surf,
            items: EntitlementPackage.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                .toList(),
            onChanged: (v) => setState(() => _package = v ?? _package),
          ),
          const SizedBox(height: 6),
          Text(
            'Grants ${_package.durationDays} days of Premium, counted from the '
            'day the voucher is redeemed (not today).',
            style: AppText.caption,
          ),
          const SizedBox(height: 20),

          Text('Amount collected (FCFA) *',
              style: AppText.title.copyWith(fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppText.body.copyWith(fontSize: 15),
            decoration: _dec(ac, hint: 'e.g. 5000'),
            validator: (v) {
              final parsed = num.tryParse((v ?? '').trim());
              if (parsed == null) return 'Enter the amount collected';
              if (parsed < 0) return 'Amount cannot be negative';
              return null;
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Type what was actually collected — prices are not fixed in the '
            'app, so this records the real figure rather than an assumed one.',
            style: AppText.caption,
          ),
          const SizedBox(height: 20),

          Text('Payment method *', style: AppText.title.copyWith(fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<PaymentMethod>(
            initialValue: _method,
            decoration: _dec(ac),
            style: AppText.body.copyWith(fontSize: 14),
            dropdownColor: ac.surf,
            items: PaymentMethod.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                .toList(),
            onChanged: (v) => setState(() => _method = v ?? _method),
          ),
          const SizedBox(height: 20),

          Text('Buyer name', style: AppText.title.copyWith(fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _buyerCtrl,
            style: AppText.body.copyWith(fontSize: 15),
            decoration: _dec(ac, hint: 'e.g. Mrs. Foka'),
          ),
          const SizedBox(height: 6),
          Text(
            'Who handed over the money. Used for support lookups — the buyer '
            'usually has no account at all.',
            style: AppText.caption,
          ),
          const SizedBox(height: 20),

          Text('Purchase source', style: AppText.title.copyWith(fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _sourceCtrl,
            style: AppText.body.copyWith(fontSize: 15),
            decoration: _dec(ac, hint: 'e.g. Yaoundé Office'),
          ),
          const SizedBox(height: 20),

          Text('Transaction status *',
              style: AppText.title.copyWith(fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<PurchaseStatus>(
            initialValue: _status,
            decoration: _dec(ac),
            style: AppText.body.copyWith(fontSize: 14),
            dropdownColor: ac.surf,
            items: PurchaseStatus.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _noteCtrl,
            maxLines: 2,
            style: AppText.body.copyWith(fontSize: 14),
            decoration: _dec(ac, label: 'Note (optional)'),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: ac.redBg, borderRadius: BorderRadius.circular(Rad.sm)),
              child: Text(_error!, style: AppText.bodySm.copyWith(color: ac.red)),
            ),
          ],

          const SizedBox(height: 28),
          PrimaryBtn(
            label: 'Record sale & issue voucher',
            loading: _saving,
            onTap: _submit,
          ),

          if (_issued != null) ...[
            const SizedBox(height: 24),
            _IssuedVoucherCard(voucher: _issued!),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  InputDecoration _dec(AppColors ac, {String? hint, String? label}) => InputDecoration(
        hintText: hint,
        labelText: label,
        filled: true,
        fillColor: ac.surf3,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Rad.sm),
            borderSide: BorderSide.none),
      );
}

/// The just-issued code, big enough to read aloud across a desk.
class _IssuedVoucherCard extends StatelessWidget {
  final Voucher voucher;
  const _IssuedVoucherCard({required this.voucher});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ac.grnBg,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.grn.withValues(alpha: .4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.confirmation_number_outlined, size: 18, color: ac.grn),
          const SizedBox(width: 8),
          Text('Voucher issued',
              style: AppText.title.copyWith(fontSize: 14, color: ac.grn)),
        ]),
        const SizedBox(height: 12),
        SelectableText(
          voucher.code,
          style: AppText.title.copyWith(fontSize: 26, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        Text('${voucher.packageLabel} · ${voucher.durationDays} days',
            style: AppText.caption),
        const SizedBox(height: 12),
        Text(
          'Give this code to the buyer. Premium starts on the day it is '
          'redeemed, so it can be gifted whenever they like.',
          style: AppText.caption,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: voucher.code));
            HapticFeedback.selectionClick();
            showToast(context, 'Code copied');
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy code'),
        ),
      ]),
    );
  }
}

// ══ Voucher list ════════════════════════════════════════════════════════

class _VouchersTab extends StatelessWidget {
  const _VouchersTab();

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<List<Voucher>>(
      stream: EntitlementRepository.instance.watchVouchers(),
      builder: (context, snap) {
        // Always check hasError before concluding "the list is empty" —
        // a missing composite index surfaces as an error here, not as an
        // empty result (see the CLAUDE.md gotcha).
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text('Could not load vouchers.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: AppText.bodySm.copyWith(color: ac.red)),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final vouchers = snap.data!;
        if (vouchers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'No vouchers issued yet.\nRecord a sale to generate the first one.',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: ac.txt2),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: vouchers.length,
          itemBuilder: (_, i) => _VoucherRow(voucher: vouchers[i]),
        );
      },
    );
  }
}

class _VoucherRow extends StatelessWidget {
  final Voucher voucher;
  const _VoucherRow({required this.voucher});

  static Color _statusColor(AppColors ac, VoucherStatus s) {
    switch (s) {
      case VoucherStatus.unused:   return ac.blu;
      case VoucherStatus.active:   return ac.grn;
      case VoucherStatus.redeemed: return ac.grn;
      case VoucherStatus.expired:  return ac.muted;
      case VoucherStatus.revoked:  return ac.red;
    }
  }

  Future<void> _revoke(BuildContext context) async {
    final ac = AppColors.of(context);
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ac.surf,
        title: Text('Revoke voucher?', style: AppText.title.copyWith(fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'This stops ${voucher.code} from being redeemed. It does not '
            'remove Premium from an account that already redeemed it.',
            style: AppText.bodySm,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            style: AppText.body.copyWith(fontSize: 14),
            decoration: const InputDecoration(hintText: 'Reason (e.g. refunded)'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Revoke', style: TextStyle(color: ac.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await EntitlementRepository.instance
        .revokeVoucher(voucher.id, reasonCtrl.text.trim());
    if (!context.mounted) return;
    switch (result) {
      case Success():
        showToast(context, 'Voucher revoked');
      case Failure(:final message):
        showToast(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final status = voucher.effectiveStatus;
    final color = _statusColor(ac, status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.sm),
        border: Border.all(color: ac.bdr),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(voucher.code,
                style: AppText.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(
              '${voucher.packageLabel.isEmpty ? '${voucher.durationDays} days' : voucher.packageLabel}'
              '${voucher.recipientName != null ? ' · ${voucher.recipientName}' : ''}',
              style: AppText.caption,
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20)),
          child: Text(status.label,
              style: AppText.caption.copyWith(
                  color: color, fontWeight: FontWeight.w700, fontSize: 11)),
        ),
        if (voucher.status == VoucherStatus.unused)
          IconButton(
            tooltip: 'Revoke',
            onPressed: () => _revoke(context),
            icon: Icon(Icons.block_rounded, size: 18, color: ac.muted),
          ),
      ]),
    );
  }
}

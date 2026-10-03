// lib/features/onboarding/school_admin_page.dart
// Staff side of architecture brief items 4-6: registering a school
// (superAdmin only — platform-level, same tier as this codebase's
// existing "Register a School" concept) and issuing that school's
// role-coded voucher codes (schoolAdmin of that school, or superAdmin for
// any school). Without this page the redemption flow in
// school_access_page.dart has nothing to redeem — codes have to come
// from somewhere real, not be typed in by hand into Firestore.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/school.dart';
import '../../models/school_voucher.dart';
import '../../repositories/school_repository.dart';
import '../../repositories/school_access_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class SchoolAdminPage extends StatefulWidget {
  final AppUser user;
  const SchoolAdminPage({super.key, required this.user});

  @override
  State<SchoolAdminPage> createState() => _SchoolAdminPageState();
}

class _SchoolAdminPageState extends State<SchoolAdminPage> {
  School? _selectedSchool;
  SchoolRole _role = SchoolRole.student;
  VoucherPremiumTier _premiumTier = VoucherPremiumTier.silver;
  int _count = 1;
  bool _issuing = false;
  String? _error;
  List<SchoolVoucher> _issued = [];

  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: '1');
  bool _registering = false;
  String? _registerError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _registerSchool() async {
    setState(() {
      _registering = true;
      _registerError = null;
    });
    final result = await SchoolRepository.instance.registerSchool(
      name: _nameCtrl.text,
      code: _codeCtrl.text,
    );
    if (!mounted) return;
    setState(() => _registering = false);
    switch (result) {
      case Success(:final value):
        setState(() => _selectedSchool = value);
        _nameCtrl.clear();
        _codeCtrl.clear();
        showToast(context, 'School registered');
      case Failure(:final message):
        setState(() => _registerError = message);
    }
  }

  int _listVersion = 0;

  Future<void> _issue() async {
    final school = _selectedSchool;
    if (school == null) {
      // Used to return silently -- a dead button for a super admin who
      // hadn't picked a school yet.
      setState(() => _error = 'Choose a school first.');
      return;
    }
    final count = int.tryParse(_countCtrl.text.trim());
    if (count == null || count < 1 || count > 200) {
      setState(() => _error = 'Enter how many codes to generate (1–200).');
      return;
    }
    _count = count;
    HapticFeedback.mediumImpact();
    setState(() {
      _issuing = true;
      _error = null;
      _issued = [];
    });
    final result = await SchoolAccessRepository.instance.issueVouchers(
      school: school,
      role: _role,
      issuedByUid: widget.user.id,
      count: _count,
      premiumTier: _premiumTier,
    );
    if (!mounted) return;
    setState(() => _issuing = false);
    switch (result) {
      case Success(:final value):
        setState(() {
          _issued = value;
          _listVersion++;
        });
      case Failure(:final message):
        setState(() => _error = message);
    }
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    showToast(context, '$what copied');
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg, elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('School Access Admin', style: AppText.title),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.user.isSuperAdmin) ...[
              Text('Register a school', style: AppText.title.copyWith(fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'School name',
                  filled: true, fillColor: ac.surf3,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'School code (e.g. GH)',
                  filled: true, fillColor: ac.surf3,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
                ),
              ),
              if (_registerError != null) ...[
                const SizedBox(height: 8),
                Text(_registerError!, style: AppText.bodySm.copyWith(color: ac.red)),
              ],
              const SizedBox(height: 10),
              PrimaryBtn(label: 'Register School', loading: _registering, onTap: _registerSchool),
              const SizedBox(height: 28),
              Divider(color: ac.bdr),
              const SizedBox(height: 20),
            ],

            Text('Issue voucher codes', style: AppText.title.copyWith(fontSize: 14)),
            const SizedBox(height: 8),

            if (widget.user.isSuperAdmin)
              StreamBuilder<List<School>>(
                stream: SchoolRepository.instance.watchAll(),
                builder: (context, snap) {
                  final schools = snap.data ?? [];
                  return DropdownButtonFormField<School>(
                    initialValue: _selectedSchool,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'School',
                      filled: true, fillColor: ac.surf3,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
                    ),
                    items: schools.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${s.code})'))).toList(),
                    onChanged: (v) => setState(() => _selectedSchool = v),
                  );
                },
              )
            else
              FutureBuilder<School?>(
                future: SchoolRepository.instance.getByIdOnce(widget.user.schoolId ?? ''),
                builder: (context, snap) {
                  final school = snap.data;
                  if (school != null && _selectedSchool == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _selectedSchool = school);
                    });
                  }
                  if (!widget.user.isSchoolAdmin && !widget.user.isSuperAdmin) {
                    return Text('You need to be registered as a school administrator to issue codes.',
                        style: AppText.bodySm.copyWith(color: ac.txt2));
                  }
                  return Text(school != null ? 'Issuing for: ${school.name} (${school.code})' : 'Loading your school…',
                      style: AppText.bodySm.copyWith(color: ac.txt2));
                },
              ),
            const SizedBox(height: 10),

            DropdownButtonFormField<SchoolRole>(
              initialValue: _role,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Role',
                filled: true, fillColor: ac.surf3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
              ),
              // Parent isn't independently issuable — a linked parent code
              // is generated automatically alongside every student code
              // (School -> Student -> Parent, see issueVouchers()).
              items: SchoolRole.values
                  .where((r) => r != SchoolRole.parent)
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                  .toList(),
              onChanged: (v) => setState(() => _role = v ?? SchoolRole.student),
            ),
            const SizedBox(height: 10),

            if (_role == SchoolRole.student)
              DropdownButtonFormField<VoucherPremiumTier>(
                initialValue: _premiumTier,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Premium tier',
                  filled: true, fillColor: ac.surf3,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
                ),
                items: VoucherPremiumTier.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) => setState(() => _premiumTier = v ?? VoucherPremiumTier.silver),
              )
            else
              Text('Premium tier: Gold (fixed for this role)',
                  style: AppText.bodySm.copyWith(color: ac.txt2)),
            const SizedBox(height: 10),
            TextField(
              controller: _countCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'How many codes',
                filled: true, fillColor: ac.surf3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
              ),
              onChanged: (v) => _count = int.tryParse(v) ?? 1,
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: AppText.bodySm.copyWith(color: ac.red)),
            ],
            const SizedBox(height: 14),
            PrimaryBtn(
              label: 'Generate Codes',
              loading: _issuing,
              onTap: _issue,
            ),

            if (_issued.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: Text('Generated ${_issued.length} code${_issued.length == 1 ? '' : 's'}:',
                    style: AppText.bodySm.copyWith(color: ac.txt2))),
                TextButton.icon(
                  onPressed: () => _copy(_issued.map((v) => '${v.code}\t${v.role.label}').join('\n'), 'All codes'),
                  icon: const Icon(Icons.copy_all_rounded, size: 16),
                  label: const Text('Copy all'),
                ),
              ]),
              const SizedBox(height: 8),
              ..._issued.map((v) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: ac.grnBg, borderRadius: BorderRadius.circular(Rad.sm)),
                    child: Row(children: [
                      Expanded(child: SelectableText(v.code, style: AppText.body.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1))),
                      Text(v.role.label, style: AppText.bodySm.copyWith(color: ac.txt2)),
                      IconButton(
                        tooltip: 'Copy',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        onPressed: () => _copy(v.code, 'Code'),
                      ),
                    ]),
                  )),
            ],
            if (_selectedSchool != null) ...[
              const SizedBox(height: 28),
              Divider(color: ac.bdr),
              const SizedBox(height: 16),
              IssuedVouchersSection(key: ValueKey('${_selectedSchool!.id}-$_listVersion'), school: _selectedSchool!),
            ],
          ],
        ),
      ),
    );
  }
}

enum _VoucherFilter { unused, used, all }

/// Every code issued for one school: search, Unused/Used filter, copy,
/// and CSV export. Before this, generated codes were only ever shown
/// once ("write these down or print them now") and were lost on leaving
/// the page.
class IssuedVouchersSection extends StatefulWidget {
  final School school;
  const IssuedVouchersSection({super.key, required this.school});

  @override
  State<IssuedVouchersSection> createState() => _IssuedVouchersSectionState();
}

class _IssuedVouchersSectionState extends State<IssuedVouchersSection> {
  late Future<Result<List<IssuedVoucher>>> _future = _load();
  final _searchCtrl = TextEditingController();
  _VoucherFilter _filter = _VoucherFilter.unused;

  Future<Result<List<IssuedVoucher>>> _load() => SchoolAccessRepository.instance.listVouchers(widget.school.id);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<IssuedVoucher> _visible(List<IssuedVoucher> all) {
    final q = _searchCtrl.text.trim().toUpperCase();
    return all.where((v) {
      if (_filter == _VoucherFilter.unused && v.voucher.status != SchoolVoucherStatus.unused) return false;
      if (_filter == _VoucherFilter.used && !v.isUsed) return false;
      if (q.isEmpty) return true;
      return v.voucher.code.toUpperCase().contains(q) ||
          v.voucher.role.label.toUpperCase().contains(q) ||
          (v.redeemedByName ?? '').toUpperCase().contains(q);
    }).toList();
  }

  Future<void> _export(List<IssuedVoucher> rows) async {
    String esc(String s) => s.contains(',') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;
    final csv = StringBuffer('code,role,premium,status,issued,redeemed_by,redeemed_at\r\n');
    for (final v in rows) {
      csv.write([
        v.voucher.code, v.voucher.role.label, v.voucher.premiumTier?.label ?? 'None', v.voucher.status.name,
        v.voucher.createdAt.toIso8601String().substring(0, 10), v.redeemedByName ?? '',
        v.redeemedAt?.toIso8601String().substring(0, 16).replaceAll('T', ' ') ?? '',
      ].map(esc).join(','));
      csv.write('\r\n');
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/codes_${widget.school.code}_${_filter.name}.csv');
      await file.writeAsString('﻿$csv');
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], text: '${widget.school.name} codes');
    } catch (_) {
      if (mounted) showToast(context, 'Couldn\'t create the export file.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return FutureBuilder<Result<List<IssuedVoucher>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final res = snap.data;
        if (res is! Success<List<IssuedVoucher>>) {
          return Column(children: [
            Text(res is Failure<List<IssuedVoucher>> ? res.message : 'Couldn\'t load issued codes.',
                style: AppText.bodySm.copyWith(color: ac.red)),
            TextButton.icon(
              onPressed: () => setState(() => _future = _load()),
              icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ]);
        }
        final all = res.value;
        final unused = all.where((v) => v.voucher.status == SchoolVoucherStatus.unused).length;
        final used = all.where((v) => v.isUsed).length;
        final rows = _visible(all);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Issued codes · ${widget.school.name}', style: AppText.title.copyWith(fontSize: 14)),
          const SizedBox(height: 4),
          Text('${all.length} issued · $unused unused · $used used', style: AppText.bodySm.copyWith(color: ac.txt2)),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search code, role or student name',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true, filled: true, fillColor: ac.surf3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<_VoucherFilter>(
            segments: [
              ButtonSegment(value: _VoucherFilter.unused, label: Text('Unused ($unused)')),
              ButtonSegment(value: _VoucherFilter.used, label: Text('Used ($used)')),
              const ButtonSegment(value: _VoucherFilter.all, label: Text('All')),
            ],
            selected: {_filter},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
          const SizedBox(height: 6),
          Row(children: [
            TextButton.icon(
              onPressed: rows.isEmpty ? null : () {
                Clipboard.setData(ClipboardData(text: rows.map((v) => '${v.voucher.code}\t${v.voucher.role.label}').join('\n')));
                showToast(context, '${rows.length} codes copied');
              },
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: const Text('Copy list'),
            ),
            TextButton.icon(
              onPressed: rows.isEmpty ? null : () => _export(rows),
              icon: const Icon(Icons.ios_share_rounded, size: 16),
              label: const Text('Export CSV'),
            ),
          ]),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(all.isEmpty ? 'No codes issued for this school yet.' : 'No codes match.',
                  style: AppText.bodySm.copyWith(color: ac.muted)),
            ),
          for (final v in rows.take(300))
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              decoration: BoxDecoration(
                color: ac.surf, borderRadius: BorderRadius.circular(Rad.sm), border: Border.all(color: ac.bdr2)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SelectableText(v.voucher.code,
                      style: AppText.body.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8,
                          color: v.isUsed ? ac.muted : ac.txt,
                          decoration: v.isUsed ? TextDecoration.lineThrough : null)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      v.voucher.role.label,
                      if (v.voucher.premiumTier != null) v.voucher.premiumTier!.label,
                      if (v.isUsed) 'used by ${v.redeemedByName?.isNotEmpty == true ? v.redeemedByName : 'someone'}'
                          '${v.redeemedAt != null ? ' · ${v.redeemedAt!.day}/${v.redeemedAt!.month}/${v.redeemedAt!.year}' : ''}'
                      else if (v.voucher.status == SchoolVoucherStatus.revoked) 'revoked'
                      else 'unused',
                    ].join(' · '),
                    style: AppText.bodySm.copyWith(fontSize: 11.5, color: v.isUsed ? ac.muted : ac.grn),
                  ),
                ])),
                if (!v.isUsed)
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: v.voucher.code));
                      showToast(context, 'Code copied');
                    },
                  ),
              ]),
            ),
          if (rows.length > 300)
            Text('Showing 300 of ${rows.length} — narrow with search or export the full list.',
                style: AppText.bodySm.copyWith(color: ac.muted)),
        ]);
      },
    );
  }
}

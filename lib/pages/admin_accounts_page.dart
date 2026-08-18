// lib/pages/admin_accounts_page.dart
// Full admin accounts panel: list, role change, suspend/unsuspend, search.
// Streams from AccountsRepository (Firestore). No in-memory data.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../repositories/accounts_repository.dart';
import '../widgets/widgets.dart';

class AdminAccountsPage extends StatefulWidget {
  final AppUser user;
  const AdminAccountsPage({super.key, required this.user});

  @override
  State<AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends State<AdminAccountsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  String _search = '';
  String _classFilter = 'All';

  static const _classes = [
    'All', 'Form 1', 'Form 2', 'Form 3', 'Form 4', 'Form 5A', 'Form 5B',
    'Upper Sixth Science', 'Upper Sixth Arts',
    'Lower Sixth Science', 'Lower Sixth Arts',
  ];

  String get _schoolId => widget.user.schoolId ?? '';

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  List<StudentAccount> _filtered(List<StudentAccount> list) {
    var result = _classFilter == 'All'
        ? list
        : list.where((a) => a.classLevel == _classFilter).toList();
    if (_search.isNotEmpty) {
      result = result
          .where((a) =>
      a.accountId.toLowerCase().contains(_search.toLowerCase()) ||
          (a.studentName?.toLowerCase().contains(_search.toLowerCase()) ?? false))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // production_plan.md §10 audit finding: same gap as AdminPanelPage —
    // this page (role changes, suspend/reactivate, seat creation/
    // assignment for real student accounts) had no internal authorization
    // check, trusting whichever caller pushed it. Its only current caller
    // (SchoolManagementPage's hub) already gates on canManageSchool, but
    // that guard lived solely on the caller. Re-checked here too, so a
    // future stray Navigator.push/deep link can't reach it unguarded.
    if (!widget.user.canManageSchool) {
      return const _AdminAccountsAccessDenied();
    }
    if (_schoolId.isEmpty) {
      return const Center(child: Text('No school linked to this account'));
    }

    return StreamBuilder<List<StudentAccount>>(
      stream: AccountsRepository.instance.watchAccounts(_schoolId),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final unassigned = _filtered(
            all.where((a) => a.status == AccountStatus.unassigned).toList());
        final assigned = _filtered(
            all.where((a) => a.status == AccountStatus.assigned).toList());
        final active = _filtered(
            all.where((a) => a.status == AccountStatus.active).toList());
        final suspended = _filtered(
            all.where((a) => a.status == AccountStatus.suspended).toList());

        return Column(children: [
          // Stats bar
          Container(
            color: C.primary,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(children: [
              // Stat chips
              Row(children: [
                _stat('${unassigned.length}', 'Available', C.goldp, C.gold),
                const SizedBox(width: 8),
                _stat('${assigned.length}', 'Assigned', C.blub, C.blu),
                const SizedBox(width: 8),
                _stat('${active.length}', 'Active', C.grnb, C.grn),
                const SizedBox(width: 8),
                _stat('${suspended.length}', 'Suspended', C.redb, C.red),
              ]),
              const SizedBox(height: 12),
              // Search
              TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search by name or account ID…',
                  prefixIcon: const Icon(Icons.search),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              // Class filter
              SizedBox(
                height: 34,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _classes.length,
                  itemBuilder: (_, i) {
                    final selected = _classFilter == _classes[i];
                    return GestureDetector(
                      onTap: () => setState(() => _classFilter = _classes[i]),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_classes[i],
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: selected ? C.primary : Colors.white)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Tabs
              TabBar(
                controller: _tc,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: Colors.white,
                dividerColor: Colors.transparent,
                isScrollable: true,
                tabs: [
                  Tab(text: 'AVAILABLE (${unassigned.length})'),
                  Tab(text: 'ASSIGNED (${assigned.length})'),
                  Tab(text: 'ACTIVE (${active.length})'),
                  Tab(text: 'SUSPENDED (${suspended.length})'),
                ],
              ),
            ]),
          ),

          // FAB to create seats
          Expanded(
            child: Stack(children: [
              TabBarView(controller: _tc, children: [
                _AccountList(
                    accounts: unassigned,
                    status: AccountStatus.unassigned,
                    schoolId: _schoolId),
                _AccountList(
                    accounts: assigned,
                    status: AccountStatus.assigned,
                    schoolId: _schoolId),
                _AccountList(
                    accounts: active,
                    status: AccountStatus.active,
                    schoolId: _schoolId),
                _AccountList(
                    accounts: suspended,
                    status: AccountStatus.suspended,
                    schoolId: _schoolId),
              ]),
              Positioned(
                bottom: 16, right: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'create_seats_fab',
                  onPressed: () => _showCreateSeatsDialog(context),
                  backgroundColor: C.gold,
                  foregroundColor: C.primary,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Seats',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ]);
      },
    );
  }

  Widget _stat(String val, String label, Color bg, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(val,
              style: GoogleFonts.sora(
                  fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label,
              style: GoogleFonts.inter(fontSize: 9, color: Colors.white70)),
        ]),
      ),
    );
  }

  void _showCreateSeatsDialog(BuildContext ctx) {
    String classLevel = _classes[1];
    int count = 1;
    bool loading = false;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (dCtx, setDlg) => AlertDialog(
          title: Text('Create Seats', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: classLevel,
              decoration: const InputDecoration(labelText: 'Class Level'),
              items: _classes.skip(1).map((c) =>
                  DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setDlg(() => classLevel = v ?? classLevel),
            ),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Number of seats'),
              onChanged: (v) => count = int.tryParse(v) ?? 1,
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: loading ? null : () async {
                setDlg(() => loading = true);
                await AccountsRepository.instance.createSeat(
                  schoolId: _schoolId,
                  classLevel: classLevel,
                  count: count,
                );
                if (!dCtx.mounted) return;
                Navigator.pop(dCtx);
                if (ctx.mounted) {
                  showToast(ctx, '✅ $count seat(s) created for $classLevel');
                }
              },
              child: loading
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when this page is reached without canManageSchool — see the
/// build()-level guard above. A real, legible screen rather than a
/// silent pop, same reasoning as SchoolManagementPage's own
/// _AccessDenied.
class _AdminAccountsAccessDenied extends StatelessWidget {
  const _AdminAccountsAccessDenied();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline_rounded, size: 56, color: C.muted),
          const SizedBox(height: 16),
          Text('Access Restricted',
              style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: C.txt)),
          const SizedBox(height: 8),
          Text(
            'Student Records requires a school administrator account.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: C.txt2, height: 1.5),
          ),
        ]),
      ),
    );
  }
}

// ── Account List ─────────────────────────────────────────

class _AccountList extends StatelessWidget {
  final List<StudentAccount> accounts;
  final AccountStatus status;
  final String schoolId;
  const _AccountList({
    required this.accounts,
    required this.status,
    required this.schoolId,
  });

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.manage_accounts_outlined, size: 40, color: C.muted),
          const SizedBox(height: 10),
          Text('No accounts in this category',
              style: GoogleFonts.inter(color: C.muted)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: accounts.length,
      itemBuilder: (_, i) =>
          _AccountTile(account: accounts[i], schoolId: schoolId),
    );
  }
}

// ── Account Tile ─────────────────────────────────────────

class _AccountTile extends StatelessWidget {
  final StudentAccount account;
  final String schoolId;
  const _AccountTile({required this.account, required this.schoolId});

  Color get _statusColor {
    switch (account.status) {
      case AccountStatus.unassigned: return C.muted;
      case AccountStatus.assigned:   return C.blu;
      case AccountStatus.active:     return C.grn;
      case AccountStatus.suspended:  return C.red;
    }
  }

  String get _statusLabel {
    switch (account.status) {
      case AccountStatus.unassigned: return 'Available';
      case AccountStatus.assigned:   return 'Assigned';
      case AccountStatus.active:     return 'Active';
      case AccountStatus.suspended:  return 'Suspended';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: C.surf, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.bdr)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Center(
              child: Text(
                  account.studentName != null
                      ? account.studentName![0].toUpperCase()
                      : '?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: _statusColor))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(account.studentName ?? 'Unassigned Seat',
              style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700)),
          Text('${account.accountId.substring(0, 8)}… · ${account.classLevel}',
              style: GoogleFonts.inter(fontSize: 11, color: C.muted)),
          Row(children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_statusLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: _statusColor)),
            ),
            if (account.status == AccountStatus.assigned &&
                account.tempPassword.isNotEmpty) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: account.tempPassword));
                  showToast(context, 'Temp password copied');
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: C.blub, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.copy, size: 10, color: C.blu),
                    const SizedBox(width: 3),
                    Text('Copy temp password',
                        style: GoogleFonts.inter(fontSize: 10, color: C.blu,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ],
          ]),
        ])),
        _ActionMenu(account: account, schoolId: schoolId),
      ]),
    );
  }
}

// ── Action Menu ──────────────────────────────────────────

class _ActionMenu extends StatelessWidget {
  final StudentAccount account;
  final String schoolId;
  const _ActionMenu({required this.account, required this.schoolId});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: C.muted, size: 18),
      onSelected: (val) async {
        final repo = AccountsRepository.instance;
        switch (val) {
          case 'suspend':
            await repo.suspend(schoolId, account.accountId);
            if (context.mounted) showToast(context, 'Account suspended');
            break;
          case 'unsuspend':
            await repo.unsuspend(schoolId, account.accountId);
            if (context.mounted) showToast(context, 'Account reactivated');
            break;
          case 'assign':
            _showAssignDialog(context);
            break;
        }
      },
      itemBuilder: (_) => [
        if (account.status == AccountStatus.unassigned)
          const PopupMenuItem(value: 'assign',
              child: Row(children: [
                Icon(Icons.person_add_outlined, size: 18),
                SizedBox(width: 8),
                Text('Assign Student'),
              ])),
        if (account.status != AccountStatus.suspended &&
            account.status != AccountStatus.unassigned)
          const PopupMenuItem(value: 'suspend',
              child: Row(children: [
                Icon(Icons.block_outlined, size: 18, color: C.red),
                SizedBox(width: 8),
                Text('Suspend', style: TextStyle(color: C.red)),
              ])),
        if (account.status == AccountStatus.suspended)
          const PopupMenuItem(value: 'unsuspend',
              child: Row(children: [
                Icon(Icons.check_circle_outline, size: 18, color: C.grn),
                SizedBox(width: 8),
                Text('Reactivate', style: TextStyle(color: C.grn)),
              ])),
      ],
    );
  }

  void _showAssignDialog(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final payCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (dCtx, setDlg) => AlertDialog(
          title: Text('Assign Seat', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Student name')),
            const SizedBox(height: 12),
            TextField(controller: payCtrl,
                decoration: const InputDecoration(
                    labelText: 'Payment reference',
                    hintText: 'e.g. MTN-MOMO-123456')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: loading ? null : () async {
                if (nameCtrl.text.trim().isEmpty) return;
                setDlg(() => loading = true);
                await AccountsRepository.instance.assignSeat(
                  schoolId: schoolId,
                  seatId: account.accountId,
                  studentName: nameCtrl.text.trim(),
                  paymentRef: payCtrl.text.trim(),
                );
                if (!dCtx.mounted) return;
                Navigator.pop(dCtx);
                if (ctx.mounted) showToast(ctx, '✅ Seat assigned to ${nameCtrl.text.trim()}');
              },
              child: loading
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }
}
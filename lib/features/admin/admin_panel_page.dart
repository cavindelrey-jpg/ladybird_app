// lib/features/admin/admin_panel_page.dart
// Unified admin panel: Users tab, Seats tab, Platform tab (superAdmin only).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../repositories/accounts_repository.dart';
import '../../services/auth_service.dart';
import '../../providers/institution_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import '../../core/result.dart';
import 'hero_slide_manager_page.dart';
import 'create_institution_page.dart';

class AdminPanelPage extends StatefulWidget {
  final AppUser user;
  const AdminPanelPage({super.key, required this.user});
  @override State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: widget.user.isSuperAdmin ? 3 : 2, vsync: this);
  }

  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('Administration', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        bottom: TabBar(controller: _tc, tabs: [
          const Tab(text: 'USERS'),
          const Tab(text: 'SEATS'),
          if (widget.user.isSuperAdmin) const Tab(text: 'PLATFORM'),
        ]),
      ),
      body: AppBackground(child: TabBarView(controller: _tc, children: [
        _UsersTab(user: widget.user),
        _SeatsTab(user: widget.user),
        if (widget.user.isSuperAdmin) _PlatformTab(user: widget.user),
      ])),
    );
  }
}

// ── USERS tab ─────────────────────────────────────────────

class _UsersTab extends StatefulWidget {
  final AppUser user;
  const _UsersTab({required this.user});
  @override State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _search = '';
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final sid = widget.user.schoolId ?? '';
    return Column(children: [
      Container(
        color: C.primary,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(children: [
          TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users…', hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              fillColor: Colors.white.withValues(alpha: .1), filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(height: 32, child: ListView(
            scrollDirection: Axis.horizontal,
            children: ['All', ...UserRole.values.map((r) => r.name)].map((r) {
              final sel = _filter == r;
              return GestureDetector(
                onTap: () => setState(() => _filter = r),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: sel ? Colors.white : Colors.white.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(r, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? C.primary : Colors.white)),
                ),
              );
            }).toList(),
          )),
        ]),
      ),
      Expanded(
        child: StreamBuilder<List<AppUser>>(
          stream: AuthService.instance.watchSchoolUsers(sid),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            var users = snap.data ?? [];
            if (_filter != 'All') users = users.where((u) => u.role.name == _filter).toList();
            if (_search.isNotEmpty) {
              users = users.where((u) =>
                u.name.toLowerCase().contains(_search.toLowerCase()) ||
                u.email.toLowerCase().contains(_search.toLowerCase())).toList();
            }
            if (users.isEmpty) {
              return Center(
                  child: Text('No users found', style: GoogleFonts.inter(color: C.muted)));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (_, i) => _UserTile(u: users[i], current: widget.user),
            );
          },
        ),
      ),
    ]);
  }
}

class _UserTile extends StatelessWidget {
  final AppUser u, current;
  const _UserTile({required this.u, required this.current});

  Color get _rc {
    switch (u.role) {
      case UserRole.superAdmin:     return C.pur;
      case UserRole.schoolAdmin:    return C.primary;
      case UserRole.departmentAdmin:return C.blu;
      case UserRole.lecturer:       return C.gold;
      case UserRole.student:        return C.grn;
      case UserRole.guest:          return C.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.surf,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bdr)),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: _rc.withValues(alpha: .1), radius: 20,
          child: Text(u.initials,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _rc))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u.name,
              style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: C.txt)),
          Text(u.email, style: GoogleFonts.inter(fontSize: 11, color: C.muted),
              overflow: TextOverflow.ellipsis),
          Wrap(spacing: 6, children: [
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: _rc.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(u.roleLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _rc))),
            if (u.status == AccountStatus.suspended)
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: C.redb, borderRadius: BorderRadius.circular(6)),
                child: const Text('SUSPENDED',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: C.red))),
          ]),
        ])),
        if (u.id != current.id)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: C.muted, size: 18),
            onSelected: (val) async {
              if (val == 'suspend') {
                await AuthService.instance.suspendUser(u.id);
                if (context.mounted) showToast(context, 'User suspended');
              } else if (val == 'reactivate') {
                await AuthService.instance.reactivateUser(u.id);
                if (context.mounted) showToast(context, 'User reactivated');
              } else {
                final role = UserRole.values.firstWhere((r) => r.name == val);
                await AuthService.instance.changeUserRole(u.id, role);
                if (context.mounted) showToast(context, 'Role → ${role.name}');
              }
            },
            itemBuilder: (_) => [
              if (u.status != AccountStatus.suspended)
                const PopupMenuItem(value: 'suspend',
                    child: Row(children: [
                      Icon(Icons.block_outlined, size: 16, color: C.red),
                      SizedBox(width: 8),
                      Text('Suspend', style: TextStyle(color: C.red)),
                    ])),
              if (u.status == AccountStatus.suspended)
                const PopupMenuItem(value: 'reactivate',
                    child: Row(children: [
                      Icon(Icons.check_circle_outline, size: 16, color: C.grn),
                      SizedBox(width: 8),
                      Text('Reactivate', style: TextStyle(color: C.grn)),
                    ])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'student',         child: Text('→ Student')),
              const PopupMenuItem(value: 'lecturer',        child: Text('→ Lecturer')),
              const PopupMenuItem(value: 'departmentAdmin', child: Text('→ Dept Admin')),
              const PopupMenuItem(value: 'schoolAdmin',     child: Text('→ School Admin')),
            ],
          ),
      ]),
    );
  }
}

// ── SEATS tab ─────────────────────────────────────────────

class _SeatsTab extends StatefulWidget {
  final AppUser user;
  const _SeatsTab({required this.user});
  @override State<_SeatsTab> createState() => _SeatsTabState();
}

class _SeatsTabState extends State<_SeatsTab> with SingleTickerProviderStateMixin {
  late TabController _tc;
  String _search = '';

  static const _classes = [
    'Form 1','Form 2','Form 3','Form 4','Form 5A','Form 5B',
    'Lower Sixth Science','Lower Sixth Arts',
    'Upper Sixth Science','Upper Sixth Arts',
  ];

  @override
  void initState() { super.initState(); _tc = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  String get _sid => widget.user.schoolId ?? '';

  List<StudentAccount> _filter(List<StudentAccount> list) {
    if (_search.isEmpty) return list;
    return list.where((a) =>
      (a.studentName?.toLowerCase().contains(_search.toLowerCase()) ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: C.primary,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(children: [
          TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search seats…', hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              fillColor: Colors.white.withValues(alpha: .1), filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          TabBar(controller: _tc,
            labelColor: Colors.white, unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white, dividerColor: Colors.transparent,
            isScrollable: true,
            tabs: const [Tab(text:'AVAILABLE'),Tab(text:'ASSIGNED'),
              Tab(text:'ACTIVE'),Tab(text:'SUSPENDED')]),
        ]),
      ),
      Expanded(
        child: StreamBuilder<List<StudentAccount>>(
          stream: AccountsRepository.instance.watchAccounts(_sid),
          builder: (ctx, snap) {
            final all = snap.data ?? [];
            return Stack(children: [
              TabBarView(controller: _tc, children: [
                _SeatList(seats: _filter(all.where((a) => a.status == AccountStatus.unassigned).toList()), sid: _sid),
                _SeatList(seats: _filter(all.where((a) => a.status == AccountStatus.assigned).toList()), sid: _sid),
                _SeatList(seats: _filter(all.where((a) => a.status == AccountStatus.active).toList()), sid: _sid),
                _SeatList(seats: _filter(all.where((a) => a.status == AccountStatus.suspended).toList()), sid: _sid),
              ]),
              Positioned(bottom: 16, right: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'seats_fab',
                  backgroundColor: C.gold, foregroundColor: C.navy,
                  icon: const Icon(Icons.add),
                  label: Text('Create Seats', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  onPressed: () => _showCreate(context),
                )),
            ]);
          },
        ),
      ),
    ]);
  }

  void _showCreate(BuildContext ctx) {
    String cls = _classes.first;
    int cnt = 1;
    bool saving = false;
    showDialog(context: ctx, builder: (_) => StatefulBuilder(
      builder: (dCtx, setD) => AlertDialog(
        title: Text('Create Seats', style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: cls, decoration: const InputDecoration(labelText: 'Class Level'),
            items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setD(() => cls = v ?? cls),
          ),
          const SizedBox(height: 14),
          TextField(
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Number of seats'),
            onChanged: (v) => cnt = int.tryParse(v) ?? 1,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: saving ? null : () async {
              setD(() => saving = true);
              final r = await AccountsRepository.instance.createSeat(
                  schoolId: _sid, classLevel: cls, count: cnt);
              if (!dCtx.mounted) return;
              Navigator.pop(dCtx);
              if (r is Success && ctx.mounted) showToast(ctx, '✅ $cnt seat(s) created for $cls');
            },
            child: saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create')),
        ],
      ),
    ));
  }
}

class _SeatList extends StatelessWidget {
  final List<StudentAccount> seats;
  final String sid;
  const _SeatList({required this.seats, required this.sid});

  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) {
      return Center(
          child: Text('No seats', style: GoogleFonts.inter(color: C.muted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: seats.length,
      itemBuilder: (_, i) => _SeatTile(seat: seats[i], sid: sid),
    );
  }
}

class _SeatTile extends StatelessWidget {
  final StudentAccount seat;
  final String sid;
  const _SeatTile({required this.seat, required this.sid});

  Color get _sc {
    switch (seat.status) {
      case AccountStatus.unassigned: return C.muted;
      case AccountStatus.assigned:   return C.blu;
      case AccountStatus.active:     return C.grn;
      case AccountStatus.suspended:  return C.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.surf,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bdr)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: _sc.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(
            seat.studentName?.isNotEmpty == true ? seat.studentName![0].toUpperCase() : '?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _sc)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(seat.studentName ?? 'Unassigned Seat',
              style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700)),
          Text('${seat.classLevel} · ${seat.status.name}',
              style: GoogleFonts.inter(fontSize: 11, color: C.muted)),
          if (seat.status == AccountStatus.assigned && seat.tempPassword.isNotEmpty)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: seat.tempPassword));
                showToast(context, 'Temp password copied');
              },
              child: Text('Tap to copy temp password',
                  style: GoogleFonts.inter(fontSize: 11, color: C.blu, fontWeight: FontWeight.w600))),
        ])),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: C.muted, size: 18),
          onSelected: (val) async {
            if (val == 'suspend')   await AccountsRepository.instance.suspend(sid, seat.accountId);
            if (val == 'unsuspend') await AccountsRepository.instance.unsuspend(sid, seat.accountId);
            if (context.mounted) showToast(context, 'Done');
          },
          itemBuilder: (_) => [
            if (seat.status != AccountStatus.suspended && seat.status != AccountStatus.unassigned)
              const PopupMenuItem(value: 'suspend', child: Text('Suspend')),
            if (seat.status == AccountStatus.suspended)
              const PopupMenuItem(value: 'unsuspend', child: Text('Reactivate')),
          ],
        ),
      ]),
    );
  }
}

// ── PLATFORM tab (superAdmin) ─────────────────────────────

class _PlatformTab extends StatelessWidget {
  final AppUser user;
  const _PlatformTab({required this.user});

  @override
  Widget build(BuildContext context) {
    final inst = context.watch<InstitutionProvider>().effectiveInstitution;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Institution Settings',
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _Row('School Name', inst.schoolName),
        _Row('School Code', inst.schoolCode),
        _Row('Country', inst.country ?? '—'),
        _Row('Contact', inst.contactEmail ?? '—'),
        _Row('Website', inst.websiteUrl ?? '—'),
        const SizedBox(height: 20),
        Text('Enabled Features',
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: inst.enabledFeatures.map((f) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: C.primaryBg, borderRadius: BorderRadius.circular(20)),
            child: Text(f.name,
                style: GoogleFonts.inter(fontSize: 12, color: C.primary, fontWeight: FontWeight.w600)),
          )).toList()),
        const SizedBox(height: 24),
        Text('Home Screen',
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => HeroSlideManagerPage(createdByUid: user.id))),
          icon: const Icon(Icons.image_outlined),
          label: const Text('Manage Home Banners'),
        ),
        const SizedBox(height: 24),
        Text('Schools',
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const CreateInstitutionPage())),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Register a School'),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.read<InstitutionProvider>().clear(),
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Switch Institution')),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: C.surf,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: C.bdr)),
      child: Row(children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: C.txt2)),
        const Spacer(),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: C.txt)),
      ]),
    );
  }
}

// lib/features/onboarding/school_admin_page.dart
// Staff side of architecture brief items 4-6: registering a school
// (superAdmin only — platform-level, same tier as this codebase's
// existing "Register a School" concept) and issuing that school's
// role-coded voucher codes (schoolAdmin of that school, or superAdmin for
// any school). Without this page the redemption flow in
// school_access_page.dart has nothing to redeem — codes have to come
// from somewhere real, not be typed in by hand into Firestore.

import 'package:flutter/material.dart';
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

  Future<void> _issue() async {
    final school = _selectedSchool;
    if (school == null) return;
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
    );
    if (!mounted) return;
    setState(() => _issuing = false);
    switch (result) {
      case Success(:final value):
        setState(() => _issued = value);
      case Failure(:final message):
        setState(() => _error = message);
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
              items: SchoolRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
              onChanged: (v) => setState(() => _role = v ?? SchoolRole.student),
            ),
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
              Text('Generated — write these down or print them now:',
                  style: AppText.bodySm.copyWith(color: ac.txt2)),
              const SizedBox(height: 8),
              ..._issued.map((v) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: ac.grnBg, borderRadius: BorderRadius.circular(Rad.sm)),
                    child: Text(v.code, style: AppText.body.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1)),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

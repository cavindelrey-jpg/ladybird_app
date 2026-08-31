// lib/features/onboarding/school_access_page.dart
// Architecture brief items 2, 5, 6: the ONLY way a signed-in Academia
// account gains access to a school's app (School Connect/Timetable/Marks)
// is by redeeming a school-specific voucher here. Reachable from Profile
// whenever `!user.isSchoolMember`. Deliberately a separate page/repository
// from redeem_voucher_page.dart (Premium entitlement) — see
// school_access_repository.dart's file header for why these are not the
// same system.
//
// Folds item 19's "which class are you in" into this same step for
// student codes (an optional field here, not a second wall shown right
// after) rather than granting access and then immediately blocking
// Timetable with a separate "set your class" screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/school_voucher.dart';
import '../../repositories/school_access_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';

class SchoolAccessPage extends StatefulWidget {
  final AppUser user;
  const SchoolAccessPage({super.key, required this.user});

  @override
  State<SchoolAccessPage> createState() => _SchoolAccessPageState();
}

class _SchoolAccessPageState extends State<SchoolAccessPage> {
  final _codeCtrl = TextEditingController();
  String? _classLevel;
  bool _redeeming = false;
  String? _error;
  SchoolRedemptionOutcome? _outcome;

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

    final result = await SchoolAccessRepository.instance.redeemSchoolVoucher(
      userId: widget.user.id,
      rawCode: _codeCtrl.text,
      classLevel: _classLevel,
    );

    if (!mounted) return;
    setState(() => _redeeming = false);

    switch (result) {
      case Success(:final value):
        setState(() => _outcome = value);
        _codeCtrl.clear();
        showToast(context, 'Connected to ${value.school.name}');
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
        backgroundColor: ac.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
        title: Text('Connect Your School', style: AppText.title),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Enter the school code your school gave you. It identifies '
              'both your school and your role (student, parent, teacher, '
              'class master, or administrator) — you\'ll only see what\'s '
              'relevant to you.',
              style: AppText.bodySm.copyWith(color: ac.txt2),
            ),
            const SizedBox(height: 20),

            Text('School code', style: AppText.title.copyWith(fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _codeCtrl,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              style: AppText.body.copyWith(fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'GHS-XXXXXXXX',
                hintStyle: AppText.body.copyWith(fontSize: 20, letterSpacing: 2, color: ac.muted),
                filled: true,
                fillColor: ac.surf3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            Text('Class / Level (optional — students only)', style: AppText.title.copyWith(fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _classLevel,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: ac.surf3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm), borderSide: BorderSide.none),
                hintText: 'Select your class',
              ),
              items: EducationLevels.all
                  .map((lvl) => DropdownMenuItem(value: lvl, child: Text(lvl, style: AppText.body.copyWith(fontSize: 14))))
                  .toList(),
              onChanged: (v) => setState(() => _classLevel = v),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: ac.redBg, borderRadius: BorderRadius.circular(Rad.sm)),
                child: Text(_error!, style: AppText.bodySm.copyWith(color: ac.red)),
              ),
            ],

            const SizedBox(height: 24),
            PrimaryBtn(label: 'Connect', loading: _redeeming, onTap: _redeem),

            if (_outcome != null) ...[
              const SizedBox(height: 24),
              _SuccessCard(outcome: _outcome!),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  final SchoolRedemptionOutcome outcome;
  const _SuccessCard({required this.outcome});

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
          Icon(Icons.check_circle_rounded, size: 20, color: ac.grn),
          const SizedBox(width: 8),
          Text('Connected', style: AppText.title.copyWith(fontSize: 15, color: ac.grn)),
        ]),
        const SizedBox(height: 10),
        Text(
          'You\'re now connected to ${outcome.school.name} as a ${outcome.role.label}. '
          'School Connect, Timetable, and Marks are ready — no further setup needed.',
          style: AppText.bodySm,
        ),
      ]),
    );
  }
}

Future<void> openSchoolAccess(BuildContext context, AppUser user) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => SchoolAccessPage(user: user)));

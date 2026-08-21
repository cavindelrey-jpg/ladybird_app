// lib/widgets/student_header_card.dart
// Shared identity header for the official-school surfaces — Marks, the
// school's Class Timetable, and School Connect — so the three read as
// one platform instead of three separately designed screens (same
// avatar/name/role treatment, same info-row layout, same card style).
//
// Deliberately built only from fields AppUser/Institution actually
// store. There is no matriculation-number or "class master" field
// anywhere in this codebase's data model, so this card doesn't invent
// one — same standard school_management_page.dart already holds itself
// to ("Student follow-up, performance tracking and reporting are not
// built yet — they will appear here once they exist" rather than a tile
// that opens a fabricated dashboard).

import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/institution.dart';
import '../repositories/institution_repository.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import 'widgets.dart';

class SchoolStudentHeaderCard extends StatelessWidget {
  final AppUser user;
  const SchoolStudentHeaderCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final sid = user.schoolId ?? '';
    final tierIsPremium = user.entitlement.isActive;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.lg),
        border: Border.all(color: ac.bdr),
        boxShadow: Shad.sm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          UserAvatar(initials: user.initials, radius: 26, photoUrl: user.photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    user.name.isEmpty ? 'Student' : user.name,
                    style: AppText.title.copyWith(fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(label: user.roleLabel, color: ac.primary),
              ]),
              const SizedBox(height: 4),
              StreamBuilder<Institution?>(
                stream: sid.isEmpty ? null : InstitutionRepository.instance.watch(sid),
                builder: (context, snap) {
                  final schoolName = snap.data?.schoolName;
                  return Text(
                    schoolName ?? (sid.isEmpty ? 'No school linked' : 'Loading school…'),
                    style: AppText.bodySm,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Divider(height: 1, color: ac.bdr2),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _InfoItem(
              label: 'Class',
              value: user.classLevel.isEmpty ? '—' : user.classLevel,
            ),
          ),
          Expanded(
            child: _InfoItem(
              label: 'Account',
              value: user.entitlementLabel,
              valueColor: tierIsPremium ? ac.gold : null,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoItem({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: AppText.label.copyWith(fontSize: 10, color: ac.muted, letterSpacing: .4)),
      const SizedBox(height: 2),
      Text(value,
          style: AppText.subtitle.copyWith(fontSize: 13, color: valueColor ?? ac.txt),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]);
  }
}

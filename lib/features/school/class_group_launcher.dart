// lib/features/school/class_group_launcher.dart
// "Class Group" entry point. A class master (or school admin) creates the
// group for their class in one tap -- every student in the class is
// enrolled server-side by create_class_group() -- and later taps open it.
// Students open their own class's group, or are told it isn't set up yet.
// The chat itself is the existing club chat (ClubChatPage).

import 'package:flutter/material.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/club.dart';
import '../../repositories/club_repository.dart';
import '../../widgets/widgets.dart' show showToast;
import '../clubs/clubs_page.dart' show ClubChatPage;

bool canOpenClassGroup(AppUser u) =>
    u.isSchoolMember &&
    ((u.isStudent && !u.isParent && u.classLevel.isNotEmpty) ||
        (u.classMasterOfClass ?? '').isNotEmpty ||
        u.hasMinRole(UserRole.schoolAdmin));

Future<void> openClassGroup(BuildContext context, AppUser user) async {
  final schoolId = user.schoolId ?? '';
  final isStaff = !user.isStudent;
  String? cls = isStaff ? user.classMasterOfClass : user.classLevel;
  if ((cls ?? '').isEmpty && user.hasMinRole(UserRole.schoolAdmin)) {
    cls = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Which class?'),
        children: [
          for (final c in const ['Form 1', 'Form 2', 'Form 3', 'Form 4', 'Form 5', 'Lower Sixth', 'Upper Sixth'])
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, c), child: Text(c)),
        ],
      ),
    );
  }
  if (cls == null || cls.isEmpty || !context.mounted) return;

  final existing = await ClubRepository.instance.classGroup(schoolId, cls);
  if (!context.mounted) return;
  Club? club;
  switch (existing) {
    case Failure(:final message):
      showToast(context, message, isError: true);
      return;
    case Success(:final value):
      club = value;
  }

  if (club == null) {
    if (!isStaff) {
      showToast(context, 'Your class master hasn\'t created the $cls group yet.');
      return;
    }
    final create = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Create the $cls group?'),
        content: Text('Every student currently in $cls will be added. '
            'You can remove members or add new arrivals later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create group')),
        ],
      ),
    );
    if (create != true || !context.mounted) return;
    final res = await ClubRepository.instance.createClassGroup(cls);
    if (!context.mounted) return;
    switch (res) {
      case Failure(:final message):
        showToast(context, message, isError: true);
        return;
      case Success(:final value):
        club = value;
        showToast(context, '${value.name} created with ${value.memberCount - 1} students.');
    }
  } else if (isStaff) {
    // Pick up students who joined the class since the group was created.
    final synced = await ClubRepository.instance.syncClassGroup(club.id);
    if (context.mounted && synced is Success<int> && synced.value > 0) {
      showToast(context, 'Added ${synced.value} new student${synced.value == 1 ? '' : 's'} to the group.');
    }
  }
  if (!context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubChatPage(club: club!, user: user)));
}

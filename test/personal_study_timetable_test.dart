import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academia_app/models/app_user.dart';
import 'package:academia_app/models/personal_study_slot.dart';
import 'package:academia_app/repositories/personal_study_repository.dart';
import 'package:academia_app/features/timetable/personal_study_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const testUser = AppUser(id: 'test-student-1', name: 'Alice Student');

  group('PersonalStudySlot Model', () {
    test('serializes and deserializes correctly', () {
      const slot = PersonalStudySlot(
        id: 'slot-1',
        userId: 'test-student-1',
        dayOfWeek: 1,
        startTime: '10:00',
        endTime: '16:00',
        activity: 'Revision / laboratory work',
        subject: 'Chemistry',
      );

      final json = slot.toJson();
      final parsed = PersonalStudySlot.fromJson(json);

      expect(parsed.id, 'slot-1');
      expect(parsed.userId, 'test-student-1');
      expect(parsed.dayOfWeek, 1);
      expect(parsed.startTime, '10:00');
      expect(parsed.endTime, '16:00');
      expect(parsed.activity, 'Revision / laboratory work');
      expect(parsed.subject, 'Chemistry');
      expect(parsed.dayName, 'Mon');
    });
  });

  group('PersonalStudyRepository Offline First & Local Cache', () {
    test('add, watchAll, update, delete work with 0ms local persistence', () async {
      final repo = PersonalStudyRepository.instance;

      const slot = PersonalStudySlot(
        id: 'slot-chem',
        userId: 'test-student-1',
        dayOfWeek: 2,
        startTime: '10:00',
        endTime: '16:00',
        activity: 'Revision / laboratory work',
        subject: 'Chemistry',
      );

      // Add slot
      await repo.add(slot);

      // Stream should emit the saved slot
      final slots = await repo.watchAll('test-student-1').first;
      expect(slots.length, 1);
      expect(slots.first.subject, 'Chemistry');
      expect(slots.first.startTime, '10:00');
      expect(slots.first.endTime, '16:00');
      expect(slots.first.activity, 'Revision / laboratory work');

      // Update slot
      const updatedSlot = PersonalStudySlot(
        id: 'slot-chem',
        userId: 'test-student-1',
        dayOfWeek: 2,
        startTime: '11:00',
        endTime: '15:00',
        activity: 'Laboratory work & practice',
        subject: 'Chemistry',
      );
      await repo.update(updatedSlot);

      final updatedSlots = await repo.watchAll('test-student-1').first;
      expect(updatedSlots.length, 1);
      expect(updatedSlots.first.startTime, '11:00');
      expect(updatedSlots.first.endTime, '15:00');
      expect(updatedSlots.first.activity, 'Laboratory work & practice');

      // Delete slot
      await repo.delete('test-student-1', 'slot-chem');
      final remainingSlots = await repo.watchAll('test-student-1').first;
      expect(remainingSlots, isEmpty);
    });
  });

  group('PersonalStudyPage Widget Flow', () {
    testWidgets('shows empty state, opens creation sheet, validates and saves timetable entry',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        const MaterialApp(
          home: PersonalStudyPage(user: testUser),
        ),
      );
      await tester.pumpAndSettle();

      // Verify empty state is displayed
      expect(find.text('No study sessions planned yet'), findsOneWidget);
      expect(find.text('Create Personal Timetable'), findsOneWidget); // Centered button
      expect(find.text('Add to Personal Timetable'), findsOneWidget); // FAB

      // Tap the Create Personal Timetable button
      await tester.tap(find.text('Create Personal Timetable'));
      await tester.pumpAndSettle();

      // Verify sheet is open with title
      expect(find.text('New Timetable Entry'), findsOneWidget);

      // Verify primary action buttons exist:
      // 1. Header save button
      expect(find.byKey(const Key('header_save_btn')), findsOneWidget);
      // 2. Inline form save button
      expect(find.byKey(const Key('inline_save_timetable_entry_btn')), findsOneWidget);
      // 3. Sticky footer save button
      expect(find.byKey(const Key('sticky_save_timetable_entry_btn')), findsOneWidget);

      // Validation test: attempt to save with empty fields
      await tester.tap(find.byKey(const Key('sticky_save_timetable_entry_btn')));
      await tester.pumpAndSettle();
      // Should show validation toast and NOT close the modal
      expect(find.text('New Timetable Entry'), findsOneWidget);

      // Enter Subject: Chemistry (using the quick suggestion chip)
      final chemistryChip = find.text('Chemistry');
      expect(chemistryChip, findsOneWidget);
      await tester.tap(chemistryChip);
      await tester.pump();

      // Enter Personal remark: Revision / laboratory work
      final remarkField = find.byKey(const Key('remark_field'));
      expect(remarkField, findsOneWidget);
      await tester.enterText(remarkField, 'Revision / laboratory work');
      await tester.pump();

      // Tap the primary action "Save Timetable Entry"
      await tester.tap(find.byKey(const Key('sticky_save_timetable_entry_btn')));
      await tester.pumpAndSettle();

      // The sheet should close, and the newly created entry should appear immediately
      expect(find.text('New Timetable Entry'), findsNothing);
      expect(find.text('Chemistry'), findsOneWidget);
      expect(find.textContaining('Revision / laboratory work'), findsOneWidget);
      expect(find.textContaining('10:00 – 16:00'), findsOneWidget);

      // Tap the created card to open the edit sheet
      await tester.tap(find.text('Chemistry'));
      await tester.pumpAndSettle();

      // Verify edit sheet opened with existing data
      expect(find.text('Edit Timetable Entry'), findsOneWidget);
      expect(find.text('Save Changes'), findsNWidgets(2)); // inline and sticky
      expect(find.byKey(const Key('delete_timetable_entry_btn')), findsOneWidget);

      // Update the remark
      await tester.enterText(find.byKey(const Key('remark_field')), 'Revision / laboratory work & practice');
      await tester.pump();

      // Save changes
      await tester.tap(find.byKey(const Key('sticky_save_timetable_entry_btn')));
      await tester.pumpAndSettle();

      // Check updated content appears immediately
      expect(find.text('Edit Timetable Entry'), findsNothing);
      expect(find.textContaining('Revision / laboratory work & practice'), findsOneWidget);

      // Tap again to delete
      await tester.tap(find.text('Chemistry'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete_timetable_entry_btn')));
      await tester.pumpAndSettle();

      // Empty state should be back
      expect(find.text('No study sessions planned yet'), findsOneWidget);
    });

    testWidgets('creation form renders cleanly without overflow on 320dp and 360dp mobile screens',
        (tester) async {
      for (final width in [320.0, 360.0]) {
        await tester.binding.setSurfaceSize(Size(width, 640.0));

        await tester.pumpWidget(
          const MaterialApp(
            home: PersonalStudyPage(user: testUser),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Add Session from AppBar
        await tester.tap(find.byKey(const Key('add_session_appbar_btn')));
        await tester.pumpAndSettle();

        // Check Save Timetable Entry button is visible and tappable
        expect(find.byKey(const Key('sticky_save_timetable_entry_btn')), findsOneWidget);
        expect(find.byKey(const Key('header_save_btn')), findsOneWidget);

        // Close sheet
        await tester.tap(find.byTooltip('Cancel'));
        await tester.pumpAndSettle();
      }
    });
  });
}

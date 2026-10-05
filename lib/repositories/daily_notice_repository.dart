// lib/repositories/daily_notice_repository.dart
// Production-ready repository for Daily Academic Notices and automated
// next-day timetable notifications. Supports offline SQLite caching.

import 'dart:async';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/local_database.dart';
import '../models/daily_notice.dart';
import '../models/school_timetable_slot.dart';
import '../core/realtime_tolerant.dart';

class DailyNoticeRepository {
  DailyNoticeRepository._();
  static final DailyNoticeRepository instance = DailyNoticeRepository._();

  final SupabaseClient _db = Supabase.instance.client;

  Stream<List<DailyNotice>> watchForClass(String schoolId, String classLevel) {
    if (schoolId.isEmpty) return Stream.value(const []);

    final stream = _db
        .from('daily_notices')
        .stream(primaryKey: ['id'])
        .eq('school_id', schoolId)
        .order('created_at', ascending: false)
        .realtimeTolerant();

    return stream.asyncMap((rows) async {
      try {
        final list = rows
            .map(DailyNotice.fromJson)
            .where((n) => classLevel.isEmpty || n.classLevel == classLevel || n.classLevel.toLowerCase() == 'all')
            .toList();

        for (final item in list) {
          await LocalDatabase.instance.cacheData('daily_notices', item.id, item.toJson());
        }
        return list;
      } catch (_) {
        return _getLocalNotices(schoolId, classLevel);
      }
    }).handleError((_) => _getLocalNotices(schoolId, classLevel));
  }

  Future<List<DailyNotice>> _getLocalNotices(String schoolId, String classLevel) async {
    try {
      final cached = await LocalDatabase.instance.getCachedCollection('daily_notices');
      return cached
          .map(DailyNotice.fromJson)
          .where((n) => n.schoolId == schoolId && (classLevel.isEmpty || n.classLevel == classLevel))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> submitNotice(DailyNotice notice) async {
    final json = notice.toJson();
    await LocalDatabase.instance.cacheData('daily_notices', notice.id, json);

    try {
      await _db.from('daily_notices').upsert(json, onConflict: 'id');
      return true;
    } catch (e) {
      await LocalDatabase.instance.queueSyncAction('upsert', 'daily_notices', notice.id, json);
      return false;
    }
  }

  Future<bool> deleteNotice(String id) async {
    await LocalDatabase.instance.deleteCachedData('daily_notices', id);
    try {
      await _db.from('daily_notices').delete().eq('id', id);
    } catch (_) {
      await LocalDatabase.instance.queueSyncAction('delete', 'daily_notices', id, {});
    }
    return true;
  }

  /// Automatically generates "Tomorrow's Programme" notice using the stored timetable.
  /// Deduplicates so it only generates once per date.
  Future<DailyNotice?> generateTomorrowsProgramme({
    required String schoolId,
    required String classLevel,
    DateTime? targetDate,
  }) async {
    final now = DateTime.now();
    // Default to tomorrow
    final tomorrow = targetDate ?? now.add(const Duration(days: 1));
    final tomorrowWeekday = tomorrow.weekday; // 1=Mon...7=Sun
    final dateKey = DateFormat('yyyy-MM-dd').format(tomorrow);
    final noticeId = 'prog_${schoolId}_${classLevel}_$dateKey';

    // Check if notice already exists in local DB or remote
    final cached = await LocalDatabase.instance.getCachedData('daily_notices', noticeId);
    if (cached != null) {
      return DailyNotice.fromJson(cached);
    }

    // Fetch timetable slots for this class
    try {
      final rows = await _db
          .from('school_timetable_slots')
          .select()
          .eq('school_id', schoolId)
          .eq('class_level', classLevel)
          .eq('day_of_week', tomorrowWeekday)
          .order('start_time', ascending: true);

      final slots = rows.map((r) => SchoolTimetableSlot(
            id: r['id']?.toString() ?? '',
            schoolId: r['school_id']?.toString() ?? '',
            classLevel: r['class_level']?.toString() ?? '',
            dayOfWeek: (r['day_of_week'] as num?)?.toInt() ?? 1,
            startTime: r['start_time']?.toString() ?? '',
            endTime: r['end_time']?.toString() ?? '',
            subject: r['subject']?.toString() ?? '',
            teacherName: r['teacher_name']?.toString() ?? '',
            room: r['room']?.toString(),
          )).toList();

      if (slots.isEmpty) {
        // Weekend or no scheduled periods
        final dayName = SchoolTimetableSlot.dayNames[tomorrowWeekday];
        final notice = DailyNotice(
          id: noticeId,
          schoolId: schoolId,
          classLevel: classLevel,
          subject: 'Timetable',
          teacherId: 'system',
          teacherName: 'School Management System',
          teacherRole: 'Automated Schedule',
          noticeType: NoticeType.timetableProgramme,
          title: "Tomorrow's Programme — $dayName ($dateKey)",
          content: 'No scheduled timetable periods for tomorrow ($dayName). Enjoy your personal study time!',
          date: tomorrow,
          isSystemGenerated: true,
          createdAt: DateTime.now(),
        );
        await submitNotice(notice);
        return notice;
      }

      final dayName = SchoolTimetableSlot.dayNames[tomorrowWeekday];
      final buffer = StringBuffer();
      buffer.writeln("Official Timetable for tomorrow, $dayName ($dateKey):\n");

      for (int i = 0; i < slots.length; i++) {
        final s = slots[i];
        final roomText = (s.room != null && s.room!.isNotEmpty) ? ' [Room: ${s.room}]' : '';
        buffer.writeln('${i + 1}. ${s.startTime} - ${s.endTime}: ${s.subject}');
        buffer.writeln('   Teacher: ${s.teacherName}$roomText\n');
      }

      final notice = DailyNotice(
        id: noticeId,
        schoolId: schoolId,
        classLevel: classLevel,
        subject: 'Timetable',
        teacherId: 'system',
        teacherName: 'School Management System',
        teacherRole: 'Automated Schedule',
        noticeType: NoticeType.timetableProgramme,
        title: "Tomorrow's Programme — $dayName ($dateKey)",
        content: buffer.toString().trim(),
        date: tomorrow,
        isSystemGenerated: true,
        createdAt: DateTime.now(),
      );

      await submitNotice(notice);
      return notice;
    } catch (_) {
      return null;
    }
  }
}

// lib/models/models.dart
export 'academic_content.dart';
export 'app_user.dart';
export 'entitlement.dart';
export 'purchase.dart';
export 'voucher.dart';
export 'announcement.dart';
export 'club.dart';
export 'personal_study_slot.dart';
export 'hero_slide.dart';
export 'magazine_article.dart';
export 'magazine_gallery_post.dart';
export 'magazine_video_post.dart';
export 'daily_challenge.dart';
export 'xp_transaction.dart';
export 'test.dart';
export 'test_attempt.dart';

// The official-school models — mark.dart/timetable_slot.dart/
// calendar_event.dart/institution.dart were previously only reachable by
// importing each file directly; several existing pages already import
// this barrel and use their types (marks_page.dart's SubjectMark/
// SequenceReport, timetable_page.dart's TimetableSlot, calendar_page.dart's
// CalendarEvent) so this closes a gap in the barrel rather than changing
// what those pages already relied on.
export 'mark.dart';
export 'timetable_slot.dart';
export 'calendar_event.dart';
export 'institution.dart';
export 'school_request.dart';

// Course/Assignment/AttendanceRecord/StudentAccount/LibraryItem files
// already existed with their classes fully defined but were never wired
// into this barrel -- every features/ and repositories/ file importing
// '../models/models.dart' (the barrel, not the file directly) saw them
// as undefined types. This was the root cause of ~200 flutter analyze
// errors across admin/assignments/attendance/courses/library/onboarding.
export 'course.dart';
export 'assignment.dart';
export 'attendance_record.dart';
export 'student_account.dart';
export 'library_item.dart';

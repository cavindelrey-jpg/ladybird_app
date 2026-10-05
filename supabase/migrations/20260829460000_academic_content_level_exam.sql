-- ============================================================================
-- greenhills_app/ladybird_app's Library upload form adds Level/Class and
-- Exam Board/Series classification on top of the shared academic_content
-- table (see models/academic_content.dart's kAcademicLevels/kExamBoards).
-- Same shared table as academia-cameroon; blank/unused there.
-- ============================================================================

alter table public.academic_content
  add column if not exists level text not null default '',
  add column if not exists exam_board text not null default '',
  add column if not exists year integer;

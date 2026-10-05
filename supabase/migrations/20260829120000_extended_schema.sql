-- ============================================================================
-- Academia Cameroon — extended schema, second pass.
--
-- schema.sql (20260828060000) covered exactly 7 tables per the original,
-- narrower request. This migration adds the rest of MIGRATION_INVENTORY.md's
-- collections that carry real (or plausible near-term) data, per the
-- follow-up request to migrate everything, not just the original 7 tables.
--
-- Explicitly NOT migrated here, on purpose:
--   - academic_content, and its children saves/readPositions — confirmed
--     dead code (lib/repositories/academic_content_repository.dart is never
--     instantiated anywhere; library_items already covers the live Library
--     feature). Migrating a dead table's data would just be noise.
--   - schools, marks — legacy/未used-in-current-data paths superseded by
--     institutions + student_accounts for the school concept this app
--     actually exercises today (both had 0 documents in the Firestore
--     export). Revisit if marks entry ships for real.
--   - users/{uid}/settings/notifications (a singleton preferences doc,
--     not a list) — a different subcollection name ("settings") that
--     wasn't part of the original SUBCOLLECTION_GROUPS export list and
--     has 0 confirmed rows; flagging rather than silently guessing at it.
--
-- RLS is enabled on every table below with the same public-read/
-- role-gated-write pattern already established in
-- 20260828060100_rls_policies.sql, reusing has_min_role()/current_role()
-- from that migration rather than redefining them.
-- ============================================================================

-- ============================================================================
-- Enums
-- ============================================================================

create type question_type as enum ('mcq', 'structured', 'long_form');
create type test_difficulty as enum ('easy', 'medium', 'hard');
create type attempt_status as enum ('submitted', 'graded');
create type club_role as enum ('visitor', 'member', 'moderator', 'admin');
create type club_join_request_status as enum ('pending', 'approved', 'declined');
create type friend_request_status as enum ('pending', 'accepted', 'declined');
create type xp_transaction_type as enum ('earn', 'spend');
create type xp_source as enum (
  'mcq', 'structural', 'ac', 'paper_unlock', 'magazine_read',
  'test_completion', 'streak_daily', 'streak_milestone'
);
create type hero_destination as enum (
  'library', 'clubs', 'past_questions', 'magazine', 'courses', 'custom'
);
create type notification_type as enum (
  'announcement', 'comment', 'reply', 'article_published', 'system'
);
create type unlocked_via as enum ('xp', 'paid_subscription');

-- ============================================================================
-- Testing (lib/models/test.dart, test_attempt.dart)
-- Questions/responses stay jsonb, matching Firestore's own embedded-array
-- design (see test.dart's header comment on why questions aren't a
-- subcollection) — no reason to normalize what the source system itself
-- deliberately denormalized for single-read performance.
-- ============================================================================

create table if not exists public.tests (
  id              uuid primary key default gen_random_uuid(),
  subject         text not null,
  title           text not null default 'Untitled Test',
  description     text,
  difficulty      test_difficulty not null default 'medium',
  questions       jsonb not null default '[]'::jsonb,
  created_by      uuid references public.users (id) on delete set null,
  created_by_name text,
  -- Null = open to every student studying this subject (see test.dart:7-8).
  institution_id  uuid references public.institutions (id) on delete set null,
  published       boolean not null default true,
  created_at      timestamptz not null default now()
);

create index if not exists tests_subject_idx on public.tests (subject);
create index if not exists tests_institution_id_idx on public.tests (institution_id);

alter table public.tests enable row level security;
create policy "tests_select_authenticated" on public.tests for select using (auth.uid() is not null);
create policy "tests_write_lecturer" on public.tests for all
  using (public.has_min_role('lecturer')) with check (public.has_min_role('lecturer'));

create table if not exists public.test_attempts (
  id                     uuid primary key default gen_random_uuid(),
  test_id                uuid references public.tests (id) on delete set null,
  test_title             text,
  subject                text,
  difficulty             test_difficulty not null default 'medium',
  user_id                uuid references public.users (id) on delete set null,
  user_name              text,
  responses              jsonb not null default '[]'::jsonb,
  total_possible_points  integer not null default 0,
  status                 attempt_status not null default 'submitted',
  total_xp_awarded       integer not null default 0,
  submitted_at           timestamptz not null default now(),
  graded_at              timestamptz
);

create index if not exists test_attempts_user_id_idx on public.test_attempts (user_id);
create index if not exists test_attempts_test_id_idx on public.test_attempts (test_id);

alter table public.test_attempts enable row level security;
create policy "test_attempts_select_own_or_lecturer" on public.test_attempts for select
  using (user_id = auth.uid() or public.has_min_role('lecturer'));
create policy "test_attempts_insert_own" on public.test_attempts for insert
  with check (user_id = auth.uid());
create policy "test_attempts_update_lecturer" on public.test_attempts for update
  using (public.has_min_role('lecturer')) with check (public.has_min_role('lecturer'));

-- ============================================================================
-- Clubs (lib/models/club.dart)
-- ============================================================================

create table if not exists public.clubs (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,
  emoji              text not null default '🎓',
  description        text,
  moderator_id       uuid references public.users (id) on delete set null,
  moderator_name     text,
  category           text not null default 'General',
  banner_url         text,
  member_count       integer not null default 0,
  institution_id     uuid references public.institutions (id) on delete set null,
  requires_approval  boolean not null default false,
  created_at         timestamptz not null default now()
);

alter table public.clubs enable row level security;
create policy "clubs_select_authenticated" on public.clubs for select using (auth.uid() is not null);
create policy "clubs_insert_authenticated" on public.clubs for insert with check (auth.uid() is not null);
create policy "clubs_update_moderator" on public.clubs for update
  using (moderator_id = auth.uid() or public.has_min_role('school_admin'))
  with check (moderator_id = auth.uid() or public.has_min_role('school_admin'));
create policy "clubs_delete_moderator" on public.clubs for delete
  using (moderator_id = auth.uid() or public.has_min_role('school_admin'));

create table if not exists public.club_members (
  club_id    uuid not null references public.clubs (id) on delete cascade,
  user_id    uuid not null references public.users (id) on delete cascade,
  name       text,
  photo_url  text,
  role       club_role not null default 'member',
  joined_at  timestamptz not null default now(),
  primary key (club_id, user_id)
);

alter table public.club_members enable row level security;
create policy "club_members_select_authenticated" on public.club_members for select using (auth.uid() is not null);
create policy "club_members_insert_self" on public.club_members for insert with check (user_id = auth.uid());
create policy "club_members_delete_self_or_moderator" on public.club_members for delete
  using (
    user_id = auth.uid()
    or exists (select 1 from public.clubs c where c.id = club_id and c.moderator_id = auth.uid())
    or public.has_min_role('school_admin')
  );

create table if not exists public.club_join_requests (
  id              uuid primary key default gen_random_uuid(),
  club_id         uuid not null references public.clubs (id) on delete cascade,
  club_name       text,
  user_id         uuid references public.users (id) on delete set null,
  user_name       text,
  user_photo_url  text,
  status          club_join_request_status not null default 'pending',
  created_at      timestamptz not null default now()
);

create index if not exists club_join_requests_club_id_idx on public.club_join_requests (club_id);

alter table public.club_join_requests enable row level security;
create policy "club_join_requests_select_own_or_moderator" on public.club_join_requests for select
  using (
    user_id = auth.uid()
    or exists (select 1 from public.clubs c where c.id = club_id and c.moderator_id = auth.uid())
  );
create policy "club_join_requests_insert_self" on public.club_join_requests for insert with check (user_id = auth.uid());
create policy "club_join_requests_update_moderator" on public.club_join_requests for update
  using (exists (select 1 from public.clubs c where c.id = club_id and c.moderator_id = auth.uid()))
  with check (exists (select 1 from public.clubs c where c.id = club_id and c.moderator_id = auth.uid()));

create table if not exists public.club_messages (
  id               uuid primary key default gen_random_uuid(),
  club_id          uuid not null references public.clubs (id) on delete cascade,
  sender_id        uuid references public.users (id) on delete set null,
  sender_name      text,
  sender_initials  text,
  body             text,
  sent_at          timestamptz not null default now()
);

create index if not exists club_messages_club_id_idx on public.club_messages (club_id);

alter table public.club_messages enable row level security;
create policy "club_messages_select_member" on public.club_messages for select
  using (exists (select 1 from public.club_members m where m.club_id = club_messages.club_id and m.user_id = auth.uid()));
create policy "club_messages_insert_member" on public.club_messages for insert
  with check (
    sender_id = auth.uid()
    and exists (select 1 from public.club_members m where m.club_id = club_messages.club_id and m.user_id = auth.uid())
  );

-- ============================================================================
-- Direct messaging (lib/models/messaging.dart)
-- ============================================================================

create table if not exists public.friend_requests (
  id                     uuid primary key default gen_random_uuid(),
  from_user_id           uuid references public.users (id) on delete set null,
  from_user_name         text,
  from_user_photo_url    text,
  from_user_role_label   text,
  to_user_id             uuid references public.users (id) on delete set null,
  status                 friend_request_status not null default 'pending',
  created_at             timestamptz not null default now()
);

alter table public.friend_requests enable row level security;
create policy "friend_requests_select_participant" on public.friend_requests for select
  using (from_user_id = auth.uid() or to_user_id = auth.uid());
create policy "friend_requests_insert_self" on public.friend_requests for insert with check (from_user_id = auth.uid());
create policy "friend_requests_update_recipient" on public.friend_requests for update
  using (to_user_id = auth.uid()) with check (to_user_id = auth.uid());

-- id kept as the original Firestore sorted-pair string ("{uidA}_{uidB}")
-- rather than reissued as a uuid — it's already a stable natural key and
-- other records don't reference it by FK, so there's nothing to gain by
-- replacing it.
create table if not exists public.friendships (
  id          text primary key,
  user_a_id   uuid references public.users (id) on delete cascade,
  user_b_id   uuid references public.users (id) on delete cascade,
  created_at  timestamptz not null default now()
);

alter table public.friendships enable row level security;
create policy "friendships_select_participant" on public.friendships for select
  using (user_a_id = auth.uid() or user_b_id = auth.uid());

create table if not exists public.conversations (
  id                       uuid primary key default gen_random_uuid(),
  participant_ids          uuid[] not null default '{}',
  participant_names        jsonb not null default '{}'::jsonb,
  participant_photos       jsonb not null default '{}'::jsonb,
  last_message_text        text,
  last_message_sender_id   uuid references public.users (id) on delete set null,
  last_message_at          timestamptz not null default now(),
  unread_count             jsonb not null default '{}'::jsonb,
  typing_at                jsonb not null default '{}'::jsonb
);

alter table public.conversations enable row level security;
create policy "conversations_select_participant" on public.conversations for select
  using (auth.uid() = any (participant_ids));
create policy "conversations_update_participant" on public.conversations for update
  using (auth.uid() = any (participant_ids)) with check (auth.uid() = any (participant_ids));

create table if not exists public.direct_messages (
  id               uuid primary key default gen_random_uuid(),
  conversation_id  uuid not null references public.conversations (id) on delete cascade,
  sender_id        uuid references public.users (id) on delete set null,
  sender_name      text,
  body             text,
  image_url        text,
  video_url        text,
  file_url         text,
  file_name        text,
  content_ref      jsonb,
  sent_at          timestamptz not null default now(),
  read_by          uuid[] not null default '{}'
);

create index if not exists direct_messages_conversation_id_idx on public.direct_messages (conversation_id);

alter table public.direct_messages enable row level security;
create policy "direct_messages_select_participant" on public.direct_messages for select
  using (exists (
    select 1 from public.conversations c
    where c.id = direct_messages.conversation_id and auth.uid() = any (c.participant_ids)
  ));
create policy "direct_messages_insert_participant" on public.direct_messages for insert
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.conversations c
      where c.id = direct_messages.conversation_id and auth.uid() = any (c.participant_ids)
    )
  );

create table if not exists public.follows (
  follower_id  uuid not null references public.users (id) on delete cascade,
  followed_id  uuid not null references public.users (id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (follower_id, followed_id)
);

alter table public.follows enable row level security;
create policy "follows_select_all" on public.follows for select using (auth.uid() is not null);
create policy "follows_insert_self" on public.follows for insert with check (follower_id = auth.uid());
create policy "follows_delete_self" on public.follows for delete using (follower_id = auth.uid());

-- ============================================================================
-- XP / gamification (lib/models/xp_transaction.dart)
-- ============================================================================

create table if not exists public.xp_transactions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users (id) on delete cascade,
  type          xp_transaction_type not null,
  source        xp_source not null,
  amount        integer not null,
  paper_id      text,
  article_id    uuid references public.magazine_articles (id) on delete set null,
  ref_id        uuid, -- test_attempts.id when source is mcq/structural/ac/test_completion
  occurred_at   timestamptz not null default now()
);

create index if not exists xp_transactions_user_id_idx on public.xp_transactions (user_id);

alter table public.xp_transactions enable row level security;
create policy "xp_transactions_select_own" on public.xp_transactions for select using (user_id = auth.uid());

create table if not exists public.unlocked_papers (
  user_id       uuid not null references public.users (id) on delete cascade,
  paper_id      text not null,
  unlocked_via  unlocked_via not null default 'xp',
  unlocked_at   timestamptz not null default now(),
  primary key (user_id, paper_id)
);

alter table public.unlocked_papers enable row level security;
create policy "unlocked_papers_select_own" on public.unlocked_papers for select using (user_id = auth.uid());

create table if not exists public.activity_days (
  user_id     uuid not null references public.users (id) on delete cascade,
  day         date not null,
  created_at  timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.activity_days enable row level security;
create policy "activity_days_select_own" on public.activity_days for select using (user_id = auth.uid());
create policy "activity_days_insert_own" on public.activity_days for insert with check (user_id = auth.uid());

-- ============================================================================
-- Home content (lib/models/hero_slide.dart, announcement.dart)
-- ============================================================================

create table if not exists public.hero_slides (
  id            uuid primary key default gen_random_uuid(),
  headline      text not null default '',
  subtext       text,
  cta_label     text not null default 'Explore Now',
  stat_line     text,
  destination   hero_destination not null default 'custom',
  custom_route  text,
  image_url     text,
  sort_order    integer not null default 0,
  active        boolean not null default true,
  created_by    uuid references public.users (id) on delete set null,
  created_at    timestamptz not null default now()
);

alter table public.hero_slides enable row level security;
create policy "hero_slides_select_all" on public.hero_slides for select using (true);
create policy "hero_slides_write_school_admin" on public.hero_slides for all
  using (public.has_min_role('school_admin')) with check (public.has_min_role('school_admin'));

create table if not exists public.announcements (
  id              uuid primary key default gen_random_uuid(),
  title           text not null,
  body            text,
  tag             text,
  author_id       uuid references public.users (id) on delete set null,
  author_name     text,
  occurred_at     timestamptz not null default now(), -- Firestore field name: `date`
  urgent          boolean not null default false,
  institution_id  uuid references public.institutions (id) on delete set null,
  source_type     text not null default 'general',
  reference_id    text,
  created_at      timestamptz not null default now()
);

create index if not exists announcements_institution_id_idx on public.announcements (institution_id);

alter table public.announcements enable row level security;
create policy "announcements_select_authenticated" on public.announcements for select using (auth.uid() is not null);
create policy "announcements_write_lecturer" on public.announcements for all
  using (public.has_min_role('lecturer')) with check (public.has_min_role('lecturer'));

-- ============================================================================
-- Audit log (lib/services/analytics_service.dart:134 —
-- audit_logs/{institutionId}/entries/{entryId} in Firestore)
-- ============================================================================

create table if not exists public.audit_log_entries (
  id              uuid primary key default gen_random_uuid(),
  institution_id  uuid references public.institutions (id) on delete set null,
  actor_id        uuid references public.users (id) on delete set null,
  actor_role      text,
  action          text not null,
  target_id       text,
  target_type     text,
  metadata        jsonb,
  severity        text,
  occurred_at     timestamptz not null default now()
);

create index if not exists audit_log_entries_institution_id_idx on public.audit_log_entries (institution_id);

alter table public.audit_log_entries enable row level security;
create policy "audit_log_entries_select_super_admin" on public.audit_log_entries for select
  using (public.has_min_role('super_admin'));
create policy "audit_log_entries_insert_authenticated" on public.audit_log_entries for insert
  with check (auth.uid() is not null);

-- ============================================================================
-- Engagement: comments/likes/bookmarks/learners, split by parent content
-- type (articles vs courses) — Firestore stored both under a
-- same-named `comments`/`bookmarks` subcollection distinguished only by
-- parent path; Postgres tables split them instead of one polymorphic table.
-- ============================================================================

create table if not exists public.article_comments (
  id                 uuid primary key default gen_random_uuid(),
  article_id         uuid not null references public.magazine_articles (id) on delete cascade,
  author_id          uuid references public.users (id) on delete set null,
  author_name        text,
  author_photo_url   text,
  parent_comment_id  uuid references public.article_comments (id) on delete cascade,
  body               text,
  created_at         timestamptz not null default now()
);

create index if not exists article_comments_article_id_idx on public.article_comments (article_id);

alter table public.article_comments enable row level security;
create policy "article_comments_select_all" on public.article_comments for select using (true);
create policy "article_comments_insert_authenticated" on public.article_comments for insert
  with check (author_id = auth.uid());
create policy "article_comments_delete_own" on public.article_comments for delete
  using (author_id = auth.uid() or public.has_min_role('lecturer'));

create table if not exists public.article_likes (
  article_id  uuid not null references public.magazine_articles (id) on delete cascade,
  user_id     uuid not null references public.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (article_id, user_id)
);

alter table public.article_likes enable row level security;
create policy "article_likes_select_all" on public.article_likes for select using (true);
create policy "article_likes_insert_self" on public.article_likes for insert with check (user_id = auth.uid());
create policy "article_likes_delete_self" on public.article_likes for delete using (user_id = auth.uid());

create table if not exists public.article_reads (
  article_id  uuid not null references public.magazine_articles (id) on delete cascade,
  user_id     uuid not null references public.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (article_id, user_id)
);

alter table public.article_reads enable row level security;
create policy "article_reads_insert_self" on public.article_reads for insert with check (user_id = auth.uid());

create table if not exists public.article_bookmarks (
  article_id  uuid not null references public.magazine_articles (id) on delete cascade,
  user_id     uuid not null references public.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (article_id, user_id)
);

alter table public.article_bookmarks enable row level security;
create policy "article_bookmarks_select_own" on public.article_bookmarks for select using (user_id = auth.uid());
create policy "article_bookmarks_insert_self" on public.article_bookmarks for insert with check (user_id = auth.uid());
create policy "article_bookmarks_delete_self" on public.article_bookmarks for delete using (user_id = auth.uid());

create table if not exists public.course_comments (
  id                uuid primary key default gen_random_uuid(),
  course_id         uuid not null references public.courses (id) on delete cascade,
  author_id         uuid references public.users (id) on delete set null,
  author_name       text,
  author_photo_url  text,
  body              text,
  created_at        timestamptz not null default now()
);

create index if not exists course_comments_course_id_idx on public.course_comments (course_id);

alter table public.course_comments enable row level security;
create policy "course_comments_select_all" on public.course_comments for select using (true);
create policy "course_comments_insert_authenticated" on public.course_comments for insert
  with check (author_id = auth.uid());

create table if not exists public.course_learners (
  course_id   uuid not null references public.courses (id) on delete cascade,
  user_id     uuid not null references public.users (id) on delete cascade,
  started_at  timestamptz not null default now(),
  primary key (course_id, user_id)
);

alter table public.course_learners enable row level security;
create policy "course_learners_select_own" on public.course_learners for select using (user_id = auth.uid());
create policy "course_learners_insert_self" on public.course_learners for insert with check (user_id = auth.uid());

create table if not exists public.course_bookmarks (
  course_id   uuid not null references public.courses (id) on delete cascade,
  user_id     uuid not null references public.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (course_id, user_id)
);

alter table public.course_bookmarks enable row level security;
create policy "course_bookmarks_select_own" on public.course_bookmarks for select using (user_id = auth.uid());
create policy "course_bookmarks_insert_self" on public.course_bookmarks for insert with check (user_id = auth.uid());
create policy "course_bookmarks_delete_self" on public.course_bookmarks for delete using (user_id = auth.uid());

-- No confirmed Firestore data for course ratings yet (0 rows in the
-- export) — shape inferred from context (public_courses/{id}/ratings/
-- {userId}, feeding PublicCourse.avgRating/ratingCount), not read from a
-- model file. Verify against CourseRating's real fields if one gets
-- added to the Dart side later.
create table if not exists public.course_ratings (
  course_id   uuid not null references public.courses (id) on delete cascade,
  user_id     uuid not null references public.users (id) on delete cascade,
  rating      integer not null check (rating between 1 and 5),
  created_at  timestamptz not null default now(),
  primary key (course_id, user_id)
);

alter table public.course_ratings enable row level security;
create policy "course_ratings_select_all" on public.course_ratings for select using (true);
create policy "course_ratings_insert_self" on public.course_ratings for insert with check (user_id = auth.uid());

-- ============================================================================
-- Notifications (lib/models/app_notification.dart)
-- ============================================================================

create table if not exists public.notifications (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.users (id) on delete cascade,
  type           notification_type not null default 'system',
  title          text,
  body           text,
  deep_link_id   text,
  read           boolean not null default false,
  created_at     timestamptz not null default now()
);

create index if not exists notifications_user_id_idx on public.notifications (user_id);

alter table public.notifications enable row level security;
create policy "notifications_select_own" on public.notifications for select using (user_id = auth.uid());
create policy "notifications_update_own" on public.notifications for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "notifications_delete_own" on public.notifications for delete using (user_id = auth.uid());

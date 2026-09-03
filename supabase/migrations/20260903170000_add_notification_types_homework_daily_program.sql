-- 20260903170000_add_notification_types_homework_daily_program.sql
-- notifications.type is the enum public.notification_type (announcement,
-- comment, reply, article_published, system) -- not free text. Adding the
-- two new values the Homework feature and the daily aggregator need.
-- Split into its own migration/transaction ahead of the function that
-- uses them: a value added by ALTER TYPE ... ADD VALUE isn't safe to use
-- in the very same transaction that added it.

alter type public.notification_type add value if not exists 'homework';
alter type public.notification_type add value if not exists 'daily_program';

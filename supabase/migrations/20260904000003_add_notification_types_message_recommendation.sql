-- 20260904000003_add_notification_types_message_recommendation.sql
-- notifications.type is the enum public.notification_type -- adding the
-- values spec items 9B/9D need. Split into its own migration ahead of
-- any function that uses them (20260903170000 already established why:
-- a value added by ALTER TYPE ... ADD VALUE isn't safe to use in the
-- same transaction that added it).

alter type public.notification_type add value if not exists 'message';
alter type public.notification_type add value if not exists 'recommendation';

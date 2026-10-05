-- ============================================================================
-- greenhills_app/ladybird_app additions on top of the shared
-- conversations/direct_messages tables:
--   - conversations.active_at — real per-conversation "had this thread
--     open in the last couple minutes" presence, same mechanism as the
--     existing typing_at.
--   - conversations.pinned_by — per-user "pin to top" view preference.
--   - direct_messages.deleted — soft-delete marker (sender clears the
--     body, keeps the row as a placeholder).
--   - direct_messages.shared_*  — flat denormalized shared-content
--     attachment (Course/Quiz/Article/Note/Past Paper), replacing the
--     nested content_ref jsonb academia-cameroon's ContentRef used.
--     content_ref stays as-is there; these are separate, additive columns.
-- Same shared tables as academia-cameroon; unused there.
-- ============================================================================

alter table public.conversations
  add column if not exists active_at jsonb not null default '{}'::jsonb,
  add column if not exists pinned_by uuid[] not null default '{}';

alter table public.direct_messages
  add column if not exists deleted boolean not null default false,
  add column if not exists shared_type text,
  add column if not exists shared_id text,
  add column if not exists shared_title text,
  add column if not exists shared_subtitle text,
  add column if not exists shared_thumbnail_url text;

-- ============================================================================
-- AuthService.currentAppUserStream() (Firestore version) live-updates the
-- Profile/Home UI whenever the user doc changes (XP awarded, streak
-- recorded, etc.) via a snapshots() listener. supabase_flutter's
-- equivalent (.stream()) needs the table added to the `supabase_realtime`
-- publication — without this, .stream() silently never emits.
-- ============================================================================

alter publication supabase_realtime add table public.users;

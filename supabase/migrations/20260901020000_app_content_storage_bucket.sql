-- 20260901020000_app_content_storage_bucket.sql
-- The Home page's greeting banner upload fails with:
--   Could not upload banner: Failed to upload banner image
--
-- lib/repositories/home_hero_repository.dart and club_repository.dart's
-- uploadBanner/uploadThumbnail both write to storage bucket
-- 'app-content' and read back via getPublicUrl() (implying a *public*
-- bucket, no signed URLs anywhere in the client code) -- but the bucket
-- was never created, so every upload 403s. Creates it (idempotent) and
-- adds the matching storage.objects policies: public read, authenticated
-- write. Fine-grained "only a club's admin/school admin can write to
-- their own club/home banner path" is already enforced client-side
-- (_canManageHeroBanner, club admin checks before uploadBanner is ever
-- called) -- this bucket has no per-user-scoped paths for RLS to key
-- off of (home_hero/banner.jpg is a single shared path), so the
-- storage-level policy is deliberately just "any authenticated user."

insert into storage.buckets (id, name, public)
values ('app-content', 'app-content', true)
on conflict (id) do update set public = true;

create policy "app-content public read"
  on storage.objects for select
  using (bucket_id = 'app-content');

create policy "app-content authenticated write"
  on storage.objects for insert
  with check (bucket_id = 'app-content' and auth.role() = 'authenticated');

create policy "app-content authenticated update"
  on storage.objects for update
  using (bucket_id = 'app-content' and auth.role() = 'authenticated')
  with check (bucket_id = 'app-content' and auth.role() = 'authenticated');

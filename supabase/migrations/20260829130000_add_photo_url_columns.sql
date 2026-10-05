-- ============================================================================
-- Three columns missed in the original schema passes — AppUser.photoUrl,
-- MagazineArticle.authorPhotoUrl, and PublicCourse.creatorPhotoUrl all
-- exist on the Firestore side but had no Postgres destination, found while
-- auditing which Firebase Storage files actually need migrating.
-- ============================================================================

alter table public.users add column if not exists photo_url text;
alter table public.magazine_articles add column if not exists author_photo_url text;
alter table public.courses add column if not exists creator_photo_url text;

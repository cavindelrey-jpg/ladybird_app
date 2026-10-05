-- ============================================================================
-- greenhills_app/ladybird_app's Home page hero background image — a
-- single well-known row, not a collection (there is only ever one Home
-- hero background for the whole app). Small enough to build for real.
-- Same shared database as academia-cameroon; unused there.
-- ============================================================================

create table if not exists public.home_hero (
  id         text primary key default 'config',
  image_url  text
);

alter table public.home_hero enable row level security;
create policy "home_hero_select_all" on public.home_hero for select using (true);
create policy "home_hero_write_lecturer" on public.home_hero for all
  using (public.has_min_role('lecturer')) with check (public.has_min_role('lecturer'));

-- 1. Create the `school_memberships` table
create table if not exists public.school_memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  school_id uuid not null references public.institutions (id) on delete cascade,
  role user_role not null default 'student',
  school_role text,
  class_level text,
  class_master_of_class text,
  school_voucher_ref text references public.school_vouchers (id) on delete set null,
  created_at timestamptz not null default now(),
  unique(user_id, school_id)
);

create index if not exists school_memberships_user_id_idx on public.school_memberships(user_id);
create index if not exists school_memberships_school_id_idx on public.school_memberships(school_id);

alter table public.school_memberships enable row level security;

-- Users can read their own memberships
create policy "school_memberships_select_self" on public.school_memberships for select
  using (user_id = auth.uid());

-- 2. Migrate existing data from `public.users` into `school_memberships`
insert into public.school_memberships (
  user_id, school_id, role, school_role, class_level, class_master_of_class, school_voucher_ref
)
select 
  id, institution_id, role, school_role, class_level, class_master_of_class, school_voucher_ref
from public.users
where institution_id is not null
on conflict (user_id, school_id) do nothing;

-- 3. Create contextual role-check helper
create or replace function public.has_school_role(p_school_id uuid, min_role user_role)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.school_memberships
    where user_id = auth.uid()
      and school_id = p_school_id
      and public.role_level(role) >= public.role_level(min_role)
  ) or exists (
    select 1 from public.users
    where id = auth.uid()
      and public.role_level(role) >= public.role_level(min_role)
  );
$$;

-- 4. Update the voucher redemption RPC to INSERT into memberships instead of overriding global user
create or replace function public.redeem_school_voucher(p_code text, p_class_level text default null)
returns table (out_school_id uuid, out_role text)
language plpgsql security definer set search_path = public as $$
declare
  v_status text;
  v_school_id uuid;
  v_role text;
  v_content_role user_role;
begin
  if auth.uid() is null then
    raise exception 'You need to be signed in to link a school';
  end if;

  select status, school_id, role into v_status, v_school_id, v_role
    from public.school_vouchers where id = p_code for update;

  if v_status is null then
    raise exception 'No school code found matching that entry';
  end if;
  if v_status = 'revoked' then
    raise exception 'This school code has been revoked';
  end if;
  if v_status = 'redeemed' then
    raise exception 'This code has already been used';
  end if;

  update public.school_vouchers
    set status = 'redeemed', redeemed_at = now(), redeemed_by_user_id = auth.uid()
    where id = p_code;

  v_content_role := case v_role
    when 'student'     then 'student'::user_role
    when 'parent'      then 'guest'::user_role
    when 'teacher'     then 'lecturer'::user_role
    when 'classMaster' then 'lecturer'::user_role
    when 'admin'       then 'school_admin'::user_role
    else 'student'::user_role
  end;

  insert into public.school_memberships (
    user_id, school_id, role, school_role, class_level, class_master_of_class, school_voucher_ref
  ) values (
    auth.uid(),
    v_school_id,
    v_content_role,
    v_role,
    case when p_class_level is not null and p_class_level <> '' then p_class_level else null end,
    case when v_role = 'classMaster' and p_class_level is not null and p_class_level <> '' then p_class_level else null end,
    p_code
  )
  on conflict (user_id, school_id) do update set
    role = excluded.role,
    school_role = excluded.school_role,
    class_level = coalesce(excluded.class_level, public.school_memberships.class_level),
    class_master_of_class = coalesce(excluded.class_master_of_class, public.school_memberships.class_master_of_class),
    school_voucher_ref = excluded.school_voucher_ref;

  out_school_id := v_school_id;
  out_role := v_role;
  return next;
end;
$$;

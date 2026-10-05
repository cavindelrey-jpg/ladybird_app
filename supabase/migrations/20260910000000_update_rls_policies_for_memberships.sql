-- Replaces policy institutions_write_super_admin on institutions
drop policy if exists "institutions_write_super_admin" on public.institutions;
create policy "institutions_write_super_admin" on public.institutions
  for all
  using (public.has_school_role(id, 'super_admin'))
  with check (public.has_school_role(id, 'super_admin'));

-- Replaces policy users_select_self_or_admin on users
drop policy if exists "users_select_self_or_admin" on public.users;
create policy "users_select_self_or_admin" on public.users
  for select
  using (id = auth.uid() or public.has_school_role(institution_id, 'department_admin'));

-- Replaces policy users_update_admin on users
drop policy if exists "users_update_admin" on public.users;
create policy "users_update_admin" on public.users
  for update
  using (public.has_school_role(institution_id, 'department_admin'))
  with check (public.has_school_role(institution_id, 'department_admin'));

-- Replaces policy student_accounts_select_own_or_admin on student_accounts
drop policy if exists "student_accounts_select_own_or_admin" on public.student_accounts;
create policy "student_accounts_select_own_or_admin" on public.student_accounts
  for select
  using (
    user_id = auth.uid()
    or public.has_school_role(institution_id, 'school_admin')
  );

-- Replaces policy student_accounts_update_own_or_admin on student_accounts
drop policy if exists "student_accounts_update_own_or_admin" on public.student_accounts;
create policy "student_accounts_update_own_or_admin" on public.student_accounts
  for update
  using (
    user_id = auth.uid()
    or public.has_school_role(institution_id, 'school_admin')
  )
  with check (
    user_id = auth.uid()
    or public.has_school_role(institution_id, 'school_admin')
  );

-- Replaces policy student_accounts_insert_admin on student_accounts
drop policy if exists "student_accounts_insert_admin" on public.student_accounts;
create policy "student_accounts_insert_admin" on public.student_accounts
  for insert
  with check (
    public.has_school_role(institution_id, 'school_admin')
  );

-- Replaces policy student_accounts_delete_admin on student_accounts
drop policy if exists "student_accounts_delete_admin" on public.student_accounts;
create policy "student_accounts_delete_admin" on public.student_accounts
  for delete
  using (
    public.has_school_role(institution_id, 'school_admin')
  );

-- Replaces policy serials_write_school_admin on serials
drop policy if exists "serials_write_school_admin" on public.serials;
create policy "serials_write_school_admin" on public.serials
  for all
  using (
    public.has_school_role(null, 'school_admin')
  )
  with check (
    public.has_school_role(null, 'school_admin')
  );

-- Replaces policy library_items_write_lecturer on library_items
drop policy if exists "library_items_write_lecturer" on public.library_items;
create policy "library_items_write_lecturer" on public.library_items
  for all
  using (public.has_school_role(null, 'lecturer'))
  with check (public.has_school_role(null, 'lecturer'));

-- Replaces policy courses_write_lecturer on courses
drop policy if exists "courses_write_lecturer" on public.courses;
create policy "courses_write_lecturer" on public.courses
  for all
  using (public.has_school_role(institution_id, 'lecturer'))
  with check (public.has_school_role(institution_id, 'lecturer'));

-- Replaces policy magazine_articles_write_lecturer on magazine_articles
drop policy if exists "magazine_articles_write_lecturer" on public.magazine_articles;
create policy "magazine_articles_write_lecturer" on public.magazine_articles
  for all
  using (public.has_school_role(null, 'lecturer'))
  with check (public.has_school_role(null, 'lecturer'));

-- Replaces policy tests_write_lecturer on tests
drop policy if exists "tests_write_lecturer" on public.tests;
create policy "tests_write_lecturer" on public.tests
  for all
  using (public.has_school_role(institution_id, 'lecturer')) with check (public.has_school_role(institution_id, 'lecturer'));

-- Replaces policy test_attempts_select_own_or_lecturer on test_attempts
drop policy if exists "test_attempts_select_own_or_lecturer" on public.test_attempts;
create policy "test_attempts_select_own_or_lecturer" on public.test_attempts
  for select
  using (user_id = auth.uid() or public.has_school_role((select institution_id from public.tests where id = test_id), 'lecturer'));

-- Replaces policy test_attempts_update_lecturer on test_attempts
drop policy if exists "test_attempts_update_lecturer" on public.test_attempts;
create policy "test_attempts_update_lecturer" on public.test_attempts
  for update
  using (public.has_school_role((select institution_id from public.tests where id = test_id), 'lecturer')) with check (public.has_school_role((select institution_id from public.tests where id = test_id), 'lecturer'));

-- Replaces policy clubs_update_moderator on clubs
drop policy if exists "clubs_update_moderator" on public.clubs;
create policy "clubs_update_moderator" on public.clubs
  for update
  using (moderator_id = auth.uid() or public.has_school_role(institution_id, 'school_admin'))
  with check (moderator_id = auth.uid() or public.has_school_role(institution_id, 'school_admin'));

-- Replaces policy clubs_delete_moderator on clubs
drop policy if exists "clubs_delete_moderator" on public.clubs;
create policy "clubs_delete_moderator" on public.clubs
  for delete
  using (moderator_id = auth.uid() or public.has_school_role(institution_id, 'school_admin'));

-- Replaces policy club_members_delete_self_or_moderator on club_members
drop policy if exists "club_members_delete_self_or_moderator" on public.club_members;
create policy "club_members_delete_self_or_moderator" on public.club_members
  for delete
  using (
    user_id = auth.uid()
    or exists (select 1 from public.clubs c where c.id = club_id and c.moderator_id = auth.uid())
    or public.has_school_role((select institution_id from public.clubs where id = club_id), 'school_admin')
  );

-- Replaces policy hero_slides_write_school_admin on hero_slides
drop policy if exists "hero_slides_write_school_admin" on public.hero_slides;
create policy "hero_slides_write_school_admin" on public.hero_slides
  for all
  using (public.has_school_role(null, 'school_admin')) with check (public.has_school_role(null, 'school_admin'));

-- Replaces policy announcements_write_lecturer on announcements
drop policy if exists "announcements_write_lecturer" on public.announcements;
create policy "announcements_write_lecturer" on public.announcements
  for all
  using (public.has_school_role(institution_id, 'lecturer')) with check (public.has_school_role(institution_id, 'lecturer'));

-- Replaces policy audit_log_entries_select_super_admin on audit_log_entries
drop policy if exists "audit_log_entries_select_super_admin" on public.audit_log_entries;
create policy "audit_log_entries_select_super_admin" on public.audit_log_entries
  for select
  using (public.has_school_role(institution_id, 'super_admin'));

-- Replaces policy article_comments_delete_own on article_comments
drop policy if exists "article_comments_delete_own" on public.article_comments;
create policy "article_comments_delete_own" on public.article_comments
  for delete
  using (author_id = auth.uid() or public.has_school_role(null, 'lecturer'));

-- Replaces policy academic_content_write_lecturer on academic_content
drop policy if exists "academic_content_write_lecturer" on public.academic_content;
create policy "academic_content_write_lecturer" on public.academic_content
  for all
  using (public.has_school_role(institution_id, 'lecturer')) with check (public.has_school_role(institution_id, 'lecturer'));

-- Replaces policy curriculum_icons_write_lecturer on curriculum_icons
drop policy if exists "curriculum_icons_write_lecturer" on public.curriculum_icons;
create policy "curriculum_icons_write_lecturer" on public.curriculum_icons
  for all
  using (public.has_school_role(null, 'lecturer')) with check (public.has_school_role(null, 'lecturer'));

-- Replaces policy school_vouchers_select_staff on school_vouchers
drop policy if exists "school_vouchers_select_staff" on public.school_vouchers;
create policy "school_vouchers_select_staff" on public.school_vouchers
  for select
  using (public.has_school_role(school_id, 'department_admin'));

-- Replaces policy school_vouchers_insert_staff on school_vouchers
drop policy if exists "school_vouchers_insert_staff" on public.school_vouchers;
create policy "school_vouchers_insert_staff" on public.school_vouchers
  for insert
  with check (public.has_school_role(school_id, 'department_admin')
              and created_by_uid = auth.uid()
              and status = 'unused'
              and (public.has_school_role(school_id, 'super_admin') or school_id = public.current_institution_id()));

-- Replaces policy school_vouchers_update_staff on school_vouchers
drop policy if exists "school_vouchers_update_staff" on public.school_vouchers;
create policy "school_vouchers_update_staff" on public.school_vouchers
  for update
  using (public.has_school_role(school_id, 'department_admin'))
  with check (public.has_school_role(school_id, 'department_admin'));

-- Replaces policy academic_sections_write_lecturer on academic_sections
drop policy if exists "academic_sections_write_lecturer" on public.academic_sections;
create policy "academic_sections_write_lecturer" on public.academic_sections
  for all
  using (public.has_school_role(null, 'lecturer')) with check (public.has_school_role(null, 'lecturer'));

-- Replaces policy course_category_visuals_write_lecturer on course_category_visuals
drop policy if exists "course_category_visuals_write_lecturer" on public.course_category_visuals;
create policy "course_category_visuals_write_lecturer" on public.course_category_visuals
  for all
  using (public.has_school_role(null, 'lecturer')) with check (public.has_school_role(null, 'lecturer'));

-- Replaces policy home_hero_write_lecturer on home_hero
drop policy if exists "home_hero_write_lecturer" on public.home_hero;
create policy "home_hero_write_lecturer" on public.home_hero
  for all
  using (public.has_school_role(null, 'lecturer')) with check (public.has_school_role(null, 'lecturer'));

-- Replaces policy super_admin_vouchers_select_super_admin on super_admin_vouchers
drop policy if exists "super_admin_vouchers_select_super_admin" on public.super_admin_vouchers;
create policy "super_admin_vouchers_select_super_admin" on public.super_admin_vouchers
  for select
  using (public.has_school_role(null, 'super_admin'));

-- Replaces policy super_admin_vouchers_insert_super_admin on super_admin_vouchers
drop policy if exists "super_admin_vouchers_insert_super_admin" on public.super_admin_vouchers;
create policy "super_admin_vouchers_insert_super_admin" on public.super_admin_vouchers
  for insert
  with check (
    public.has_school_role(null, 'super_admin')
    and created_by = auth.uid()
    and status = 'unused'
  );

-- Replaces policy super_admin_vouchers_revoke_super_admin on super_admin_vouchers
drop policy if exists "super_admin_vouchers_revoke_super_admin" on public.super_admin_vouchers;
create policy "super_admin_vouchers_revoke_super_admin" on public.super_admin_vouchers
  for update
  using (public.has_school_role(null, 'super_admin') and status = 'unused')
  with check (status = 'revoked');

-- Replaces policy course_levels_write_lecturer on course_levels
drop policy if exists "course_levels_write_lecturer" on public.course_levels;
create policy "course_levels_write_lecturer" on public.course_levels
  for all
  using (public.has_school_role(null, 'lecturer')) with check (public.has_school_role(null, 'lecturer'));

-- Replaces policy course_lessons_write_lecturer on course_lessons
drop policy if exists "course_lessons_write_lecturer" on public.course_lessons;
create policy "course_lessons_write_lecturer" on public.course_lessons
  for all
  using (public.has_school_role(null, 'lecturer')) with check (public.has_school_role(null, 'lecturer'));

-- Replaces policy library_folders_write_lecturer on library_folders
drop policy if exists "library_folders_write_lecturer" on public.library_folders;
create policy "library_folders_write_lecturer" on public.library_folders
  for all using (public.has_school_role(null, 'lecturer')) with check (public.has_school_role(null, 'lecturer'));

-- Replaces policy academia_premium_vouchers_select_super_admin on academia_premium_vouchers
drop policy if exists "academia_premium_vouchers_select_super_admin" on public.academia_premium_vouchers;
create policy "academia_premium_vouchers_select_super_admin" on public.academia_premium_vouchers
  for select
  using (public.has_school_role(null, 'super_admin'));

-- Replaces policy academia_premium_vouchers_insert_super_admin on academia_premium_vouchers
drop policy if exists "academia_premium_vouchers_insert_super_admin" on public.academia_premium_vouchers;
create policy "academia_premium_vouchers_insert_super_admin" on public.academia_premium_vouchers
  for insert
  with check (
    public.has_school_role(null, 'super_admin')
    and created_by = auth.uid()
    and status = 'unused'
  );

-- Replaces policy academia_premium_vouchers_revoke_super_admin on academia_premium_vouchers
drop policy if exists "academia_premium_vouchers_revoke_super_admin" on public.academia_premium_vouchers;
create policy "academia_premium_vouchers_revoke_super_admin" on public.academia_premium_vouchers
  for update
  using (public.has_school_role(null, 'super_admin') and status = 'unused')
  with check (status = 'revoked');

-- Replaces policy club_join_requests_select_own_or_staff on club_join_requests
drop policy if exists "club_join_requests_select_own_or_staff" on public.club_join_requests;
create policy "club_join_requests_select_own_or_staff" on public.club_join_requests
  for select
  using (
    user_id = auth.uid()
    or public.is_club_staff(club_id)
    or public.has_school_role((select institution_id from public.clubs where id = club_id), 'school_admin')
  );

-- Replaces policy club_join_requests_update_staff on club_join_requests
drop policy if exists "club_join_requests_update_staff" on public.club_join_requests;
create policy "club_join_requests_update_staff" on public.club_join_requests
  for update
  using (public.is_club_staff(club_id) or public.has_school_role((select institution_id from public.clubs where id = club_id), 'school_admin'))
  with check (public.is_club_staff(club_id) or public.has_school_role((select institution_id from public.clubs where id = club_id), 'school_admin'));

-- Replaces policy club_members_delete_self_or_staff on club_members
drop policy if exists "club_members_delete_self_or_staff" on public.club_members;
create policy "club_members_delete_self_or_staff" on public.club_members
  for delete
  using (
    user_id = auth.uid()
    or public.is_club_staff(club_id)
    or public.has_school_role((select institution_id from public.clubs where id = club_id), 'school_admin')
  );


-- Update RPC functions
create or replace function public.approve_club_join_request(p_request_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_req record;
begin
  select * into v_req from public.club_join_requests where id = p_request_id;
  if v_req is null then raise exception 'Request not found.'; end if;
  if not (public.is_club_staff(v_req.club_id) or public.has_school_role((select institution_id from public.clubs where id = v_req.club_id), 'school_admin')) then
    raise exception 'Not authorized to approve this request.';
  end if;

  update public.club_join_requests set status = 'approved' where id = p_request_id;
  insert into public.club_members (club_id, user_id, name, photo_url, role)
    values (v_req.club_id, v_req.user_id, v_req.user_name, v_req.user_photo_url, 'member')
    on conflict (club_id, user_id) do nothing;
  if found then
    update public.clubs set member_count = member_count + 1 where id = v_req.club_id;
  end if;
end;
$$;

create or replace function public.remove_club_member(p_club_id uuid, p_user_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not (public.is_club_staff(p_club_id)
          or public.has_school_role((select institution_id from public.clubs where id = p_club_id), 'school_admin')
          or auth.uid() = p_user_id) then
    raise exception 'Not authorized to remove this member.';
  end if;
  delete from public.club_members where club_id = p_club_id and user_id = p_user_id;
  if found then
    update public.clubs set member_count = greatest(0, member_count - 1) where id = p_club_id;
  end if;
end;
$$;

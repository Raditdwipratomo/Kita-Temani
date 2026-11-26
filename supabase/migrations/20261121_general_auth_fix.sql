-- supabase/migrations/20261121_general_auth_fix.sql
-- Idempotent patch for live databases:
-- 1) Fix ERROR 42P10 by replacing partial unique index on schools(slug) with a full unique index
-- 2) Remove role escalation so only the dedicated Guru BK account (bk@kitatemani.id) gets guru_bk
-- 3) Automatically sync bk@kitatemani.id if already created in Supabase Authentication

drop index if exists public.schools_slug_uidx;
create unique index if not exists schools_slug_uidx on public.schools (slug);

insert into public.schools (slug, name, city, counselor_name, counselor_phone)
values ('sman1-nusantara', 'SMAN 1 Nusantara', 'Jakarta', 'Bu Rina, S.Pd.', '0811-2233-4455')
on conflict (slug) do update set
  name = excluded.name,
  city = excluded.city,
  counselor_name = excluded.counselor_name,
  counselor_phone = excluded.counselor_phone;

create or replace function public.upsert_my_profile(
  p_name text,
  p_class_name text,
  p_school_slug text default 'sman1-nusantara',
  p_is_private_mode boolean default false,
  p_is_disguised_mode boolean default false,
  p_role text default 'siswa',
  p_email text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_jwt_email text := lower(coalesce((select auth.jwt() ->> 'email'), ''));
  v_is_existing_staff boolean := false;
  v_school_id uuid;
  v_short_name text;
  v_resolved_role text;
  v_school_name text := 'SMAN 1 Nusantara';
  v_school_slug text := 'sman1-nusantara';
  v_counselor_name text := 'Bu Rina, S.Pd.';
begin
  if v_uid is null then
    raise exception 'unauthorized';
  end if;

  select exists (select 1 from public.staff where user_id = v_uid)
  into v_is_existing_staff;

  -- Only the dedicated counselor email (or an already provisioned staff row) gets Guru BK role.
  if v_jwt_email = 'bk@kitatemani.id' or v_is_existing_staff then
    v_resolved_role := 'guru_bk';
  else
    v_resolved_role := 'siswa';
  end if;

  select id, slug, name, counselor_name
  into v_school_id, v_school_slug, v_school_name, v_counselor_name
  from public.schools
  where slug = coalesce(nullif(nullif(p_school_slug, 'private-mode'), ''), 'sman1-nusantara')
     or id::text = p_school_slug
  limit 1;

  if v_school_id is null then
    select id, slug, name, counselor_name
    into v_school_id, v_school_slug, v_school_name, v_counselor_name
    from public.schools
    order by created_at asc
    limit 1;
  end if;

  v_short_name := split_part(trim(coalesce(nullif(p_name, ''), case when v_resolved_role = 'guru_bk' then 'Bu Rina' else 'Maya Putri' end)), ' ', 1);

  insert into public.profiles (
    id, school_id, name, short_name, class_name, email, role,
    is_private_mode, is_disguised_mode, updated_at
  )
  values (
    v_uid, v_school_id,
    coalesce(nullif(trim(p_name), ''), case when v_resolved_role = 'guru_bk' then 'Bu Rina, S.Pd.' else 'Maya Putri' end),
    v_short_name,
    coalesce(nullif(trim(p_class_name), ''), case when v_resolved_role = 'guru_bk' then 'Ruang BK' else 'XI-2' end),
    coalesce(nullif(v_jwt_email, ''), coalesce(p_email, '')),
    v_resolved_role,
    false,
    p_is_disguised_mode,
    now()
  )
  on conflict (id) do update set
    school_id = coalesce(excluded.school_id, public.profiles.school_id),
    name = excluded.name,
    short_name = excluded.short_name,
    class_name = excluded.class_name,
    email = case when excluded.email <> '' then excluded.email else public.profiles.email end,
    role = excluded.role,
    is_private_mode = false,
    is_disguised_mode = excluded.is_disguised_mode,
    updated_at = now();

  if v_resolved_role = 'guru_bk' and v_school_id is not null then
    insert into public.staff (user_id, school_id, full_name, role)
    values (v_uid, v_school_id, coalesce(nullif(trim(p_name), ''), 'Bu Rina, S.Pd.'), 'guru_bk')
    on conflict (user_id) do update set
      school_id = excluded.school_id,
      full_name = excluded.full_name,
      role = 'guru_bk';
  else
    delete from public.staff where user_id = v_uid;
  end if;

  return jsonb_build_object(
    'id', v_uid,
    'school_id', v_school_id,
    'school_slug', coalesce(v_school_slug, 'sman1-nusantara'),
    'school_name', coalesce(v_school_name, 'SMAN 1 Nusantara'),
    'counselor_name', coalesce(v_counselor_name, 'Bu Rina, S.Pd.'),
    'role', v_resolved_role
  );
end;
$$;

-- If the special Guru BK user (bk@kitatemani.id) already exists in Supabase Auth, grant staff access now.
do $$
declare
  v_bk_uid uuid;
  v_school_id uuid;
begin
  select id into v_bk_uid from auth.users where lower(email) = 'bk@kitatemani.id' limit 1;
  select id into v_school_id from public.schools where slug = 'sman1-nusantara' limit 1;

  if v_bk_uid is not null and v_school_id is not null then
    insert into public.profiles (id, school_id, name, short_name, class_name, email, role, is_private_mode)
    values (v_bk_uid, v_school_id, 'Bu Rina, S.Pd.', 'Bu Rina', 'Ruang BK', 'bk@kitatemani.id', 'guru_bk', false)
    on conflict (id) do update set
      school_id = excluded.school_id,
      role = 'guru_bk',
      class_name = 'Ruang BK',
      is_private_mode = false;

    insert into public.staff (user_id, school_id, full_name, role)
    values (v_bk_uid, v_school_id, 'Bu Rina, S.Pd.', 'guru_bk')
    on conflict (user_id) do update set
      school_id = excluded.school_id,
      role = 'guru_bk';
  end if;
end $$;

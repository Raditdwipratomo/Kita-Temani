-- supabase/migrations/20261125_profile_details.sql
-- Expand user profile fields (phone number, avatar preset/photo, gender,
-- birth_date, education_level, homeroom_teacher, parent_name, preferred contact,
-- safety_note) without collecting NIS/student_number.

alter table public.profiles
  add column if not exists avatar_preset text not null default 'indigo',
  add column if not exists avatar_url text not null default '',
  add column if not exists gender text not null default '',
  add column if not exists birth_date date,
  add column if not exists education_level text not null default '',
  add column if not exists homeroom_teacher text not null default '',
  add column if not exists phone_number text not null default '',
  add column if not exists parent_name text not null default '',
  add column if not exists preferred_contact_method text not null default 'ruang_bk',
  add column if not exists safety_note text not null default '';

alter table public.profiles drop constraint if exists profiles_gender_check;
alter table public.profiles
  add constraint profiles_gender_check check (gender in ('', 'L', 'P', 'other'));

alter table public.profiles drop constraint if exists profiles_education_level_check;
alter table public.profiles
  add constraint profiles_education_level_check check (education_level in ('', 'SMP', 'SMA', 'SMK', 'MA'));

alter table public.profiles drop constraint if exists profiles_preferred_contact_check;
alter table public.profiles
  add constraint profiles_preferred_contact_check check (
    preferred_contact_method in ('ruang_bk', 'whatsapp', 'orang_tua', 'aplikasi')
  );

alter table public.profiles drop constraint if exists profiles_safety_note_len_check;
alter table public.profiles
  add constraint profiles_safety_note_len_check check (char_length(safety_note) <= 160);

drop function if exists public.upsert_my_profile(text, text, text, boolean, boolean, text, text);
drop function if exists public.upsert_my_profile(text, text, text, boolean, boolean, text, text, text, boolean);

create or replace function public.upsert_my_profile(
  p_name text,
  p_class_name text,
  p_school_slug text default 'sman1-nusantara',
  p_is_private_mode boolean default false,
  p_is_disguised_mode boolean default false,
  p_role text default 'siswa',
  p_email text default null,
  p_school_name text default null,
  p_is_profile_completed boolean default true,
  p_short_name text default null,
  p_avatar_preset text default null,
  p_avatar_url text default null,
  p_gender text default null,
  p_birth_date date default null,
  p_education_level text default null,
  p_homeroom_teacher text default null,
  p_phone_number text default null,
  p_parent_name text default null,
  p_preferred_contact_method text default null,
  p_safety_note text default null
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
  v_default_school_name text := 'SMAN 1 Nusantara';
  v_school_slug text := 'sman1-nusantara';
  v_counselor_name text := 'Bu Rina, S.Pd.';
  v_counselor_phone text := '089686899447';
  v_final_name text;
  v_final_class text;
  v_final_school_name text;
  v_completed boolean;
  v_avatar_preset text;
  v_avatar_url text;
  v_gender text;
  v_education_level text;
  v_homeroom_teacher text;
  v_phone_number text;
  v_parent_name text;
  v_preferred_contact text;
  v_safety_note text;
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

  select id, slug, name, counselor_name, counselor_phone
  into v_school_id, v_school_slug, v_default_school_name, v_counselor_name, v_counselor_phone
  from public.schools
  where slug = coalesce(nullif(nullif(p_school_slug, 'private-mode'), ''), 'sman1-nusantara')
     or id::text = p_school_slug
  limit 1;

  if v_school_id is null then
    select id, slug, name, counselor_name, counselor_phone
    into v_school_id, v_school_slug, v_default_school_name, v_counselor_name, v_counselor_phone
    from public.schools
    order by created_at asc
    limit 1;
  end if;

  v_final_name := coalesce(
    nullif(trim(coalesce(p_name, '')), ''),
    case when v_resolved_role = 'guru_bk' then 'Bu Rina, S.Pd.' else '' end
  );
  v_final_class := coalesce(
    nullif(trim(coalesce(p_class_name, '')), ''),
    case when v_resolved_role = 'guru_bk' then 'Ruang BK' else '' end
  );
  v_final_school_name := coalesce(
    nullif(trim(coalesce(p_school_name, '')), ''),
    case when v_resolved_role = 'guru_bk' then coalesce(v_default_school_name, 'SMAN 1 Nusantara') else '' end
  );
  v_completed := case
    when v_resolved_role = 'guru_bk' then true
    else coalesce(p_is_profile_completed, false)
      and v_final_name <> ''
      and v_final_class <> ''
      and v_final_school_name <> ''
  end;
  v_short_name := coalesce(
    nullif(trim(coalesce(p_short_name, '')), ''),
    split_part(v_final_name, ' ', 1)
  );

  v_avatar_preset := coalesce(nullif(trim(coalesce(p_avatar_preset, '')), ''), 'indigo');
  v_avatar_url := trim(coalesce(p_avatar_url, ''));
  v_gender := case
    when coalesce(p_gender, '') in ('L', 'P', 'other') then p_gender
    else ''
  end;
  v_education_level := case
    when upper(trim(coalesce(p_education_level, ''))) in ('SMP', 'SMA', 'SMK', 'MA')
      then upper(trim(p_education_level))
    else ''
  end;
  v_homeroom_teacher := trim(coalesce(p_homeroom_teacher, ''));
  v_phone_number := trim(coalesce(p_phone_number, ''));
  v_parent_name := trim(coalesce(p_parent_name, ''));
  v_preferred_contact := case
    when coalesce(p_preferred_contact_method, '') in ('ruang_bk', 'whatsapp', 'orang_tua', 'aplikasi')
      then p_preferred_contact_method
    else 'ruang_bk'
  end;
  v_safety_note := left(trim(coalesce(p_safety_note, '')), 160);

  insert into public.profiles (
    id, school_id, name, short_name, class_name, school_name, email, role,
    is_private_mode, is_disguised_mode, is_profile_completed,
    avatar_preset, avatar_url, gender, birth_date, education_level,
    homeroom_teacher, phone_number, parent_name, preferred_contact_method,
    safety_note, updated_at
  )
  values (
    v_uid, v_school_id,
    v_final_name,
    v_short_name,
    v_final_class,
    v_final_school_name,
    coalesce(nullif(v_jwt_email, ''), coalesce(p_email, '')),
    v_resolved_role,
    false,
    p_is_disguised_mode,
    v_completed,
    v_avatar_preset,
    v_avatar_url,
    v_gender,
    p_birth_date,
    v_education_level,
    v_homeroom_teacher,
    v_phone_number,
    v_parent_name,
    v_preferred_contact,
    v_safety_note,
    now()
  )
  on conflict (id) do update set
    school_id = coalesce(excluded.school_id, public.profiles.school_id),
    name = case when excluded.name <> '' then excluded.name else public.profiles.name end,
    short_name = case when p_short_name is not null and excluded.short_name <> '' then excluded.short_name else public.profiles.short_name end,
    class_name = case when excluded.class_name <> '' then excluded.class_name else public.profiles.class_name end,
    school_name = case when excluded.school_name <> '' then excluded.school_name else public.profiles.school_name end,
    email = case when excluded.email <> '' then excluded.email else public.profiles.email end,
    role = excluded.role,
    is_private_mode = false,
    is_disguised_mode = excluded.is_disguised_mode,
    is_profile_completed = excluded.is_profile_completed,
    avatar_preset = case when p_avatar_preset is not null then excluded.avatar_preset else public.profiles.avatar_preset end,
    avatar_url = case when p_avatar_url is not null then excluded.avatar_url else public.profiles.avatar_url end,
    gender = case when p_gender is not null then excluded.gender else public.profiles.gender end,
    birth_date = case when p_avatar_preset is not null or p_birth_date is not null then p_birth_date else public.profiles.birth_date end,
    education_level = case when p_education_level is not null then excluded.education_level else public.profiles.education_level end,
    homeroom_teacher = case when p_homeroom_teacher is not null then excluded.homeroom_teacher else public.profiles.homeroom_teacher end,
    phone_number = case when p_phone_number is not null then excluded.phone_number else public.profiles.phone_number end,
    parent_name = case when p_parent_name is not null then excluded.parent_name else public.profiles.parent_name end,
    preferred_contact_method = case when p_preferred_contact_method is not null then excluded.preferred_contact_method else public.profiles.preferred_contact_method end,
    safety_note = case when p_safety_note is not null then excluded.safety_note else public.profiles.safety_note end,
    updated_at = now();

  if v_resolved_role = 'guru_bk' and v_school_id is not null then
    insert into public.staff (user_id, school_id, full_name, role, phone)
    values (
      v_uid,
      v_school_id,
      coalesce(nullif(v_final_name, ''), 'Bu Rina, S.Pd.'),
      'guru_bk',
      nullif(v_phone_number, '')
    )
    on conflict (user_id) do update set
      school_id = excluded.school_id,
      full_name = excluded.full_name,
      role = 'guru_bk',
      phone = coalesce(excluded.phone, public.staff.phone);
  else
    delete from public.staff where user_id = v_uid;
  end if;

  return jsonb_build_object(
    'id', v_uid,
    'school_id', v_school_id,
    'school_slug', coalesce(v_school_slug, 'sman1-nusantara'),
    'school_name', coalesce(nullif(v_final_school_name, ''), coalesce(v_default_school_name, 'SMAN 1 Nusantara')),
    'counselor_name', coalesce(v_counselor_name, 'Bu Rina, S.Pd.'),
    'counselor_phone', coalesce(nullif(v_counselor_phone, ''), '089686899447'),
    'role', v_resolved_role,
    'is_profile_completed', v_completed
  );
end;
$$;

-- Private storage bucket for user profile avatars
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

drop policy if exists avatars_owner_select on storage.objects;
create policy avatars_owner_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists avatars_owner_insert on storage.objects;
create policy avatars_owner_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists avatars_owner_update on storage.objects;
create policy avatars_owner_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists avatars_owner_delete on storage.objects;
create policy avatars_owner_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

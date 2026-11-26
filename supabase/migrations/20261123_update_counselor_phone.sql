-- supabase/migrations/20261123_update_counselor_phone.sql
-- Ensure default school row exists with Bu Rina (Guru BK) phone 089686899447
-- and return counselor_phone from upsert_my_profile.

drop index if exists public.schools_slug_uidx;
create unique index schools_slug_uidx on public.schools (slug);

insert into public.schools (slug, name, city, counselor_name, counselor_phone)
values ('sman1-nusantara', 'SMAN 1 Nusantara', 'Jakarta', 'Bu Rina, S.Pd.', '089686899447')
on conflict (slug) do update set
  counselor_name = excluded.counselor_name,
  counselor_phone = excluded.counselor_phone;

update public.schools
set counselor_phone = '089686899447'
where slug = 'sman1-nusantara'
   or counselor_name ilike '%Bu Rina%';

create or replace function public.upsert_my_profile(
  p_name text,
  p_class_name text,
  p_school_slug text default 'sman1-nusantara',
  p_is_private_mode boolean default false,
  p_is_disguised_mode boolean default false,
  p_role text default 'siswa',
  p_email text default null,
  p_school_name text default null,
  p_is_profile_completed boolean default true
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
begin
  if v_uid is null then
    raise exception 'unauthorized';
  end if;

  select exists (select 1 from public.staff where user_id = v_uid)
  into v_is_existing_staff;

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
  v_short_name := split_part(v_final_name, ' ', 1);

  insert into public.profiles (
    id, school_id, name, short_name, class_name, school_name, email, role,
    is_private_mode, is_disguised_mode, is_profile_completed, updated_at
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
    now()
  )
  on conflict (id) do update set
    school_id = coalesce(excluded.school_id, public.profiles.school_id),
    name = case when excluded.name <> '' then excluded.name else public.profiles.name end,
    short_name = case when excluded.short_name <> '' then excluded.short_name else public.profiles.short_name end,
    class_name = case when excluded.class_name <> '' then excluded.class_name else public.profiles.class_name end,
    school_name = case when excluded.school_name <> '' then excluded.school_name else public.profiles.school_name end,
    email = case when excluded.email <> '' then excluded.email else public.profiles.email end,
    role = excluded.role,
    is_private_mode = false,
    is_disguised_mode = excluded.is_disguised_mode,
    is_profile_completed = excluded.is_profile_completed,
    updated_at = now();

  if v_resolved_role = 'guru_bk' and v_school_id is not null then
    insert into public.staff (user_id, school_id, full_name, role)
    values (v_uid, v_school_id, coalesce(nullif(v_final_name, ''), 'Bu Rina, S.Pd.'), 'guru_bk')
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
    'school_name', coalesce(nullif(v_final_school_name, ''), coalesce(v_default_school_name, 'SMAN 1 Nusantara')),
    'counselor_name', coalesce(v_counselor_name, 'Bu Rina, S.Pd.'),
    'counselor_phone', coalesce(nullif(trim(coalesce(v_counselor_phone, '')), ''), '089686899447'),
    'role', v_resolved_role,
    'is_profile_completed', v_completed
  );
end;
$$;

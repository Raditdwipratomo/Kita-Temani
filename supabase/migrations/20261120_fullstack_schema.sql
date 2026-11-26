-- supabase/migrations/20261120_fullstack_schema.sql
-- Fullstack PostgreSQL schema, RLS policies, indexes, storage policies, and RPCs for KitaTemani
-- Module Arsip Rahasia dihapus sementara sesuai fase implementasi saat ini.

create extension if not exists pgcrypto;

-- 1. Schools (extend existing table)
alter table public.schools
  add column if not exists slug text,
  add column if not exists city text not null default 'Indonesia',
  add column if not exists counselor_name text not null default 'Guru BK Mitra',
  add column if not exists counselor_phone text,
  add column if not exists created_at timestamptz not null default now();

drop index if exists public.schools_slug_uidx;
create unique index if not exists schools_slug_uidx on public.schools (slug);

alter table public.schools enable row level security;
drop policy if exists schools_public_read on public.schools;
create policy schools_public_read on public.schools
  for select
  to anon, authenticated
  using (true);

-- 2. Profiles (allow nullable school_id for mode pribadi & add full profile fields)
alter table public.profiles
  alter column school_id drop not null,
  add column if not exists short_name text not null default '',
  add column if not exists email text not null default '',
  add column if not exists is_private_mode boolean not null default false,
  add column if not exists is_disguised_mode boolean not null default false,
  add column if not exists safe_days_count integer not null default 1,
  add column if not exists fcm_token text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check check (role in ('siswa', 'guru_bk', 'wali_kelas', 'admin'));

create index if not exists profiles_school_id_idx on public.profiles (school_id);

alter table public.profiles enable row level security;
drop policy if exists profiles_owner_select on public.profiles;
create policy profiles_owner_select on public.profiles
  for select to authenticated
  using ((select auth.uid()) = id);

drop policy if exists profiles_owner_insert on public.profiles;
create policy profiles_owner_insert on public.profiles
  for insert to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists profiles_owner_update on public.profiles;
create policy profiles_owner_update on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- 3. Staff (Counselors / Teachers per school)
alter table public.staff
  add column if not exists full_name text not null default 'Guru BK',
  add column if not exists phone text,
  add column if not exists created_at timestamptz not null default now();

create index if not exists staff_school_id_idx on public.staff (school_id);

alter table public.staff enable row level security;
drop policy if exists staff_self_read on public.staff;
create policy staff_self_read on public.staff
  for select to authenticated
  using ((select auth.uid()) = user_id);

-- 4. Reports (extend base table cleanly)
alter table public.reports
  alter column school_id drop not null,
  add column if not exists reporter_id uuid references auth.users (id) on delete set null,
  add column if not exists is_victim boolean not null default true,
  add column if not exists is_anonymous boolean not null default true,
  add column if not exists evidence_link text,
  add column if not exists updated_at timestamptz not null default now();

create index if not exists reports_school_created_idx on public.reports (school_id, created_at desc);
create index if not exists reports_reporter_id_idx on public.reports (reporter_id);
create index if not exists reports_code_idx on public.reports (code);

drop policy if exists counselor_read on public.reports;
create policy counselor_read on public.reports
  for select to authenticated
  using (
    exists (
      select 1 from public.staff s
      where s.user_id = (select auth.uid())
        and s.school_id = reports.school_id
    )
  );

drop policy if exists reporter_read on public.reports;
create policy reporter_read on public.reports
  for select to authenticated
  using ((select auth.uid()) = reporter_id);

drop policy if exists counselor_update on public.reports;
create policy counselor_update on public.reports
  for update to authenticated
  using (
    exists (
      select 1 from public.staff s
      where s.user_id = (select auth.uid())
        and s.school_id = reports.school_id
    )
  )
  with check (
    exists (
      select 1 from public.staff s
      where s.user_id = (select auth.uid())
        and s.school_id = reports.school_id
    )
  );

-- 5. Report Attachments
create table if not exists public.report_attachments (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports (id) on delete cascade,
  storage_path text not null,
  file_name text not null,
  kind text not null default 'foto' check (kind in ('foto', 'video', 'suara', 'file')),
  created_at timestamptz not null default now()
);

create index if not exists report_attachments_report_idx on public.report_attachments (report_id);

alter table public.report_attachments enable row level security;
drop policy if exists report_attachments_access on public.report_attachments;
create policy report_attachments_access on public.report_attachments
  for select to authenticated
  using (
    exists (
      select 1 from public.reports r
      where r.id = report_attachments.report_id
        and (
          r.reporter_id = (select auth.uid())
          or exists (
            select 1 from public.staff s
            where s.user_id = (select auth.uid())
              and s.school_id = r.school_id
          )
        )
    )
  );

-- 6. Report Status History
create table if not exists public.report_status_history (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports (id) on delete cascade,
  status text not null check (status in ('diterima', 'ditinjau', 'tindak_lanjut', 'selesai')),
  title text not null,
  description text not null default '',
  changed_by uuid references auth.users (id) on delete set null,
  changed_at timestamptz not null default now()
);

create index if not exists report_status_history_report_idx on public.report_status_history (report_id, changed_at asc);

alter table public.report_status_history enable row level security;
drop policy if exists report_status_history_access on public.report_status_history;
create policy report_status_history_access on public.report_status_history
  for select to authenticated
  using (
    exists (
      select 1 from public.reports r
      where r.id = report_status_history.report_id
        and (
          r.reporter_id = (select auth.uid())
          or exists (
            select 1 from public.staff s
            where s.user_id = (select auth.uid())
              and s.school_id = r.school_id
          )
        )
    )
  );

-- 7. Two-way Private Discussion Messages between Pelapor and Guru BK
create table if not exists public.report_messages (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  sender_role text not null check (sender_role in ('siswa', 'guru_bk')),
  sender_label text not null,
  content text not null check (char_length(content) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists report_messages_report_idx on public.report_messages (report_id, created_at asc);

alter table public.report_messages enable row level security;
drop policy if exists report_messages_read on public.report_messages;
create policy report_messages_read on public.report_messages
  for select to authenticated
  using (
    exists (
      select 1 from public.reports r
      where r.id = report_messages.report_id
        and (
          r.reporter_id = (select auth.uid())
          or exists (
            select 1 from public.staff s
            where s.user_id = (select auth.uid())
              and s.school_id = r.school_id
          )
        )
    )
  );

drop policy if exists report_messages_insert on public.report_messages;
create policy report_messages_insert on public.report_messages
  for insert to authenticated
  with check (
    (select auth.uid()) = sender_id
    and exists (
      select 1 from public.reports r
      where r.id = report_messages.report_id
        and (
          r.reporter_id = (select auth.uid())
          or exists (
            select 1 from public.staff s
            where s.user_id = (select auth.uid())
              and s.school_id = r.school_id
          )
        )
    )
  );

-- 8. Emergency Contacts (max 5 per user enforced via trigger)
create table if not exists public.emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 100),
  role_label text not null check (char_length(role_label) between 1 and 60),
  phone text not null check (char_length(phone) between 6 and 30),
  is_active boolean not null default true,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists emergency_contacts_user_idx on public.emergency_contacts (user_id);

alter table public.emergency_contacts enable row level security;
drop policy if exists emergency_contacts_owner_all on public.emergency_contacts;
create policy emergency_contacts_owner_all on public.emergency_contacts
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create or replace function public.enforce_emergency_contact_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if (tg_op = 'INSERT') then
    select count(*) into v_count
    from public.emergency_contacts
    where user_id = new.user_id;

    if v_count >= 5 then
      raise exception 'Maksimal 5 kontak darurat per akun.';
    end if;
  end if;

  if new.is_primary then
    update public.emergency_contacts
    set is_primary = false
    where user_id = new.user_id
      and id <> new.id
      and is_primary = true;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_emergency_contacts_limit on public.emergency_contacts;
create trigger trg_emergency_contacts_limit
  before insert or update on public.emergency_contacts
  for each row execute function public.enforce_emergency_contact_limit();

-- 9. Panic Events
create table if not exists public.panic_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  school_id uuid references public.schools (id) on delete set null,
  student_name text not null,
  class_name text not null default '',
  lat double precision,
  lng double precision,
  accuracy_m double precision,
  location_label text not null default '',
  message_text text not null default '',
  audio_storage_path text,
  contact_deliveries jsonb not null default '[]'::jsonb,
  status text not null default 'active' check (status in ('active', 'resolved')),
  started_at timestamptz not null default now(),
  ended_at timestamptz
);

create index if not exists panic_events_school_started_idx on public.panic_events (school_id, started_at desc);
create index if not exists panic_events_user_idx on public.panic_events (user_id, started_at desc);

alter table public.panic_events enable row level security;
drop policy if exists panic_events_owner_all on public.panic_events;
create policy panic_events_owner_all on public.panic_events
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists panic_events_staff_read on public.panic_events;
create policy panic_events_staff_read on public.panic_events
  for select to authenticated
  using (
    exists (
      select 1 from public.staff s
      where s.user_id = (select auth.uid())
        and s.school_id = panic_events.school_id
    )
  );

drop policy if exists panic_events_staff_update on public.panic_events;
create policy panic_events_staff_update on public.panic_events
  for update to authenticated
  using (
    exists (
      select 1 from public.staff s
      where s.user_id = (select auth.uid())
        and s.school_id = panic_events.school_id
    )
  );

-- 10. Education Articles (Kenali bullying di Beranda)
create table if not exists public.education_articles (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  body text not null,
  read_minutes integer not null default 3,
  accent_color text not null default '#585FE6',
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.education_articles enable row level security;
drop policy if exists education_articles_public_read on public.education_articles;
create policy education_articles_public_read on public.education_articles
  for select to anon, authenticated
  using (true);

-- 11. School AI Summaries
create table if not exists public.school_summaries (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  period text not null default '7d',
  risk_cases integer not null default 0,
  online_cases integer not null default 0,
  summary_text text not null,
  recommendation text not null,
  generated_at timestamptz not null default now(),
  unique (school_id, period)
);

alter table public.school_summaries enable row level security;
drop policy if exists school_summaries_school_read on public.school_summaries;
create policy school_summaries_school_read on public.school_summaries
  for select to authenticated
  using (
    exists (
      select 1 from public.staff s
      where s.user_id = (select auth.uid())
        and s.school_id = school_summaries.school_id
    )
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.school_id = school_summaries.school_id
    )
  );

-- 12. App Notifications
create table if not exists public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  body text not null,
  kind text not null default 'info',
  ref_code text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists app_notifications_user_idx on public.app_notifications (user_id, created_at desc);

alter table public.app_notifications enable row level security;
drop policy if exists app_notifications_owner_all on public.app_notifications;
create policy app_notifications_owner_all on public.app_notifications
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- 13. Private Storage Bucket for Evidence & Panic Audio
insert into storage.buckets (id, name, public)
values ('evidence', 'evidence', false)
on conflict (id) do nothing;

drop policy if exists evidence_owner_upload on storage.objects;
create policy evidence_owner_upload on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'evidence'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists evidence_owner_or_staff_read on storage.objects;
create policy evidence_owner_or_staff_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'evidence'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (
        select 1 from public.report_attachments ra
        join public.reports r on r.id = ra.report_id
        join public.staff s on s.school_id = r.school_id
        where ra.storage_path = name
          and s.user_id = (select auth.uid())
      )
      or exists (
        select 1 from public.panic_events pe
        join public.staff s on s.school_id = pe.school_id
        where pe.audio_storage_path = name
          and s.user_id = (select auth.uid())
      )
    )
  );

-- 14. RPC Functions
drop function if exists public.submit_report(uuid, uuid, text[], timestamptz, text, text);

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

  -- Only the 1 designated Guru BK account (or pre-assigned staff row) gets counselor role.
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

create or replace function public.submit_report(
  p_idempotency_key uuid,
  p_school_ref text,
  p_types text[],
  p_occurred_at timestamptz,
  p_location text,
  p_narrative text,
  p_evidence_link text default null,
  p_is_victim boolean default true,
  p_is_anonymous boolean default true,
  p_attachments jsonb default '[]'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_school_id uuid;
  v_report_id uuid;
  v_code text;
  v_item jsonb;
begin
  if v_uid is null then
    raise exception 'unauthorized';
  end if;

  select id, code into v_report_id, v_code
  from public.reports
  where idempotency_key = p_idempotency_key;

  if v_code is not null then
    return jsonb_build_object('id', v_report_id, 'code', v_code);
  end if;

  if coalesce(p_school_ref, '') <> '' and p_school_ref <> 'private-mode' then
    select id into v_school_id
    from public.schools
    where slug = p_school_ref or id::text = p_school_ref
    limit 1;
  end if;

  if v_school_id is null then
    select school_id into v_school_id from public.profiles where id = v_uid;
  end if;

  v_code := 'KT-'
    || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 4))
    || '-'
    || upper(substr(replace(gen_random_uuid()::text, '-', ''), 5, 4));

  insert into public.reports (
    idempotency_key, code, school_id, reporter_id, is_victim, is_anonymous,
    types, occurred_at, location, narrative, evidence_link, status
  ) values (
    p_idempotency_key, v_code, v_school_id, v_uid, coalesce(p_is_victim, true),
    coalesce(p_is_anonymous, true), p_types, p_occurred_at, p_location,
    p_narrative, nullif(trim(coalesce(p_evidence_link, '')), ''), 'diterima'
  )
  returning id into v_report_id;

  insert into public.report_status_history (report_id, status, title, description, changed_by)
  values (
    v_report_id,
    'diterima',
    'Laporan Diterima',
    'Laporan masuk secara privat & terenkripsi ke ruang Guru BK sekolah.',
    v_uid
  );

  if jsonb_typeof(p_attachments) = 'array' then
    for v_item in select * from jsonb_array_elements(p_attachments)
    loop
      insert into public.report_attachments (report_id, storage_path, file_name, kind)
      values (
        v_report_id,
        coalesce(v_item->>'storage_path', v_item->>'file_name', ''),
        coalesce(v_item->>'file_name', 'bukti_lampiran'),
        case
          when (v_item->>'kind') in ('foto', 'video', 'suara', 'file') then (v_item->>'kind')
          else 'foto'
        end
      );
    end loop;
  end if;

  if v_school_id is not null then
    insert into public.app_notifications (user_id, title, body, kind, ref_code)
    select
      s.user_id,
      'Laporan Baru Masuk (' || v_code || ')',
      'Laporan perundungan di ' || p_location || ' menunggu peninjauan Guru BK.',
      'report_new',
      v_code
    from public.staff s
    where s.school_id = v_school_id;
  end if;

  return jsonb_build_object('id', v_report_id, 'code', v_code);
end;
$$;

create or replace function public.get_my_reports(p_codes text[] default '{}'::text[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_result jsonb;
begin
  if v_uid is null then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(item order by item_created_at desc), '[]'::jsonb)
  into v_result
  from (
    select
      r.created_at as item_created_at,
      jsonb_build_object(
        'id', r.id,
        'code', r.code,
        'types', r.types,
        'occurred_at', r.occurred_at,
        'location', r.location,
        'narrative', r.narrative,
        'evidence_link', r.evidence_link,
        'status', r.status,
        'is_victim', r.is_victim,
        'created_at', r.created_at,
        'attachments', coalesce(
          (select jsonb_agg(ra.file_name order by ra.created_at asc)
           from public.report_attachments ra where ra.report_id = r.id),
          '[]'::jsonb
        ),
        'has_counselor_message', exists (
          select 1 from public.report_messages rm
          where rm.report_id = r.id and rm.sender_role = 'guru_bk'
        )
      ) as item
    from public.reports r
    where r.reporter_id = v_uid
       or (coalesce(array_length(p_codes, 1), 0) > 0 and r.code = any(p_codes))
  ) sub;

  return v_result;
end;
$$;

create or replace function public.get_school_reports()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_school_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    return '[]'::jsonb;
  end if;

  select school_id into v_school_id from public.staff where user_id = v_uid limit 1;
  if v_school_id is null then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(item order by item_created_at desc), '[]'::jsonb)
  into v_result
  from (
    select
      r.created_at as item_created_at,
      jsonb_build_object(
        'id', r.id,
        'code', r.code,
        'types', r.types,
        'occurred_at', r.occurred_at,
        'location', r.location,
        'narrative', r.narrative,
        'evidence_link', r.evidence_link,
        'status', r.status,
        'is_victim', r.is_victim,
        'created_at', r.created_at,
        'attachments', coalesce(
          (select jsonb_agg(ra.file_name order by ra.created_at asc)
           from public.report_attachments ra where ra.report_id = r.id),
          '[]'::jsonb
        )
      ) as item
    from public.reports r
    where r.school_id = v_school_id
  ) sub;

  return v_result;
end;
$$;

create or replace function public.advance_report_status(
  p_code text,
  p_next_status text default null,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_report public.reports%rowtype;
  v_target_status text;
  v_title text;
  v_desc text;
begin
  if v_uid is null then
    raise exception 'unauthorized';
  end if;

  select * into v_report from public.reports where code = p_code limit 1;
  if not found then
    raise exception 'report_not_found';
  end if;

  if not exists (
    select 1 from public.staff s
    where s.user_id = v_uid and (v_report.school_id is null or s.school_id = v_report.school_id)
  ) then
    raise exception 'forbidden_not_counselor';
  end if;

  v_target_status := coalesce(
    p_next_status,
    case v_report.status
      when 'diterima' then 'ditinjau'
      when 'ditinjau' then 'tindak_lanjut'
      when 'tindak_lanjut' then 'selesai'
      else 'selesai'
    end
  );

  v_title := case v_target_status
    when 'ditinjau' then 'Ditinjau Guru BK'
    when 'tindak_lanjut' then 'Tindak Lanjut Sekolah'
    when 'selesai' then 'Laporan Selesai Ditangani'
    else 'Laporan Diterima'
  end;

  v_desc := coalesce(
    nullif(trim(coalesce(p_note, '')), ''),
    case v_target_status
      when 'ditinjau' then 'Guru BK telah membuka laporan dan memulai verifikasi awal.'
      when 'tindak_lanjut' then 'Pendampingan dan penanganan aman sedang berjalan di sekolah.'
      when 'selesai' then 'Penanganan kasus dinyatakan selesai dengan pemantauan berkala.'
      else 'Laporan tercatat di ruang BK.'
    end
  );

  update public.reports
  set status = v_target_status, updated_at = now()
  where id = v_report.id;

  insert into public.report_status_history (report_id, status, title, description, changed_by)
  values (v_report.id, v_target_status, v_title, v_desc, v_uid);

  if v_report.reporter_id is not null then
    insert into public.app_notifications (user_id, title, body, kind, ref_code)
    values (
      v_report.reporter_id,
      'Pembaruan Status ' || v_report.code,
      'Status laporanmu kini: ' || v_title,
      'report_status',
      v_report.code
    );
  end if;

  return jsonb_build_object('code', v_report.code, 'status', v_target_status);
end;
$$;

create or replace function public.get_report_detail(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_report public.reports%rowtype;
  v_is_staff boolean := false;
  v_school_name text := 'Sekolah Mitra';
begin
  if v_uid is null then
    raise exception 'unauthorized';
  end if;

  select * into v_report from public.reports where code = p_code limit 1;
  if not found then
    return null;
  end if;

  select exists (
    select 1 from public.staff s
    where s.user_id = v_uid and (v_report.school_id is null or s.school_id = v_report.school_id)
  ) into v_is_staff;

  if not v_is_staff and v_report.reporter_id is not null and v_report.reporter_id <> v_uid then
    raise exception 'forbidden';
  end if;

  if v_report.school_id is not null then
    select name into v_school_name from public.schools where id = v_report.school_id;
  end if;

  return jsonb_build_object(
    'id', v_report.id,
    'code', v_report.code,
    'school_name', v_school_name,
    'types', v_report.types,
    'occurred_at', v_report.occurred_at,
    'location', v_report.location,
    'narrative', v_report.narrative,
    'evidence_link', v_report.evidence_link,
    'status', v_report.status,
    'created_at', v_report.created_at,
    'attachments', coalesce(
      (select jsonb_agg(jsonb_build_object(
        'file_name', ra.file_name,
        'storage_path', ra.storage_path,
        'kind', ra.kind
      ) order by ra.created_at asc)
      from public.report_attachments ra where ra.report_id = v_report.id),
      '[]'::jsonb
    ),
    'history', coalesce(
      (select jsonb_agg(jsonb_build_object(
        'status', h.status,
        'title', h.title,
        'description', h.description,
        'changed_at', h.changed_at
      ) order by h.changed_at asc)
      from public.report_status_history h where h.report_id = v_report.id),
      '[]'::jsonb
    ),
    'messages', coalesce(
      (select jsonb_agg(jsonb_build_object(
        'id', m.id,
        'sender_role', m.sender_role,
        'sender_label', m.sender_label,
        'content', m.content,
        'created_at', m.created_at
      ) order by m.created_at asc)
      from public.report_messages m where m.report_id = v_report.id),
      '[]'::jsonb
    )
  );
end;
$$;

create or replace function public.send_report_message(
  p_code text,
  p_content text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_report public.reports%rowtype;
  v_profile public.profiles%rowtype;
  v_is_staff boolean := false;
  v_sender_role text;
  v_sender_label text;
  v_msg_id uuid;
begin
  if v_uid is null then
    raise exception 'unauthorized';
  end if;

  select * into v_report from public.reports where code = p_code limit 1;
  if not found then
    raise exception 'report_not_found';
  end if;

  select * into v_profile from public.profiles where id = v_uid;
  select exists (
    select 1 from public.staff s
    where s.user_id = v_uid and (v_report.school_id is null or s.school_id = v_report.school_id)
  ) into v_is_staff;

  if not v_is_staff and v_report.reporter_id is not null and v_report.reporter_id <> v_uid then
    raise exception 'forbidden';
  end if;

  if v_is_staff then
    v_sender_role := 'guru_bk';
    v_sender_label := coalesce(nullif(v_profile.name, ''), 'Guru BK') || ' · Guru BK';
  else
    v_sender_role := 'siswa';
    v_sender_label := coalesce(nullif(v_profile.name, ''), 'Siswa')
      || case when coalesce(v_profile.class_name, '') <> '' then ' (' || v_profile.class_name || ')' else '' end;
  end if;

  insert into public.report_messages (report_id, sender_id, sender_role, sender_label, content)
  values (v_report.id, v_uid, v_sender_role, v_sender_label, trim(p_content))
  returning id into v_msg_id;

  if v_sender_role = 'guru_bk' and v_report.reporter_id is not null then
    insert into public.app_notifications (user_id, title, body, kind, ref_code)
    values (
      v_report.reporter_id,
      'Pesan Baru Guru BK (' || v_report.code || ')',
      left(trim(p_content), 120),
      'report_message',
      v_report.code
    );
  elsif v_sender_role = 'siswa' and v_report.school_id is not null then
    insert into public.app_notifications (user_id, title, body, kind, ref_code)
    select s.user_id, 'Balasan Siswa (' || v_report.code || ')', left(trim(p_content), 120), 'report_message', v_report.code
    from public.staff s where s.school_id = v_report.school_id;
  end if;

  return jsonb_build_object(
    'id', v_msg_id,
    'sender_role', v_sender_role,
    'sender_label', v_sender_label,
    'content', trim(p_content),
    'created_at', now()
  );
end;
$$;

create or replace function public.resolve_panic_event(
  p_event_id uuid,
  p_audio_storage_path text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'unauthorized';
  end if;

  update public.panic_events
  set
    status = 'resolved',
    ended_at = now(),
    audio_storage_path = coalesce(nullif(p_audio_storage_path, ''), audio_storage_path)
  where id = p_event_id and user_id = v_uid;

  return jsonb_build_object('ok', true, 'id', p_event_id);
end;
$$;

-- Enable Realtime on live tables cleanly
do $$
begin
  alter publication supabase_realtime add table public.reports;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.report_messages;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.panic_events;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.app_notifications;
exception when duplicate_object then null;
end $$;

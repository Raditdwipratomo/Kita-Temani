-- supabase/migrations/20261109_reports.sql
create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null
);

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  school_id uuid not null references public.schools (id),
  name text not null,
  class_name text not null,
  role text not null default 'siswa'
);

create table if not exists public.staff (
  user_id uuid primary key references auth.users (id) on delete cascade,
  school_id uuid not null references public.schools (id),
  role text not null check (role in ('guru_bk', 'wali_kelas'))
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  idempotency_key uuid not null unique,
  code text not null unique,
  school_id uuid not null references public.schools (id),
  types text[] not null check (types <@ array['fisik','verbal','sosial','siber']),
  occurred_at timestamptz not null,
  location text not null,
  narrative text not null check (char_length(narrative) between 10 and 5000),
  status text not null default 'diterima'
    check (status in ('diterima','ditinjau','tindak_lanjut','selesai')),
  created_at timestamptz not null default now()
); -- tidak ada kolom pelapor

alter table public.reports enable row level security;

create policy counselor_read on public.reports for select
  using (exists (
    select 1 from public.staff s
    where s.user_id = auth.uid() and s.school_id = reports.school_id
  ));

create or replace function public.submit_report(
  p_idempotency_key uuid, p_school_id uuid, p_types text[],
  p_occurred_at timestamptz, p_location text, p_narrative text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if not exists (select 1 from profiles where id = auth.uid() and school_id = p_school_id) then
    raise exception 'forbidden';
  end if;

  select code into v_code from reports where idempotency_key = p_idempotency_key;
  if v_code is not null then
    return jsonb_build_object('code', v_code);
  end if;

  v_code := 'KT-' || to_char(now(), 'MMDD') || '-' || lpad((floor(random() * 10000))::int::text, 4, '0');
  insert into reports (idempotency_key, code, school_id, types, occurred_at, location, narrative)
  values (p_idempotency_key, v_code, p_school_id, p_types, p_occurred_at, p_location, p_narrative);
  return jsonb_build_object('code', v_code);
end $$;

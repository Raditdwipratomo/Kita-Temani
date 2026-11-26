-- supabase/migrations/20261127_report_parties_and_doc_limit.sql
-- Adds perpetrator_names & victim_name columns to public.reports
-- and updates submit_report, get_my_reports, get_school_reports, and get_report_detail RPCs.

alter table public.reports
  add column if not exists perpetrator_names text not null default '',
  add column if not exists victim_name text not null default '';

-- Drop previous 10-arg signature so PostgREST sees a single canonical submit_report RPC.
drop function if exists public.submit_report(
  uuid,
  text,
  text[],
  timestamptz,
  text,
  text,
  text,
  boolean,
  boolean,
  jsonb
);

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
  p_attachments jsonb default '[]'::jsonb,
  p_perpetrator_names text default '',
  p_victim_name text default ''
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
    idempotency_key,
    code,
    school_id,
    reporter_id,
    is_victim,
    is_anonymous,
    types,
    occurred_at,
    location,
    narrative,
    perpetrator_names,
    victim_name,
    evidence_link,
    status
  ) values (
    p_idempotency_key,
    v_code,
    v_school_id,
    v_uid,
    coalesce(p_is_victim, true),
    coalesce(p_is_anonymous, true),
    p_types,
    p_occurred_at,
    p_location,
    p_narrative,
    trim(coalesce(p_perpetrator_names, '')),
    trim(coalesce(p_victim_name, '')),
    nullif(trim(coalesce(p_evidence_link, '')), ''),
    'diterima'
  )
  returning id into v_report_id;

  insert into public.report_status_history (report_id, status, title, description, changed_by)
  values (
    v_report_id,
    'diterima',
    'Laporan Dikirim',
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
          else 'file'
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
        'perpetrator_names', r.perpetrator_names,
        'victim_name', r.victim_name,
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
        'perpetrator_names', r.perpetrator_names,
        'victim_name', r.victim_name,
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
    'perpetrator_names', v_report.perpetrator_names,
    'victim_name', v_report.victim_name,
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

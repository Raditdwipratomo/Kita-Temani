-- supabase/migrations/20261128_report_detail_is_victim.sql
-- Ensures get_report_detail RPC also returns is_victim so ReportDetailScreen
-- matches ReportReviewScreen's Peran pelapor field accurately.

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
    'is_victim', v_report.is_victim,
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

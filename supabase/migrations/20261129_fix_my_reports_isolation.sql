-- supabase/migrations/20261129_fix_my_reports_isolation.sql
-- Ensures get_my_reports strictly returns only reports created by the
-- authenticated user (r.reporter_id = auth.uid()) and never leaks reports
-- belonging to another reporter_id even if p_codes contains foreign codes.

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
       or (
         r.reporter_id is null
         and coalesce(array_length(p_codes, 1), 0) > 0
         and r.code = any(p_codes)
       )
  ) sub;

  return v_result;
end;
$$;

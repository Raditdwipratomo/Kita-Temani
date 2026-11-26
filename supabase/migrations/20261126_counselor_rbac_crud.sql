-- Migration: Counselor RBAC & Article CRUD + 4-Stage Report Status Workflow
-- Standardizes report status labels (Dikirim -> Dibaca -> Ditindak -> Selesai)
-- and grants Guru BK / Wali Kelas staff full CRUD access on education_articles.

-- 1. Helper predicate for staff check (profiles.role IN ('guru_bk','wali_kelas') OR staff entry)
create or replace function public.is_counselor_or_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role in ('guru_bk', 'wali_kelas')
  )
  or exists (
    select 1
    from public.staff s
    where s.user_id = auth.uid()
  );
$$;

-- 2. RLS policies for Guru BK CRUD on public.education_articles
drop policy if exists "education_articles_staff_insert" on public.education_articles;
create policy "education_articles_staff_insert"
  on public.education_articles
  for insert
  to authenticated
  with check (public.is_counselor_or_staff());

drop policy if exists "education_articles_staff_update" on public.education_articles;
create policy "education_articles_staff_update"
  on public.education_articles
  for update
  to authenticated
  using (public.is_counselor_or_staff())
  with check (public.is_counselor_or_staff());

drop policy if exists "education_articles_staff_delete" on public.education_articles;
create policy "education_articles_staff_delete"
  on public.education_articles
  for delete
  to authenticated
  using (public.is_counselor_or_staff());

-- 3. Update advance_report_status RPC with standardized 4-stage titles
create or replace function public.advance_report_status(
  p_code text,
  p_new_status text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.reports%rowtype;
  v_title text;
  v_description text;
begin
  if not public.is_counselor_or_staff() then
    raise exception 'Hanya Guru BK atau Wali Kelas yang dapat memperbarui status laporan';
  end if;

  if p_new_status not in ('diterima', 'ditinjau', 'tindak_lanjut', 'selesai') then
    raise exception 'Status laporan tidak valid: %', p_new_status;
  end if;

  update public.reports
  set status = p_new_status,
      updated_at = now()
  where upper(code) = upper(trim(p_code))
  returning * into v_report;

  if not found then
    raise exception 'Laporan dengan kode % tidak ditemukan', p_code;
  end if;

  v_title := case p_new_status
    when 'diterima' then 'Laporan Dikirim'
    when 'ditinjau' then 'Laporan Dibaca Guru BK'
    when 'tindak_lanjut' then 'Ditindaklanjuti Guru BK'
    when 'selesai' then 'Penanganan Laporan Selesai'
    else 'Status Diperbarui'
  end;

  v_description := coalesce(
    nullif(trim(p_note), ''),
    case p_new_status
      when 'diterima' then 'Laporan diterima di kanal aman Guru BK.'
      when 'ditinjau' then 'Guru BK telah membaca laporan dan mempelajari kronologi.'
      when 'tindak_lanjut' then 'Guru BK sedang melakukan pendampingan atau tindak lanjut.'
      when 'selesai' then 'Penanganan laporan telah selesai dan didokumentasikan.'
      else 'Status laporan diperbarui oleh Guru BK.'
    end
  );

  insert into public.report_status_history (
    report_id,
    status,
    title,
    description,
    updated_by
  ) values (
    v_report.id,
    p_new_status,
    v_title,
    v_description,
    auth.uid()
  );

  return jsonb_build_object(
    'code', v_report.code,
    'status', v_report.status,
    'title', v_title,
    'description', v_description,
    'updated_at', v_report.updated_at
  );
end;
$$;

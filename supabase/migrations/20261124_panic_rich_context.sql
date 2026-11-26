-- supabase/migrations/20261124_panic_rich_context.sql
-- Store richer SOS context (school_name, area_hint, situation_note) on panic_events
-- and add a partial index for fast active-alert queries in Panel Guru BK.

alter table public.panic_events
  add column if not exists school_name text not null default ''
    check (char_length(school_name) <= 160),
  add column if not exists area_hint text not null default ''
    check (char_length(area_hint) <= 120),
  add column if not exists situation_note text not null default ''
    check (char_length(situation_note) <= 240);

create index if not exists panic_events_active_school_idx
  on public.panic_events (school_id, started_at desc)
  where status = 'active';

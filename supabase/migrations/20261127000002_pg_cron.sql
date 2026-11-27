-- =====================================================================
-- PromptIndo — pg_cron scheduled jobs (§5.3)
-- Note: On local Postgres 16 without pg_cron installed, the extension step
-- is skipped if unavailable while cron.schedule() runs against the test stub.
-- On Supabase Cloud / CLI, pg_cron is available and enabled cleanly.
-- =====================================================================

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
  end if;
end $$;

select cron.schedule(
  'recompute-trending',
  '*/15 * * * *',
  $$select public.recompute_trending()$$
);

select cron.schedule(
  'cleanup-prompt-views',
  '17 * * * *',
  $$delete from public.prompt_views where created_at < now() - interval '24 hours'$$
);

-- 20260909121000_reschedule_daily_program_to_7pm.sql
-- generate_daily_program() (20260903171000_daily_program_cron.sql) was
-- scheduled at '0 6 * * *' (06:00 UTC = 07:00 WAT = 7 AM local) but the
-- user's spec is a 7 PM notification, not 7 AM -- an evening heads-up
-- about tomorrow, not a same-morning one. 19:00 WAT == 18:00 UTC
-- (Africa/Douala is UTC+1 year-round, no DST).

do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'daily-program';
end;
$$;

select cron.schedule('daily-program', '0 18 * * *', $$select public.generate_daily_program();$$);

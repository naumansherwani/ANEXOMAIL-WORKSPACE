
-- E89 — Analytics Center ka ASLI backend (26 Oct 2026, founder hukm: "ek bhi wire adhoora nahi"). Phase24 ke 6 tables pehle se hain (sql/phase24_analytics.sql),
--       lekin unhein bharne/padhne wala koi server code nahi tha — screens "not wired" dikhati thin. Ab 7 server functions (service_role-only).
--
-- CEO FORMULA (founder ne tay karne ka haq diya; yahi har jagah likha jata hai, response ke `method` field mein bhi):
--  1) Response debt £  = SUM( min(intezar_ghante, 72) ) x hourly_rate x 0.25
--       intezar = us thread ka aakhri inbound message jab se jawab nahi gaya (inbox, status open, 30 din ke andar, automated sender nahi, apna address nahi).
--       0.25 = jo insaan jawab ka intezar kar raha hai uska ~chauthai kaam ruka rehta hai (context-switch + dobara poochhna). 72h cap: purani thread se debt phat'ta nahi.
--       hourly_rate = analytics_rates ('external' scope, warna 'self', warna £60).  Currency usi row ki.
--  2) Thread economics = minutes = bheji hui mail x 5 + aayi hui mail x 1.5 ; people_hours = minutes / 60 ; cost = people_hours x hourly_rate('self').
--  3) Deep work = kaam ka din 09:00-17:00 (user ka timezone), weekdays; busy = meetings (calendar) + jawab likhne ke 5-minute ke blocks; deep = 60+ minute ke khali tukde.
--  4) Attention leaks = pichhle 7 din mein jis sender ne >= 3 baar mailbox mein aaya; har interruption = 2 minute context-switch.
--  5) Promise SLA = work_tasks (source = 'promise') jinka owner main hoon; kept = waqt par complete, late = der se complete YA due guzar gaya, broken = due ke 48h baad bhi khula.
--  6) Forecast = pichhle 4 haftay ke naye threads, wazan 4/3/2/1 ; hours = threads x average minutes / 60.
--  7) Team = org ke active members, har ek ka debt/keep rate/deep hours ; load: <3 light, <10 healthy, <25 heavy, warna drowning.
-- Package gate Rust mein (analytics_glue.rs): response debt har plan; thread economics + deep work Pro+; leaks/promises/forecast/team Business+. SQL sirf hisaab karta hai.
-- Dobara chalana safe. Server se: sql-run.sh (auto) ya `. /etc/anexomail/sync.env && psql "$WORKING_URL" -v ON_ERROR_STOP=1 -f E89_analytics_backend.sql`
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$ begin
  if to_regclass('public.analytics_rates') is null or to_regclass('public.analytics_debt_daily') is null
     or to_regclass('public.analytics_thread_cost') is null or to_regclass('public.analytics_deep_work') is null
     or to_regclass('public.analytics_attention_leaks') is null then
    raise exception 'E89 PREFLIGHT: analytics tables nahi (sql/phase24_analytics.sql pehle)'; end if;
  if to_regclass('public.mail_threads') is null or to_regclass('public.mail_messages') is null then
    raise exception 'E89 PREFLIGHT: mail_threads / mail_messages nahi (phase52)'; end if;
  if to_regclass('public.calendar_events') is null or to_regclass('public.calendar_attendees') is null or to_regclass('public.work_tasks') is null then
    raise exception 'E89 PREFLIGHT: calendar_events / calendar_attendees / work_tasks nahi (phase61)'; end if;
  if to_regclass('public.org_members') is null then raise exception 'E89 PREFLIGHT: org_members nahi (phase60)'; end if;
end $$;

-- ---------------------------------------------------------------- helpers
create or replace function public.analytics_rate(p_user uuid, p_scope text default 'external')
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'rate', coalesce((select hourly_rate from public.analytics_rates where user_id = p_user and scope = p_scope),
                     (select hourly_rate from public.analytics_rates where user_id = p_user and scope = 'self'), 60.00),
    'currency', coalesce((select currency from public.analytics_rates where user_id = p_user and scope = p_scope),
                         (select currency from public.analytics_rates where user_id = p_user and scope = 'self'), 'GBP'));
$$;

create or replace function public.analytics_waiting(p_addresses text[])
returns table (thread_id uuid, subject text, person text, waiting_h numeric)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select t.id, t.subject, coalesce(nullif(m.from_name, ''), m.from_address),
         round((extract(epoch from (now() - m.sent_at)) / 3600.0)::numeric, 2)
    from public.mail_threads t
    join lateral (select mm.direction, mm.from_address, mm.from_name, mm.sent_at
                    from public.mail_messages mm
                   where mm.thread_id = t.id
                   order by mm.sent_at desc limit 1) m on true
   where lower(t.mailbox_address) in (select lower(x) from unnest(p_addresses) x)
     and t.folder = 'inbox' and t.status = 'open'
     and t.last_message_at > now() - interval '30 days'
     and m.direction = 'in'
     and lower(m.from_address) !~ '(no-?reply|donotreply|do-not-reply|mailer-daemon|notification|newsletter|digest|bounce)'
     and lower(m.from_address) not in (select lower(x) from unnest(p_addresses) x);
$$;

-- ------------------------------------------------------------ 1) response debt
create or replace function public.analytics_response_debt(p_user uuid, p_addresses text[])
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_r jsonb := public.analytics_rate(p_user, 'external');
  v_rate numeric := (v_r->>'rate')::numeric;
  v_cur text := v_r->>'currency';
  v_people int; v_threads int; v_oldest numeric; v_median numeric; v_cost numeric;
  v_worst jsonb; v_trend jsonb;
begin
  select count(distinct lower(person))::int, count(*)::int, coalesce(max(waiting_h), 0),
         coalesce(percentile_cont(0.5) within group (order by waiting_h), 0)::numeric,
         coalesce(sum(least(waiting_h, 72)), 0) * v_rate * 0.25
    into v_people, v_threads, v_oldest, v_median, v_cost
    from public.analytics_waiting(p_addresses);

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_worst from (
    select thread_id::text as thread_id, subject, person, waiting_h as hours,
           round(least(waiting_h, 72) * v_rate * 0.25, 2) as cost
      from public.analytics_waiting(p_addresses) order by waiting_h desc limit 5) x;

  insert into public.analytics_debt_daily (user_id, day, waiting_people, waiting_threads, oldest_hours, median_hours, cost_of_delay, currency)
  values (p_user, current_date, v_people, v_threads, round(v_oldest, 2), round(v_median, 2), round(v_cost, 2), v_cur)
  on conflict (user_id, day) do update
    set waiting_people = excluded.waiting_people, waiting_threads = excluded.waiting_threads, oldest_hours = excluded.oldest_hours,
        median_hours = excluded.median_hours, cost_of_delay = excluded.cost_of_delay, currency = excluded.currency;

  select coalesce(jsonb_agg(jsonb_build_object('day', day::text, 'debt', cost_of_delay) order by day), '[]'::jsonb) into v_trend
    from public.analytics_debt_daily where user_id = p_user and day > current_date - 7;

  return jsonb_build_object(
    'waiting_people', v_people, 'waiting_threads', v_threads, 'oldest_hours', round(v_oldest, 1), 'median_hours', round(v_median, 1),
    'cost_of_delay', round(v_cost, 2), 'currency', v_cur, 'worst', v_worst, 'trend_7d', v_trend,
    'method', 'sum(min(waiting_hours,72)) x hourly_rate x 0.25');
end $$;

-- ------------------------------------------------------- 2) thread economics
create or replace function public.analytics_thread_economics(p_user uuid, p_addresses text[])
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_r jsonb := public.analytics_rate(p_user, 'self');
  v_rate numeric := (v_r->>'rate')::numeric;
  v_cur text := v_r->>'currency';
  v_n int; v_min int; v_hrs numeric; v_cost numeric; v_worst jsonb;
begin
  with base as (
    select t.id, t.subject,
           count(*)::int as msgs,
           count(*) filter (where m.direction = 'out')::int as outs,
           count(*) filter (where m.direction = 'in')::int as ins,
           (select count(distinct a) from (
              select lower(m2.from_address) as a from public.mail_messages m2 where m2.thread_id = t.id
              union
              select lower(x) from public.mail_messages m3 cross join lateral unnest(m3.to_addresses) x where m3.thread_id = t.id) q)::int as parts,
           (t.status <> 'open' or t.folder in ('archive', 'trash')) as resolved
      from public.mail_threads t
      join public.mail_messages m on m.thread_id = t.id
     where lower(t.mailbox_address) in (select lower(x) from unnest(p_addresses) x)
       and t.last_message_at > now() - interval '30 days'
     group by t.id, t.subject, t.status, t.folder
     order by max(t.last_message_at) desc
     limit 500),
  ins as (
    insert into public.analytics_thread_cost (user_id, thread_id, subject, messages, participants, minutes, people_hours, cost, currency, resolved, computed_at)
    select p_user, id, subject, msgs, parts, round(outs * 5 + ins * 1.5)::int,
           round((outs * 5 + ins * 1.5) / 60.0, 2), round((outs * 5 + ins * 1.5) / 60.0 * v_rate, 2), v_cur, resolved, now()
      from base
    on conflict (user_id, thread_id) do update
      set subject = excluded.subject, messages = excluded.messages, participants = excluded.participants, minutes = excluded.minutes,
          people_hours = excluded.people_hours, cost = excluded.cost, currency = excluded.currency, resolved = excluded.resolved, computed_at = excluded.computed_at
    returning thread_id, subject, messages, participants, minutes, people_hours, cost, resolved)
  select (select count(*) from ins)::int, coalesce((select sum(minutes) from ins), 0)::int, coalesce((select sum(people_hours) from ins), 0),
         coalesce((select sum(cost) from ins), 0),
         (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
            select thread_id::text as thread_id, subject, messages, participants, minutes, cost, resolved from ins order by cost desc limit 5) x)
    into v_n, v_min, v_hrs, v_cost, v_worst;

  return jsonb_build_object(
    'threads_30d', v_n, 'minutes_total', v_min, 'people_hours', round(v_hrs, 1), 'cost_total', round(v_cost, 2), 'currency', v_cur,
    'avg_minutes', case when v_n = 0 then 0 else round(v_min::numeric / v_n, 1) end, 'worst', v_worst,
    'method', 'minutes = sent x 5 + received x 1.5 ; cost = hours x hourly_rate');
end $$;

-- ------------------------------------------------------------- 3) deep work
create or replace function public.analytics_deep_work(p_user uuid, p_addresses text[], p_tz text default 'UTC')
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_tz text := case when exists (select 1 from pg_timezone_names where name = p_tz) then p_tz else 'UTC' end;
  v_lc text[] := (select coalesce(array_agg(lower(x)), '{}') from unnest(p_addresses) x);
  gi int; d date; w0 timestamptz; w1 timestamptz;
  v_meet int; v_inbox int; v_deep int; v_long int; v_frag int; v_best_a int; v_best_len int;
  t_deep int := 0; t_inbox int := 0; t_meet int := 0; t_long int := 0; t_frag int := 0;
  v_bestwin text; v_bestlen int := 0; v_days jsonb := '[]'::jsonb;
begin
  for gi in 0..6 loop
    d := ((now() at time zone v_tz)::date) - gi;
    continue when extract(isodow from d) >= 6;
    w0 := (d + time '09:00') at time zone v_tz;
    w1 := (d + time '17:00') at time zone v_tz;
    with ev as (
      select greatest(e.starts_at, w0) as s, least(e.ends_at, w1) as e
        from public.calendar_events e join public.calendar_attendees a on a.event_id = e.id
       where lower(a.address) = any (v_lc) and e.status <> 'cancelled' and not e.all_day and e.starts_at < w1 and e.ends_at > w0),
    bu as (
      select m.sent_at - interval '5 minutes' as s, m.sent_at as e
        from public.mail_messages m join public.mail_threads t on t.id = m.thread_id
       where lower(t.mailbox_address) = any (v_lc) and m.direction = 'out' and m.sent_at >= w0 and m.sent_at < w1 + interval '5 minutes'),
    mins as (select gs as mi, w0 + gs * interval '1 minute' as t0 from generate_series(0, 479) gs),
    f as (select mins.mi, exists (select 1 from ev where ev.s <= mins.t0 and ev.e > mins.t0) as mt,
                 exists (select 1 from bu where bu.s <= mins.t0 and bu.e > mins.t0) as ib from mins),
    fr as (select f.mi, f.mi - row_number() over (order by f.mi) as grp from f where not f.mt and not f.ib),
    runs as (select min(fr.mi) as a, count(*)::int as len from fr group by grp)
    select (select count(*) from f where mt)::int,
           (select count(*) from f where ib and not mt)::int,
           coalesce((select sum(len) from runs where len >= 60), 0)::int,
           coalesce((select max(len) from runs), 0)::int,
           (select count(*) from runs where len < 45)::int,
           coalesce((select a from runs order by len desc, a limit 1), 0)::int,
           coalesce((select len from runs order by len desc, a limit 1), 0)::int
      into v_meet, v_inbox, v_deep, v_long, v_frag, v_best_a, v_best_len;

    insert into public.analytics_deep_work (user_id, day, deep_minutes, inbox_minutes, meeting_minutes, longest_focus_minutes, fragmentation, best_window)
    values (p_user, d, v_deep, v_inbox, v_meet, v_long, v_frag,
            case when v_best_len >= 60 then to_char((w0 at time zone v_tz) + v_best_a * interval '1 minute', 'Dy HH24:MI') || '-' ||
                 to_char((w0 at time zone v_tz) + (v_best_a + v_best_len) * interval '1 minute', 'HH24:MI') end)
    on conflict (user_id, day) do update
      set deep_minutes = excluded.deep_minutes, inbox_minutes = excluded.inbox_minutes, meeting_minutes = excluded.meeting_minutes,
          longest_focus_minutes = excluded.longest_focus_minutes, fragmentation = excluded.fragmentation, best_window = excluded.best_window;

    t_deep := t_deep + v_deep; t_inbox := t_inbox + v_inbox; t_meet := t_meet + v_meet; t_frag := t_frag + v_frag;
    t_long := greatest(t_long, v_long);
    if v_best_len > v_bestlen and v_best_len >= 60 then
      v_bestlen := v_best_len;
      v_bestwin := to_char((w0 at time zone v_tz) + v_best_a * interval '1 minute', 'Dy HH24:MI') || '-' ||
                   to_char((w0 at time zone v_tz) + (v_best_a + v_best_len) * interval '1 minute', 'HH24:MI');
    end if;
    v_days := v_days || jsonb_build_array(jsonb_build_object('day', d::text, 'deep', round(v_deep / 60.0, 2),
                                                             'inbox', round(v_inbox / 60.0, 2), 'meeting', round(v_meet / 60.0, 2)));
  end loop;

  return jsonb_build_object(
    'deep_hours', round(t_deep / 60.0, 1), 'inbox_hours', round(t_inbox / 60.0, 1), 'meeting_hours', round(t_meet / 60.0, 1),
    'longest_focus_minutes', t_long, 'fragmentation', t_frag, 'best_window', v_bestwin, 'days', v_days, 'timezone', v_tz,
    'method', 'weekdays 09:00-17:00 ; busy = meetings + 5-minute reply blocks ; deep = free runs of 60+ minutes');
end $$;

-- --------------------------------------------------------- 4) attention leaks
create or replace function public.analytics_attention_leaks(p_user uuid, p_addresses text[])
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_out jsonb;
begin
  delete from public.analytics_attention_leaks where user_id = p_user;
  insert into public.analytics_attention_leaks (user_id, source, kind, interruptions_7d, minutes_7d, fix)
  select p_user, src,
         case when src ~ '(no-?reply|donotreply|do-not-reply|mailer-daemon|alerts?@|bounce|automated|system@)' then 'automation'
              when src ~ '(newsletter|digest|news@|marketing|updates@|info@|mailer)' then 'list'
              when src ~ '(notification|notify)' then 'notification'
              else 'person' end,
         n, round(n * 2)::int,
         case when src ~ '(no-?reply|donotreply|do-not-reply|mailer-daemon|alerts?@|bounce|automated|system@)' then 'Route to a label and read once a day instead of live.'
              when src ~ '(newsletter|digest|news@|marketing|updates@|info@|mailer)' then 'Unsubscribe, or move to a weekly digest.'
              when src ~ '(notification|notify)' then 'Turn the notification down at the source.'
              else 'Agree a fixed daily check-in time with this person.' end
    from (select lower(m.from_address) as src, count(*)::int as n
            from public.mail_messages m join public.mail_threads t on t.id = m.thread_id
           where lower(t.mailbox_address) in (select lower(x) from unnest(p_addresses) x)
             and m.direction = 'in' and m.sent_at > now() - interval '7 days'
             and lower(m.from_address) not in (select lower(x) from unnest(p_addresses) x)
           group by 1 having count(*) >= 3 order by 2 desc limit 8) s;
  select coalesce(jsonb_agg(jsonb_build_object('source', source, 'kind', kind, 'interruptions_7d', interruptions_7d,
                                               'minutes_7d', minutes_7d, 'fix', fix) order by interruptions_7d desc), '[]'::jsonb)
    into v_out from public.analytics_attention_leaks where user_id = p_user;
  return jsonb_build_object('leaks', v_out, 'method', 'sender with 3+ inbound messages in 7 days ; 2 minutes per interruption');
end $$;

-- ------------------------------------------------------------ 5) promise SLA
create or replace function public.analytics_promise_sla(p_user uuid, p_org uuid, p_email text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_made int; v_kept int; v_late int; v_broken int; v_avg numeric; v_risk jsonb;
begin
  with p as (
    select t.*,
           case when t.completed_at is not null and (t.due_at is null or t.completed_at <= t.due_at) then 'kept'
                when t.completed_at is not null then 'late'
                when t.due_at is not null and t.due_at < now() - interval '48 hours' then 'broken'
                when t.due_at is not null and t.due_at < now() then 'late'
                else 'open' end as st
      from public.work_tasks t
     where t.source = 'promise' and t.org_id = p_org and lower(coalesce(t.owner, '')) = lower(p_email)
       and t.created_at > now() - interval '30 days')
  select count(*)::int, count(*) filter (where st = 'kept')::int, count(*) filter (where st = 'late')::int, count(*) filter (where st = 'broken')::int,
         coalesce(avg(extract(epoch from (coalesce(completed_at, now()) - due_at)) / 3600.0) filter (where st = 'late' and due_at is not null), 0)
    into v_made, v_kept, v_late, v_broken, v_avg from p;

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_risk from (
    select thread_id::text as thread_id, coalesce(thread_subject, title) as subject, due_at, owner as person
      from public.work_tasks
     where source = 'promise' and org_id = p_org and lower(coalesce(owner, '')) = lower(p_email)
       and completed_at is null and due_at is not null and due_at < now() + interval '48 hours' and due_at > now() - interval '48 hours'
     order by due_at limit 10) x;

  return jsonb_build_object('made_30d', v_made, 'kept', v_kept, 'late', v_late, 'broken', v_broken,
    'keep_rate', case when v_made = 0 then 0 else round(100.0 * v_kept / v_made, 1) end,
    'avg_late_hours', round(greatest(v_avg, 0), 1), 'at_risk', v_risk,
    'method', 'work_tasks source=promise ; broken = still open 48h after due');
end $$;

-- ------------------------------------------------------------- 6) forecast
create or replace function public.analytics_forecast(p_user uuid, p_addresses text[])
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  w int[] := array[0, 0, 0, 0];
  i int; n int; v_est numeric; v_mean numeric; v_sd numeric; v_conf numeric; v_avg_min numeric; v_dow text;
  v_drivers jsonb := '[]'::jsonb; v_advice text;
begin
  for i in 1..4 loop
    select count(*)::int into n from public.mail_threads t
     where lower(t.mailbox_address) in (select lower(x) from unnest(p_addresses) x)
       and t.created_at >= now() - (i * interval '7 days') and t.created_at < now() - ((i - 1) * interval '7 days');
    w[i] := n;   -- w[1] = pichhla haftah, w[4] = sab se purana
  end loop;
  v_est := (w[1] * 4 + w[2] * 3 + w[3] * 2 + w[4] * 1) / 10.0;
  v_mean := (w[1] + w[2] + w[3] + w[4]) / 4.0;
  v_sd := sqrt(((w[1] - v_mean) ^ 2 + (w[2] - v_mean) ^ 2 + (w[3] - v_mean) ^ 2 + (w[4] - v_mean) ^ 2) / 4.0);
  v_conf := case when v_mean = 0 then 0.2 else greatest(0.2, least(0.95, 1 - v_sd / v_mean)) end;
  select coalesce(avg(minutes), 6) into v_avg_min from public.analytics_thread_cost where user_id = p_user and computed_at > now() - interval '30 days';
  select to_char(created_at, 'FMDay') into v_dow
    from public.mail_threads where lower(mailbox_address) in (select lower(x) from unnest(p_addresses) x) and created_at > now() - interval '28 days'
   group by 1 order by count(*) desc limit 1;

  if w[2] > 0 then v_drivers := v_drivers || jsonb_build_array(jsonb_build_object('label', 'Last week vs the week before', 'delta', round(100.0 * (w[1] - w[2]) / w[2], 1))); end if;
  if v_dow is not null then v_drivers := v_drivers || jsonb_build_array(jsonb_build_object('label', 'Busiest day: ' || v_dow, 'delta', 0)); end if;
  v_advice := case when v_est > v_mean * 1.2 and v_mean > 0 then 'Next week looks heavier than usual — protect a focus block early in the week.'
                   when v_est < v_mean * 0.8 and v_mean > 0 then 'Next week looks lighter — a good time to clear old threads.'
                   when v_mean = 0 then null
                   else 'Next week looks in line with your recent weeks.' end;
  return jsonb_build_object('next_week_threads', round(v_est)::int, 'next_week_hours', round(v_est * v_avg_min / 60.0, 1),
    'confidence', round(v_conf, 2), 'drivers', v_drivers, 'advice', v_advice, 'method', 'weights 4/3/2/1 over the last 4 weeks of new threads');
end $$;

-- ------------------------------------------------------------------- 7) team
create or replace function public.analytics_team(p_user uuid, p_org uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_r jsonb := public.analytics_rate(p_user, 'team');
  v_rate numeric := (v_r->>'rate')::numeric;
  m record; v_members jsonb := '[]'::jsonb; v_cost numeric; v_wait int; v_made int; v_kept int; v_deep numeric; v_load text;
  v_max int := 0; v_sorted int[];
begin
  for m in select om.user_id, lower(om.email) as email,
                  (select p.display_name from public.account_profiles p where p.user_id = om.user_id) as display_name
             from public.org_members om
            where om.org_id = p_org and coalesce(om.status, 'active') = 'active' and om.email is not null
            order by om.email limit 100 loop
    select coalesce(sum(least(waiting_h, 72)), 0) * v_rate * 0.25, count(*)::int into v_cost, v_wait
      from public.analytics_waiting(array[m.email]);
    select count(*)::int, count(*) filter (where completed_at is not null and (due_at is null or completed_at <= due_at))::int into v_made, v_kept
      from public.work_tasks where source = 'promise' and org_id = p_org and lower(coalesce(owner, '')) = m.email and created_at > now() - interval '30 days';
    select coalesce(sum(deep_minutes), 0) / 60.0 into v_deep from public.analytics_deep_work where user_id = m.user_id and day > current_date - 7;
    v_load := case when v_wait < 3 then 'light' when v_wait < 10 then 'healthy' when v_wait < 25 then 'heavy' else 'drowning' end;
    v_max := greatest(v_max, v_wait);
    v_sorted := array_append(coalesce(v_sorted, '{}'), v_wait);
    v_members := v_members || jsonb_build_array(jsonb_build_object('email', m.email, 'display_name', m.display_name,
      'response_debt', round(v_cost, 2), 'keep_rate', case when v_made = 0 then 0 else round(100.0 * v_kept / v_made, 1) end,
      'deep_hours', round(v_deep, 1), 'load', v_load));
  end loop;
  return jsonb_build_object('members', v_members,
    'unbalanced', coalesce(v_max >= 10 and v_max >= 3 * greatest((select percentile_cont(0.5) within group (order by x) from unnest(v_sorted) x), 1), false),
    'method', 'light <3 waiting, healthy <10, heavy <25, drowning 25+ ; unbalanced = busiest has 10+ and 3x the median');
end $$;

-- ------------------------------------------------------- founder (platform)
create or replace function public.founder_analytics_overview()
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'tenants', (select count(distinct user_id) from public.analytics_debt_daily),
    'currency', 'GBP',
    'total_debt_cost', coalesce((select sum(cost_of_delay) from public.analytics_debt_daily
                                  where day = (select max(day) from public.analytics_debt_daily)), 0),
    'threads_30d', coalesce((select count(*) from public.analytics_thread_cost where computed_at > now() - interval '30 days'), 0),
    'platform_keep_rate', coalesce((select round(100.0 * count(*) filter (where completed_at is not null and (due_at is null or completed_at <= due_at)) / greatest(count(*), 1), 1)
                                      from public.work_tasks where source = 'promise' and created_at > now() - interval '30 days'), 0),
    'worst_tenants', coalesce((select jsonb_agg(x) from (
        select user_id::text as tenant, cost_of_delay as debt, waiting_people as waiting
          from public.analytics_debt_daily
         where day = (select max(day) from public.analytics_debt_daily)
         order by cost_of_delay desc limit 10) x), '[]'::jsonb));
$$;

-- ------------------------------------------------- permissions: sirf service_role
do $$
declare f text;
begin
  foreach f in array array[
    'analytics_rate(uuid,text)', 'analytics_waiting(text[])', 'analytics_response_debt(uuid,text[])', 'analytics_thread_economics(uuid,text[])',
    'analytics_deep_work(uuid,text[],text)', 'analytics_attention_leaks(uuid,text[])', 'analytics_promise_sla(uuid,uuid,text)',
    'analytics_forecast(uuid,text[])', 'analytics_team(uuid,uuid)', 'founder_analytics_overview()'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to service_role', f);
  end loop;
end $$;

-- ------------------------------------------------------------------ self-test
do $$
declare v_u uuid; r jsonb;
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  select id into v_u from auth.users limit 1;
  if v_u is null then raise notice 'E89: auth.users khali — self-test chhoda'; return; end if;
  r := public.analytics_response_debt(v_u, array['nobody@example.invalid']);
  if (r->>'waiting_threads')::int <> 0 or (r->>'cost_of_delay')::numeric <> 0 or r->>'currency' is null then raise exception 'E89 SELFTEST FAIL debt: %', r; end if;
  r := public.analytics_thread_economics(v_u, array['nobody@example.invalid']);
  if (r->>'threads_30d')::int <> 0 then raise exception 'E89 SELFTEST FAIL econ: %', r; end if;
  r := public.analytics_deep_work(v_u, array['nobody@example.invalid'], 'Asia/Karachi');
  if r->'days' is null or (r->>'deep_hours')::numeric < 0 then raise exception 'E89 SELFTEST FAIL deep: %', r; end if;
  r := public.analytics_attention_leaks(v_u, array['nobody@example.invalid']);
  if jsonb_array_length(r->'leaks') <> 0 then raise exception 'E89 SELFTEST FAIL leaks: %', r; end if;
  r := public.analytics_promise_sla(v_u, gen_random_uuid(), 'nobody@example.invalid');
  if (r->>'made_30d')::int <> 0 then raise exception 'E89 SELFTEST FAIL promise: %', r; end if;
  r := public.analytics_forecast(v_u, array['nobody@example.invalid']);
  if (r->>'next_week_threads')::int <> 0 then raise exception 'E89 SELFTEST FAIL forecast: %', r; end if;
  r := public.analytics_team(v_u, gen_random_uuid());
  if jsonb_array_length(r->'members') <> 0 then raise exception 'E89 SELFTEST FAIL team: %', r; end if;
  r := public.founder_analytics_overview();
  if r->>'currency' <> 'GBP' then raise exception 'E89 SELFTEST FAIL founder: %', r; end if;
end $$;

select 'E89' as cheez, 'Analytics backend: 7 server functions (debt, economics, deep work, leaks, promise SLA, forecast, team) + founder overview' as haal;

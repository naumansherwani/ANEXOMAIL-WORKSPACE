-- E106 — FOUNDER POLAR REJECTS (F3-a): "301 unreviewed signature rejects kyun?" ka jawab — reason ke hisaab se ginti aur kab se, BINA raw body / header values ke. 10/10 (FC27).
-- ---------------------------------------------------------------------------------------------------------------------------
-- Source: polar_signature_rejects (engine likhta hai: reason, raw_body, headers, reviewed, created_at). Yeh file us table ko BADALTI NAHI (NO-TOUCH).
--   founder_polar_rejects() STABLE security definer, search_path pinned, statement_timeout 5s, service_role-only. Jawab:
--     total, unreviewed, latest_at, first_at
--     by_reason  [{reason, n, n_24h, first_at, last_at}] (top 12; reason sirf ^[a-z0-9_:. -]{1,80}$ — baqi "other")
--     daily_7d   [{day, n}]
--     sender     {standard_webhook_headers (webhook-id+webhook-signature maujood = Polar jaisa bhejne wala, secret ghalat/purana ho sakta hai),
--                 no_signature_headers (header hi nahi = random internet/bot), polar_user_agent}
--   PRIVACY: raw_body aur header VALUES kabhi nahi (selftest pakadta hai).
-- Dobara chalana safe. Kuch likhta nahi.
set lock_timeout = '10s';
set statement_timeout = '60s';
set search_path = pg_catalog, public, extensions;

create or replace function public.founder_polar_rejects()
returns jsonb language plpgsql stable security definer
set search_path = pg_catalog, public
set statement_timeout = '5s'
as $$
declare v_now timestamptz := now(); out jsonb;
begin
  if to_regclass('public.polar_signature_rejects') is null then
    return jsonb_build_object('connected', false, 'note', 'polar_signature_rejects table nahi');
  end if;
  with r as (
    select case when reason ~ '^[a-z0-9_:. -]{1,80}$' then reason else 'other' end as reason, created_at, reviewed,
           (headers ? 'webhook-id' and headers ? 'webhook-signature') as std,
           (not (headers ? 'webhook-signature' or headers ? 'x-polar-signature')) as nosig,
           (coalesce(headers ->> 'user-agent', '') ilike '%polar%') as ua_polar
      from public.polar_signature_rejects)
  select jsonb_build_object(
    'connected', true, 'generated_at', v_now,
    'total', count(*), 'unreviewed', count(*) filter (where not reviewed),
    'first_at', min(created_at), 'latest_at', max(created_at),
    'by_reason', coalesce((select jsonb_agg(jsonb_build_object('reason', g.reason, 'n', g.n, 'n_24h', g.n24, 'first_at', g.f, 'last_at', g.l) order by g.n desc, g.reason)
                             from (select reason, count(*) n, count(*) filter (where created_at > v_now - interval '24 hours') n24, min(created_at) f, max(created_at) l
                                     from r group by reason order by count(*) desc, reason limit 12) g), '[]'::jsonb),
    'daily_7d', coalesce((select jsonb_agg(jsonb_build_object('day', d.day, 'n', d.n) order by d.day)
                            from (select (created_at at time zone 'UTC')::date as day, count(*) n from r where created_at > v_now - interval '7 days' group by 1) d), '[]'::jsonb),
    'sender', jsonb_build_object('standard_webhook_headers', count(*) filter (where std), 'no_signature_headers', count(*) filter (where nosig), 'polar_user_agent', count(*) filter (where ua_polar)),
    'source', 'polar_signature_rejects (counts only; no raw body, no header values)')
  into out from r;
  return out;
end $$;
revoke all on function public.founder_polar_rejects() from public, anon, authenticated;
grant execute on function public.founder_polar_rejects() to service_role;
comment on function public.founder_polar_rejects() is 'E106: why were webhook signatures rejected — counts by reason/time/sender class. No raw body, no header values.';

create or replace function public.founder_polar_rejects_selftest() returns text language plpgsql security definer set search_path = pg_catalog, public as $$
declare j jsonb; txt text;
begin
  j := public.founder_polar_rejects();
  if (j ->> 'connected')::boolean is not true then return 'E106 selftest SKIP — ' || coalesce(j ->> 'note', 'table nahi'); end if;
  if not (j ? 'total' and j ? 'by_reason' and j ? 'daily_7d' and j ? 'sender') then raise exception 'shape ghalat: %', j; end if;
  txt := j::text;
  if txt ~* '"(raw_body|raw|headers|webhook-signature|user-agent)"' then raise exception 'mana key jawab mein'; end if;
  if (select provolatile from pg_proc where oid = 'public.founder_polar_rejects()'::regprocedure) <> 's' then raise exception 'STABLE nahi'; end if;
  if has_function_privilege('anon', 'public.founder_polar_rejects()', 'execute') or has_function_privilege('authenticated', 'public.founder_polar_rejects()', 'execute') then raise exception 'anon/authenticated execute'; end if;
  return 'E106 selftest OK — shape, no raw/header values, STABLE, grants; total=' || (j ->> 'total');
end $$;
revoke all on function public.founder_polar_rejects_selftest() from public, anon, authenticated;
grant execute on function public.founder_polar_rejects_selftest() to service_role;
do $$ begin raise notice '%', public.founder_polar_rejects_selftest(); end $$;

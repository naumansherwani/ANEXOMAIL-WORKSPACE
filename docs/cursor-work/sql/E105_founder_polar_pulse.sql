-- E105 — FOUNDER POLAR PULSE (F3-a): founder ko Polar production webhook ka ASLI haal, sirf PADH kar. 10/10 (FC27).
-- ---------------------------------------------------------------------------------------------------------------------------
-- Jo webhook (https://polarpayments.anexomail.com/api/v1/polar-webhook, API 2026-10) already Supabase mein likhta hai, usi ka jama-shuda data:
--   polar_webhook_inbox (events), polar_subscriptions (state-synced), polar_reconcile_log, polar_signature_rejects, polar_payment_alerts.
-- Yeh file un tables ko BADALTI NAHI (na index, na trigger, na grant): Polar engine/WAL NO-TOUCH (Rule B6a). Sirf ek read-only RPC.
--   1) Preflight      — kaunsi tables maujood hain (har section khud guard: table na ho to us hisse mein "not connected", jhoota 0 nahi).
--   2) founder_polar_pulse() — STABLE security definer, search_path pinned, statement_timeout 5s, service_role-only. Jawab jsonb:
--        webhook {last_event_at, age_secs, events_24h, events_7d, by_type_7d (top 12), unprocessed, oldest_unprocessed_age_secs, errors_24h}
--        subscriptions {total, by_status, by_product, new_30d, ended_30d, renewing_7d}
--        integrity {signature_rejects_24h, signature_rejects_unreviewed, reconcile_last_at, reconcile_gaps_7d, alerts_unsent}
--        revenue {…founder_revenue_truth() — flat per-company GBP (Rule 51)…} ya null
--      PRIVACY: email / customer id / raw payload / headers KABHI nahi (selftest regex se pakadta hai).
--   3) selftest + CHECK_E105 — shape, privacy, grants, read-only (STABLE), search_path pinned.
-- Dobara chalana safe (create or replace). Kuch likhta nahi.

set lock_timeout = '10s';
set statement_timeout = '60s';
set search_path = pg_catalog, public, extensions;

create or replace function public.founder_polar_pulse()
returns jsonb language plpgsql stable security definer
set search_path = pg_catalog, public
set statement_timeout = '5s'
as $$
declare
  v_now timestamptz := now();
  v_hook jsonb; v_subs jsonb; v_int jsonb; v_rev jsonb;
  v_last timestamptz; v_oldest timestamptz;
begin
  -- webhook events
  if to_regclass('public.polar_webhook_inbox') is null then
    v_hook := jsonb_build_object('connected', false, 'note', 'polar_webhook_inbox table nahi');
  else
    select max(received_at) into v_last from public.polar_webhook_inbox;
    select min(received_at) into v_oldest from public.polar_webhook_inbox where not processed;
    v_hook := jsonb_build_object(
      'connected', true,
      'last_event_at', v_last,
      'age_secs', case when v_last is null then null else greatest(0, extract(epoch from (v_now - v_last))::bigint) end,
      'events_24h', (select count(*) from public.polar_webhook_inbox where received_at > v_now - interval '24 hours'),
      'events_7d',  (select count(*) from public.polar_webhook_inbox where received_at > v_now - interval '7 days'),
      'by_type_7d', coalesce((select jsonb_agg(jsonb_build_object('type', t.event_type, 'n', t.n) order by t.n desc, t.event_type)
                                from (select event_type, count(*) as n from public.polar_webhook_inbox
                                       where received_at > v_now - interval '7 days' group by event_type order by count(*) desc, event_type limit 12) t), '[]'::jsonb),
      'unprocessed', (select count(*) from public.polar_webhook_inbox where not processed),
      'oldest_unprocessed_age_secs', case when v_oldest is null then null else greatest(0, extract(epoch from (v_now - v_oldest))::bigint) end,
      'errors_24h', (select count(*) from public.polar_webhook_inbox where process_error is not null and received_at > v_now - interval '24 hours'));
  end if;

  -- subscriptions (state-synced by the engine's trigger)
  if to_regclass('public.polar_subscriptions') is null then
    v_subs := jsonb_build_object('connected', false, 'note', 'polar_subscriptions table nahi');
  else
    v_subs := jsonb_build_object(
      'connected', true,
      'total', (select count(*) from public.polar_subscriptions),
      'by_status', coalesce((select jsonb_object_agg(status, n) from (select status, count(*) as n from public.polar_subscriptions group by status) s), '{}'::jsonb),
      'by_product', coalesce((select jsonb_agg(jsonb_build_object('product', coalesce(product_key, 'unknown'), 'active', a, 'past_due', p, 'grace', g) order by a desc, product_key)
                                from (select product_key, count(*) filter (where status = 'active') a, count(*) filter (where status = 'past_due') p, count(*) filter (where status = 'grace') g
                                        from public.polar_subscriptions group by product_key) q), '[]'::jsonb),
      'new_30d',   (select count(*) from public.polar_subscriptions where created_at > v_now - interval '30 days'),
      'ended_30d', (select count(*) from public.polar_subscriptions where status in ('canceled', 'revoked') and updated_at > v_now - interval '30 days'),
      'renewing_7d', (select count(*) from public.polar_subscriptions where status = 'active' and current_period_end between v_now and v_now + interval '7 days'));
  end if;

  -- integrity (signature rejects, reconcile gaps, alerts)
  v_int := jsonb_build_object(
    'signature_rejects_24h',        case when to_regclass('public.polar_signature_rejects') is null then null else (select count(*) from public.polar_signature_rejects where created_at > v_now - interval '24 hours') end,
    'signature_rejects_unreviewed', case when to_regclass('public.polar_signature_rejects') is null then null else (select count(*) from public.polar_signature_rejects where not reviewed) end,
    'reconcile_last_at',            case when to_regclass('public.polar_reconcile_log') is null then null else (select max(created_at) from public.polar_reconcile_log) end,
    'reconcile_gaps_7d',            case when to_regclass('public.polar_reconcile_log') is null then null else (select count(*) from public.polar_reconcile_log where verdict in ('missing', 'diverged') and created_at > v_now - interval '7 days') end,
    'alerts_unsent',                case when to_regclass('public.polar_payment_alerts') is null then null else (select count(*) from public.polar_payment_alerts where sent_at is null) end);

  -- revenue (existing flat-price truth, GBP) — sirf agar function maujood
  if to_regprocedure('public.founder_revenue_truth()') is not null then v_rev := public.founder_revenue_truth(); end if;

  return jsonb_build_object('generated_at', v_now, 'webhook', v_hook, 'subscriptions', v_subs, 'integrity', v_int, 'revenue', v_rev,
                            'source', 'Polar production webhook (API 2026-10) -> Supabase, read-only');
end $$;
revoke all on function public.founder_polar_pulse() from public, anon, authenticated;
grant execute on function public.founder_polar_pulse() to service_role;
comment on function public.founder_polar_pulse() is 'E105: read-only Polar webhook pulse for the founder. No PII, no raw payloads, writes nothing, touches no Polar table definition.';

create or replace function public.founder_polar_pulse_selftest() returns text language plpgsql security definer set search_path = pg_catalog, public as $$
declare j jsonb; txt text; v_ok boolean;
begin
  j := public.founder_polar_pulse();
  if not (j ? 'webhook' and j ? 'subscriptions' and j ? 'integrity' and j ? 'generated_at') then raise exception 'shape ghalat: %', j; end if;
  txt := j::text;
  if txt ~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' then raise exception 'jawab mein email jaisa text: PII leak'; end if;
  if txt ~* '"(payload|raw_body|headers|email|polar_customer_id|user_id)"' then raise exception 'jawab mein mana key (payload/email/...)'; end if;
  if (select provolatile from pg_proc where oid = 'public.founder_polar_pulse()'::regprocedure) <> 's' then raise exception 'function STABLE nahi (read-only hona chahiye)'; end if;
  if has_function_privilege('anon', 'public.founder_polar_pulse()', 'execute') or has_function_privilege('authenticated', 'public.founder_polar_pulse()', 'execute') then raise exception 'anon/authenticated ko execute mila'; end if;
  v_ok := (j #>> '{webhook,connected}') is not null; if not v_ok then raise exception 'webhook.connected gum'; end if;
  return 'E105 selftest OK — shape, no-PII, STABLE, grants; connected(webhook)=' || (j #>> '{webhook,connected}') || ', events_7d=' || coalesce(j #>> '{webhook,events_7d}', 'n/a');
end $$;
revoke all on function public.founder_polar_pulse_selftest() from public, anon, authenticated;
grant execute on function public.founder_polar_pulse_selftest() to service_role;

do $$ begin raise notice '%', public.founder_polar_pulse_selftest(); end $$;

-- E116 — Founder Settings S1d: Drift & schedule measure the new S1c rows. A third baseline rule, "value": the recommended safe value of a setting (true / false / a number).
-- Founder order 1 Nov 2026 12:14: close the honest gaps of S1c ("yeh sari haadein ko par kero") — the 8 awam rows had no Drift baseline.
-- Technology: SQL (Supabase Postgres, RLS on). The Drift page already shows any item; the Schedule form (UI) is widened in the same phase.
--
-- What changes:
--   1) founder_settings_baseline gets a 'value' rule: safe_value (jsonb) + if_off ('loose' | 'risky' = how bad it is when the value differs). E113's two rules ('set', 'max') are unchanged.
--   2) founder_settings_drift: a 'value' item compares the account's current value (or the registry default when nothing is stored) with the safe value.
--   3) founder_setting_explain: "recommended" shows the safe value for a 'value' item.
--   4) 5 baseline rows: require passkey (risky when off), flag external, send check, quiet hours, block trackers (looser when off).
--      NOT measured on purpose: undo window, retention, only-VIPs — they are choices, not safety defaults; a baseline would call a legitimate choice "drift".
-- E113 itself is left untouched (the server keeps a sha ledger of files already run); this file replaces the two functions. Safe to run again. Everything the selftest does is rolled back.

do $$
begin
  if to_regclass('public.founder_settings_baseline') is null or to_regprocedure('public.founder_settings_drift(uuid)') is null or to_regprocedure('public.founder_setting_explain(text)') is null then
    raise exception 'E116 needs E113';
  end if;
  if (select count(*) from public.founder_setting_registry) < 22 then raise exception 'E116 needs E115 first (22 registry keys)'; end if;
end $$;

-- 1) the table
alter table public.founder_settings_baseline add column if not exists safe_value jsonb;
alter table public.founder_settings_baseline add column if not exists if_off text not null default 'loose';
do $$
declare c record;
begin
  for c in select conname from pg_constraint where conrelid = 'public.founder_settings_baseline'::regclass and contype = 'c'
            and (pg_get_constraintdef(oid) like '%rule%') and conname <> 'founder_settings_baseline_if_off_ok' loop
    execute format('alter table public.founder_settings_baseline drop constraint %I', c.conname);
  end loop;
  alter table public.founder_settings_baseline add constraint founder_settings_baseline_value_rule_ok check (
    (rule = 'set'   and recommended is null     and safe_value is null) or
    (rule = 'max'   and recommended is not null and recommended > 0 and safe_value is null) or
    (rule = 'value' and recommended is null     and safe_value is not null));
  if not exists (select 1 from pg_constraint where conname = 'founder_settings_baseline_if_off_ok') then
    alter table public.founder_settings_baseline add constraint founder_settings_baseline_if_off_ok check (if_off in ('loose','risky'));
  end if;
end $$;

-- 2) five baseline rows (source 'setting' = a registry key)
insert into public.founder_settings_baseline (key, source, rule, recommended, safe_value, if_off, label, why, sort) values
 ('workspace.require_passkey', 'setting', 'value', null, 'true'::jsonb,  'risky', 'Passkey is required for every sign-in', 'Without a passkey requirement a stolen token is enough to sign in. Recommended: on (it takes effect when passkey sign-in exists, step 7).', 60),
 ('workspace.flag_external',   'setting', 'value', null, 'true'::jsonb,  'loose', 'External recipients are flagged', 'Without the warning a mail can leave the company by a mistyped address and nobody pauses.', 70),
 ('personal.send_check',       'setting', 'value', null, 'true'::jsonb,  'loose', 'Send confidence check is on', 'The check catches a missing attachment or a wrong recipient before the mail leaves.', 80),
 ('notifications.quiet_hours', 'setting', 'value', null, 'true'::jsonb,  'loose', 'Quiet hours are on', 'Without quiet hours every alert can interrupt at any hour, which hides the ones that really matter.', 90),
 ('privacy.block_trackers',    'setting', 'value', null, 'true'::jsonb,  'loose', 'Tracking pixels are blocked', 'Remote tracking pixels tell a sender that you opened a mail, and from where.', 100)
on conflict (key) do update set source = excluded.source, rule = excluded.rule, recommended = excluded.recommended, safe_value = excluded.safe_value, if_off = excluded.if_off, label = excluded.label, why = excluded.why, sort = excluded.sort;

-- 3) drift: E113's function plus the 'value' rule
create or replace function public.founder_settings_drift(p_uid uuid)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare b record; pol public.founder_audit_merkle_policy%rowtype; v_cur jsonb; v_num numeric; v_state text; v_items jsonb := '[]'::jsonb;
        na integer := 0; nl integer := 0; nr integer := 0; v_rows bigint; v_last bigint; v_lag bigint;
begin
  perform public._fs_assert_founder(p_uid);
  select * into pol from public.founder_audit_merkle_policy where id;
  for b in select * from public.founder_settings_baseline order by sort, key loop
    v_state := 'aligned'; v_cur := null;
    if b.rule = 'set' then
      v_cur := public._fs_current(p_uid, b.key);
      if v_cur is null then v_state := 'loose'; end if;
    elsif b.rule = 'value' then
      v_cur := coalesce(public._fs_current(p_uid, b.key), (select default_value from public.founder_setting_registry where key = b.key));
      if v_cur is distinct from b.safe_value then v_state := b.if_off; end if;
    else
      v_num := case b.key when 'audit.merkle.every_rows' then pol.every_rows when 'audit.merkle.warn_lag_rows' then pol.warn_lag_rows
                          when 'audit.merkle.fail_lag_rows' then pol.fail_lag_rows else null end;
      if v_num is null then continue; end if;
      v_cur := to_jsonb(v_num);
      if v_num > b.recommended * 10 then v_state := 'risky'; elsif v_num > b.recommended then v_state := 'loose'; end if;
    end if;
    if v_state = 'aligned' then na := na + 1; elsif v_state = 'loose' then nl := nl + 1; else nr := nr + 1; end if;
    v_items := v_items || jsonb_build_object('key', b.key, 'label', b.label, 'state', v_state, 'current', v_cur,
                                             'recommended', case when b.rule = 'set' then to_jsonb('set'::text) when b.rule = 'value' then b.safe_value else to_jsonb(b.recommended) end, 'why', b.why);
  end loop;
  select coalesce(max(seq), 0) into v_rows from public.founder_audit;
  select coalesce(max(upto_seq), 0) into v_last from public.founder_audit_checkpoints;
  v_lag := greatest(v_rows - v_last, 0);
  v_state := case when v_lag > pol.fail_lag_rows then 'risky' when v_lag > pol.warn_lag_rows then 'loose' else 'aligned' end;
  if v_state = 'aligned' then na := na + 1; elsif v_state = 'loose' then nl := nl + 1; else nr := nr + 1; end if;
  v_items := v_items || jsonb_build_object('key', 'audit.merkle.lag', 'label', 'Unsealed ledger entries right now', 'state', v_state, 'current', to_jsonb(v_lag),
                                           'recommended', to_jsonb(pol.warn_lag_rows), 'why', 'Entries since the last seal. Above the warning lag the tail is no longer provably covered by a seal.');
  return jsonb_build_object('score', public._fs_drift_score(na, nl, nr), 'aligned', na, 'loose', nl, 'risky', nr, 'items', v_items,
                            'at_ms', public._fs_ms(clock_timestamp()));
end $$;
revoke all on function public.founder_settings_drift(uuid) from public, anon, authenticated;
grant execute on function public.founder_settings_drift(uuid) to service_role;

-- 4) explain: the recommended value of a 'value' item
create or replace function public.founder_setting_explain(p_key text)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare i public.founder_settings_info%rowtype; b public.founder_settings_baseline%rowtype;
begin
  select * into i from public.founder_settings_info where key = p_key;
  if not found then raise exception 'unknown setting' using errcode = '22023'; end if;
  select * into b from public.founder_settings_baseline where key = p_key;
  return jsonb_build_object('key', i.key, 'label', i.label, 'plain', i.plain, 'example', i.example, 'tradeoff', i.tradeoff, 'source', 'server',
                            'recommended', case when b.key is null then null when b.rule = 'set' then to_jsonb('set'::text) when b.rule = 'value' then b.safe_value else to_jsonb(b.recommended) end,
                            'why_recommended', b.why);
end $$;
revoke all on function public.founder_setting_explain(text) from public, anon, authenticated;
grant execute on function public.founder_setting_explain(text) to service_role;

-- 5) selftest (rolled back)
create or replace function public.founder_drift_value_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare u uuid; r text := ''; j jsonb; j2 jsonb; st text; k text; n_items integer;
        b_set bigint; b_hist bigint; b_audit bigint; b_rev bigint; b_sch bigint;
begin
  select user_id into u from public.founder_accounts order by user_id limit 1;
  if u is null then return 'E116 selftest SKIP — no founder account'; end if;
  select count(*) into b_set from public.founder_settings; select count(*) into b_hist from public.founder_settings_history; select count(*) into b_audit from public.founder_audit;
  select count(*) into b_rev from public.founder_settings_revert_log; select count(*) into b_sch from public.founder_settings_schedule;
  begin
    delete from public.founder_settings where user_id = u;
    -- structure: 5 'value' rows, the old rules intact, every value row names a registry key with a boolean default equal to its safe value
    if (select count(*) from public.founder_settings_baseline where rule = 'value') <> 5 then raise exception 'five value rules expected'; end if;
    if (select count(*) from public.founder_settings_baseline where rule = 'set') <> 2 or (select count(*) from public.founder_settings_baseline where rule = 'max') <> 3 then raise exception 'the E113 rules changed'; end if;
    if exists (select 1 from public.founder_settings_baseline b where b.rule = 'value' and (not exists (select 1 from public.founder_setting_registry r where r.key = b.key)
        or not public._founder_setting_valid(b.key, b.safe_value))) then raise exception 'a value rule points at nothing or at an invalid safe value'; end if;
    if public._fs_fails($q$insert into public.founder_settings_baseline (key, source, rule, recommended, safe_value, label, why, sort) values ('x.bad','setting','value',5,'true'::jsonb,'l','w',1)$q$) is not true then raise exception 'a value rule with a recommended number was accepted'; end if;
    if public._fs_fails($q$insert into public.founder_settings_baseline (key, source, rule, recommended, safe_value, label, why, sort) values ('x.bad2','setting','value',null,null,'l','w',1)$q$) is not true then raise exception 'a value rule without a safe value was accepted'; end if;
    r := r || 'structure OK; ';

    -- defaults: with nothing stored every value item is aligned (the registry defaults ARE the safe values)
    j := public.founder_settings_drift(u);
    for k in select key from public.founder_settings_baseline where rule = 'value' loop
      st := (select e ->> 'state' from jsonb_array_elements(j -> 'items') e where e ->> 'key' = k);
      if st is distinct from 'aligned' then raise exception '% must be aligned at its default, got %', k, st; end if;
    end loop;
    n_items := jsonb_array_length(j -> 'items');
    if (j ->> 'aligned')::integer + (j ->> 'loose')::integer + (j ->> 'risky')::integer <> n_items then raise exception 'drift counts do not add up'; end if;
    r := r || 'defaults aligned OK; ';

    -- turning a safe setting off drifts it: passkey -> risky, the other four -> loose; the score falls; turning it back restores it
    perform public.founder_setting_set(u, 'workspace.require_passkey', to_jsonb(false));
    j2 := public.founder_settings_drift(u);
    if (select e ->> 'state' from jsonb_array_elements(j2 -> 'items') e where e ->> 'key' = 'workspace.require_passkey') <> 'risky' then raise exception 'passkey off must be risky'; end if;
    if (j2 ->> 'score')::integer >= (j ->> 'score')::integer then raise exception 'score must fall when passkey is off'; end if;
    if (select e -> 'current' from jsonb_array_elements(j2 -> 'items') e where e ->> 'key' = 'workspace.require_passkey') <> 'false'::jsonb
       or (select e -> 'recommended' from jsonb_array_elements(j2 -> 'items') e where e ->> 'key' = 'workspace.require_passkey') <> 'true'::jsonb then raise exception 'drift must show current and recommended'; end if;
    foreach k in array array['workspace.flag_external','personal.send_check','notifications.quiet_hours','privacy.block_trackers'] loop
      perform public.founder_setting_set(u, k, to_jsonb(false));
      st := (select e ->> 'state' from jsonb_array_elements(public.founder_settings_drift(u) -> 'items') e where e ->> 'key' = k);
      if st is distinct from 'loose' then raise exception '% off must be loose, got %', k, st; end if;
    end loop;
    if (public.founder_settings_drift(u) ->> 'risky')::integer < 1 or (public.founder_settings_drift(u) ->> 'loose')::integer < 4 then raise exception 'counts after five drifts'; end if;
    perform public.founder_setting_set(u, 'workspace.require_passkey', null);        -- null = back to the default (true)
    if (select e ->> 'state' from jsonb_array_elements(public.founder_settings_drift(u) -> 'items') e where e ->> 'key' = 'workspace.require_passkey') <> 'aligned' then raise exception 'passkey back to default must be aligned'; end if;
    perform public.founder_setting_set(u, 'privacy.block_trackers', to_jsonb(true));  -- an explicit safe value is aligned too
    if (select e ->> 'state' from jsonb_array_elements(public.founder_settings_drift(u) -> 'items') e where e ->> 'key' = 'privacy.block_trackers') <> 'aligned' then raise exception 'explicit true must be aligned'; end if;
    r := r || 'drift and restore OK; ';

    -- unmeasured choices stay unmeasured: undo window, retention and only-VIPs never appear in drift
    if exists (select 1 from jsonb_array_elements(public.founder_settings_drift(u) -> 'items') e where e ->> 'key' in ('personal.undo_send','workspace.retention_days','notifications.only_vips')) then raise exception 'a choice was measured as drift'; end if;
    r := r || 'choices not measured OK; ';

    -- explain shows the recommended value; a key without a baseline shows null
    j := public.founder_setting_explain('workspace.require_passkey');
    if j -> 'recommended' <> 'true'::jsonb or j ->> 'why_recommended' is null then raise exception 'explain must show the recommended value: %', j; end if;
    if public.founder_setting_explain('personal.undo_send') ->> 'recommended' is not null then raise exception 'undo_send has no baseline'; end if;
    if public.founder_setting_explain('personal.home') ->> 'recommended' <> 'set' then raise exception 'the E113 explain for a set rule changed'; end if;
    r := r || 'explain OK; ';

    if public.founder_settings_replay_check(u) is not null then raise exception 'replay check dirty'; end if;
    if public.founder_audit_verify(1) is not null then raise exception 'audit chain broken'; end if;
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E116 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_settings) <> b_set or (select count(*) from public.founder_settings_history) <> b_hist or (select count(*) from public.founder_audit) <> b_audit
     or (select count(*) from public.founder_settings_revert_log) <> b_rev or (select count(*) from public.founder_settings_schedule) <> b_sch then
    raise exception 'E116 selftest left rows behind';
  end if;
  return 'E116 selftest OK — ' || r || 'rollback clean';
end $$;
revoke all on function public.founder_drift_value_selftest() from public, anon, authenticated;
grant execute on function public.founder_drift_value_selftest() to service_role;

do $$ begin
  raise notice '%', public.founder_drift_value_selftest();
  raise notice '%', public.founder_settings_s2_selftest();
  raise notice '%', public.founder_settings_s1c_selftest();
end $$;

-- RUNBOOK (comments only)
-- Run:   bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E116_founder_drift_value_rule CHECK_E116   (after the usual fetch). Order: ... E114 -> E115 -> E116. Safe to run again.
-- UI:    Drift lists the five new items when they differ; the Schedule form offers every schedulable setting (booleans and the closed lists).
-- Undo:  delete the 5 baseline rows with rule 'value'; re-run E113 section 6 (drift) and section 7 (explain); drop the two added columns.

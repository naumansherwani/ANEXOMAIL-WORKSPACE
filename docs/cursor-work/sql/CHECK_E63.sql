
-- CHECK E63 — sirf padhta hai (koi write nahi). Har row ok = true. Constraint ka asli behaviour (insert reject/accept) proofs/E63_proof.sql mein (sandbox, rollback).
select item, ok from (
  select 'E63 calendar_events.goal (text) + goal_state (text) + goal_state_at (timestamptz)' as item,
         (select count(*) from information_schema.columns where table_schema='public' and table_name='calendar_events'
            and ((column_name='goal' and data_type='text') or (column_name='goal_state' and data_type='text')
              or (column_name='goal_state_at' and data_type='timestamp with time zone'))) = 3 as ok, 1 as o
  union all select 'E63 goal_state NOT NULL default open',
         exists (select 1 from information_schema.columns where table_schema='public' and table_name='calendar_events' and column_name='goal_state'
                   and is_nullable = 'NO' and column_default like '%open%'), 2
  union all select 'E63 teeno constraints maujood + VALIDATED (goal_ck, goal_state_ck, goal_state_at_ck)',
         (select count(*) from pg_constraint where conrelid = 'public.calendar_events'::regclass
            and conname in ('calendar_events_goal_ck','calendar_events_goal_state_ck','calendar_events_goal_state_at_ck') and convalidated) = 3, 3
  union all select 'E63 calendar_goal_ok: IMMUTABLE + PARALLEL SAFE + pinned search_path',
         exists (select 1 from pg_proc where oid = to_regprocedure('public.calendar_goal_ok(text)')
                   and provolatile = 'i' and proparallel = 's' and array_to_string(proconfig, ',') like '%search_path=pg_catalog, public%'), 4
  union all select 'E63 goal_ok accepts: null, ek line, 2000 harf, multi-line',
         public.calendar_goal_ok(null) and public.calendar_goal_ok('Contract signed') and public.calendar_goal_ok(repeat('x', 2000))
         and public.calendar_goal_ok(E'Line one\nLine two'), 5
  union all select 'E63 goal_ok rejects: khali, spaces, 2001 harf, tab, bell, DEL',
         not public.calendar_goal_ok('') and not public.calendar_goal_ok('   ') and not public.calendar_goal_ok(repeat('x', 2001))
         and not public.calendar_goal_ok(E'a\tb') and not public.calendar_goal_ok(E'a\x07b') and not public.calendar_goal_ok(E'a\x7fb'), 6
  union all select 'E63 purani rows sab open + goal_state_at NULL (constraint par poori)',
         not exists (select 1 from public.calendar_events where goal_state <> 'open' or goal_state_at is not null), 7
  union all select 'E63 LIVE PATH: goal columns select ho jate hain (Rust ka e63_ready wahi query chalata hai)',
         (select count(*) >= 0 from (select goal, goal_state, goal_state_at from public.calendar_events limit 1) q), 8
  union all select 'E63 export: to_jsonb(row) mein goal keys aate hain (E44 export apne-aap)',
         (select count(*) >= 0 from (select to_jsonb(e) -> 'goal_state' as g from public.calendar_events e limit 1) q)
         and exists (select 1 from pg_attribute where attrelid = 'public.calendar_events'::regclass and attname = 'goal_state' and not attisdropped), 9
) t order by o;

-- CHECK E63 — sirf padhta hai (koi write nahi). Har row ok = true. Constraint ka asli behaviour (insert reject/accept) proofs/E63_proof.sql mein (sandbox, rollback).
select item, ok from (
  select 'E63 calendar_events.goal + goal_state + goal_state_at' as item,
         (select count(*) from information_schema.columns where table_schema='public' and table_name='calendar_events'
            and column_name in ('goal','goal_state','goal_state_at')) = 3 as ok, 1 as o
  union all select 'E63 goal_state NOT NULL default open',
         exists (select 1 from information_schema.columns where table_schema='public' and table_name='calendar_events' and column_name='goal_state'
                   and is_nullable = 'NO' and column_default like '%open%'), 2
  union all select 'E63 constraints maujood + VALIDATED',
         (select count(*) from pg_constraint where conname in ('calendar_events_goal_ck','calendar_events_goal_state_ck') and convalidated) = 2, 3
  union all select 'E63 calendar_goal_ok function', to_regprocedure('public.calendar_goal_ok(text)') is not null, 4
  union all select 'E63 goal_ok accepts: null, ek line, 2000 harf, multi-line',
         public.calendar_goal_ok(null) and public.calendar_goal_ok('Contract signed') and public.calendar_goal_ok(repeat('x', 2000)) and public.calendar_goal_ok(E'Line one\nLine two'), 5
  union all select 'E63 goal_ok rejects: khali, spaces, 2001 harf, tab, bell',
         not public.calendar_goal_ok('') and not public.calendar_goal_ok('   ') and not public.calendar_goal_ok(repeat('x', 2001))
         and not public.calendar_goal_ok(E'a\tb') and not public.calendar_goal_ok(E'a\x07b'), 6
  union all select 'E63 purani rows sab open + goal_state_at NULL (constraint par poori)',
         not exists (select 1 from public.calendar_events where goal_state <> 'open' or goal_state_at is not null), 7
  union all select 'E63 LIVE PATH: goal columns select ho jate hain (Rust ka e63_ready wahi query chalata hai)',
         (select count(*) >= 0 from (select goal, goal_state, goal_state_at from public.calendar_events limit 1) q), 8
) t order by o;


-- CHECK E103 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E103 koi action title/summary mein Roman-Urdu nahi (12 English)' as item,
       (select count(*) from public.founder_actions where title ~* '(chalao|wapas|dobara|band|nahi|ka |ki |ke )' or summary ~* '(chalao|wapas|dobara|nahi|lazmi|jaanch|abhi|saaf|karna)') = 0 as ok, 1 as ord
union all select 'E103 12 actions maujood, danger/enabled nahi badla (enabled = 0)',
       (select count(*) from public.founder_actions) >= 12 and (select count(*) from public.founder_actions where enabled) = 0, 2
union all select 'E103 high-danger actions abhi bhi passkey+two_tap',
       (select count(*) from public.founder_actions where danger='high' and not (needs_passkey and two_tap)) = 0, 3
) t order by ord;

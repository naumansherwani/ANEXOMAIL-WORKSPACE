-- CHECK E61 — sirf padhta hai (koi write nahi). Har row ok = true.
select item, ok from (
  select 'E61 clocks key maanti hai (1 zone)' as item, public.awam_ui_extra_ok('{"clocks":["Europe/London"]}'::jsonb) as ok, 1 as o
  union all select 'E61 khali list theek (sab pin hata sakte hain)', public.awam_ui_extra_ok('{"clocks":[]}'::jsonb), 2
  union all select 'E61 6 zone theek', public.awam_ui_extra_ok('{"clocks":["Asia/Karachi","Europe/London","Asia/Tokyo","America/New_York","Asia/Dubai","Australia/Sydney"]}'::jsonb), 3
  union all select 'E61 7 zone rad', not public.awam_ui_extra_ok('{"clocks":["a","b","c","d","e","f","g"]}'::jsonb), 4
  union all select 'E61 duplicate rad', not public.awam_ui_extra_ok('{"clocks":["Asia/Tokyo","Asia/Tokyo"]}'::jsonb), 5
  union all select 'E61 ../ rad', not public.awam_ui_extra_ok('{"clocks":["Europe/../etc"]}'::jsonb), 6
  union all select 'E61 non-string rad', not public.awam_ui_extra_ok('{"clocks":[1]}'::jsonb), 7
  union all select 'E61 purani 3 keys ab bhi theek', public.awam_ui_extra_ok('{"ooo":[]}'::jsonb), 8
  union all select 'E61 anjaan key ab bhi rad', not public.awam_ui_extra_ok('{"evil":1}'::jsonb), 9
) t order by o;

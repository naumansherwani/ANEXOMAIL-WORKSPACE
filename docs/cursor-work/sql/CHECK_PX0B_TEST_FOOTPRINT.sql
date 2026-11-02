-- CHECK PX0B — sirf padhta hai. Founder ko dikhata hai ke do test accounts (basic.test@anexomail.com, alikhan@anexomail.com) delete hon to DATABASE mein kya kya jayega
-- (har table jis ki foreign key auth.users ko jaati hai: kitni rows). Honest limit: mail server par asli mailbox (Stalwart / files) is list mein nahi aati; woh E126 ke baad alag dekhna hoga.
select item, ok from (
  select 0 as o, 'PX0B accounts looked at: ' || coalesce(string_agg(u.email || ' (' || u.id || ')', ', ' order by u.email), 'NONE FOUND') as item, true as ok
  from auth.users u where lower(u.email) in ('basic.test@anexomail.com', 'alikhan@anexomail.com')
  union all
  select 1 + row_number() over (order by t.tbl), 'PX0B ' || t.tbl || ' (' || t.col || ') rows = ' || t.n, true
  from (
    select (c.conrelid::regclass)::text as tbl, a.attname as col,
           (xpath('/row/n/text()', query_to_xml(format('select count(*) as n from %s where %I in (select id from auth.users where lower(email) in (%L, %L))', c.conrelid::regclass, a.attname, 'basic.test@anexomail.com', 'alikhan@anexomail.com'), false, true, '')))[1]::text::int as n
    from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
    where c.contype = 'f' and c.confrelid = 'auth.users'::regclass and array_length(c.conkey, 1) = 1
  ) t where t.n > 0
) x order by o;

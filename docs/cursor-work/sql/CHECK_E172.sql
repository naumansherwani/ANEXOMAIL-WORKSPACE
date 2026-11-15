
-- CHECK E172 - the mail ledger ROWS door for the browser kernel (QUI-H3). READ-ONLY, writes nothing. 4 checks.
with d as (select public.fmail_ledger_rows172(0, 1000) as j),
r as (select (x.value ->> 'seq')::bigint as seq, x.value as v from d, jsonb_array_elements(d.j -> 'rows') x),
c as (
  select r.seq, r.v ->> 'prev' as prev, r.v ->> 'hash' as hash,
         public.fmail_ledger_hash_167(r.v ->> 'prev', r.seq, (r.v ->> 'ts')::bigint, (r.v ->> 'actor')::uuid, r.v ->> 'action', r.v ->> 'target', r.v ->> 'reason', (r.v ->> 'meta')::jsonb) as again,
         lag(r.v ->> 'hash', 1, repeat('0', 64)) over (order by r.seq) as want_prev
  from r)
select item, ok from (
select 'E172 the door returns ' || (select count(*) from r) || ' rows, the table has ' || (select count(*) from public.fmail_ledger) as item,
       (select count(*) from r) = least((select count(*) from public.fmail_ledger), 1000) as ok, 1 as ord
union all select 'E172 every returned row re-hashes to its row_hash with the one E167 formula (' || (select count(*) filter (where again <> hash) from c) || ' bad)', (select count(*) filter (where again <> hash) from c) = 0, 2
union all select 'E172 every prev_hash is the previous row_hash, first one is zeros (' || (select count(*) filter (where prev <> want_prev) from c) || ' broken links)', (select count(*) filter (where prev <> want_prev) from c) = 0, 3
union all select 'E172 the door is service_role only and read-only (stable)',
       not has_function_privilege('anon', 'public.fmail_ledger_rows172(bigint,int)', 'execute') and not has_function_privilege('authenticated', 'public.fmail_ledger_rows172(bigint,int)', 'execute')
       and (select provolatile = 's' from pg_proc where oid = 'public.fmail_ledger_rows172(bigint,int)'::regprocedure), 4
) t order by ord;

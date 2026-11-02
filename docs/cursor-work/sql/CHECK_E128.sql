-- CHECK E128 — sirf padhta hai.
select item, ok from (
  select 1 as o, 'E128 account_phones.e164_hmac exists' as item,
         exists (select 1 from information_schema.columns where table_schema='public' and table_name='account_phones' and column_name='e164_hmac') as ok
  union all select 2, 'E128 blind-index is a plain (non-unique) index: same number may sit on several accounts',
         exists (select 1 from pg_indexes where schemaname='public' and indexname='account_phones_hmac_idx' and indexdef not ilike '%unique%')
  union all select 3, 'E128 no row holds a plain-looking value in e164_hmac',
         not exists (select 1 from public.account_phones where e164_hmac is not null and e164_hmac !~ '^[0-9a-f]{64}$')
) x order by o;

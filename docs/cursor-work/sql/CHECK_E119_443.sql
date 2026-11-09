-- CHECK E119 :443 — kuch persist nahi karta, sirf padhta hai. Founder 9 Nov 2026 15:39: "yeh tune kerna hai, kaise kerna hai steps follow kerwao".
-- Prober ki REAL rows (founder_tls_checks, E119) asli :443 par, pichhle 12 ghante: normal browser offer AES-256 par utarna chahiye, aes256_only ok, aes128_only refused.
-- Item text mein wahi rows likhi aati hain (offered=ok cipher / refused), isliye output khud saboot hai. Row nahi to ok = false (kuch banaya nahi jata).
with l as (
  select distinct on (offered) offered, ok, cipher, checked_at
    from public.founder_tls_checks
   where host = 'founderworkspace.anexomail.com' and port = 443 and checked_at > now() - interval '12 hours'
   order by offered, checked_at desc, id desc
)
select item, ok from (
select 'E119 :443 founderworkspace.anexomail.com latest real handshakes (12h): '
       || coalesce((select string_agg(offered || '=' || case when ok then 'ok ' || coalesce(cipher, '?') else 'refused' end, ' | ' order by offered) from l), 'NO ROWS') as item,
       exists (select 1 from l where offered = 'browser' and ok and cipher like '%AES_256%')
       and exists (select 1 from l where offered = 'aes256_only' and ok and cipher like '%AES_256%')
       and exists (select 1 from l where offered = 'aes128_only' and not ok) as ok,
       1 as ord
) t order by ord;

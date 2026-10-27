
-- PROOF cross-plan mail — SIRF PADHTA HAI (SELECT). Koi data nahi badalta, mail ka body/content nahi dikhata.
-- Sawal: pro.buyer2 ne jo 'ZZ cross-plan connect test' basic.buyer / business.buyer / bpro.buyer ko bheji, kya un ke mailbox tak pahunchi?
-- Har test address ke liye ek row: pahunchi = true/false. (Sirf test mail, sirf subject + sent_at + org; body nahi.)
select a.addr as test_address,
       count(m.id) filter (where m.id is not null) as rows_found,
       coalesce(bool_or(m.id is not null), false) as pahunchi,
       min(m.sent_at) as pehli_baar,
       count(distinct m.org_id) as orgs_mein
  from (values ('basic.buyer@anexomail.com'), ('business.buyer@anexomail.com'), ('bpro.buyer@anexomail.com')) as a(addr)
  left join public.mail_messages m
    on m.subject = 'ZZ cross-plan connect test - please ignore'
   and m.to_addresses @> array[a.addr]::text[]
 group by a.addr
 order by a.addr

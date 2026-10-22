
-- E27 — Business Pro mailboxes = unlimited (blueprint #15, 14 Oct 2026)
--
-- Live truth (14 Oct, founder ke server ka psql output):
--   storage_plans.business_pro.mailbox_limit = NULL  (NULL = unlimited)
--   org_mailbox_cap('business_pro')          = NULL  (yehi asli cap hai)
--   workspace_plans.business_pro.mailboxes_included = 1   <- GALAT
--
-- workspace_plans.mailboxes_included NOT NULL tha, isliye "unlimited" likh nahi
-- sakte the. storage_plans ki tarah yahan bhi NULL = unlimited. Is figure ko
-- sirf server/routes/org.ts mailboxCap() fallback ki tarah padhta hai (jab
-- storage_plans mein row na ho), aur woh NULL handle karta hai.

alter table public.workspace_plans alter column mailboxes_included drop not null;

update public.workspace_plans
   set mailboxes_included = null
 where id = 'business_pro';

select id, mailboxes_included, storage_per_mailbox_gb
  from public.workspace_plans
 order by sort_order;

select public.org_mailbox_cap('business_pro') as business_pro_cap;

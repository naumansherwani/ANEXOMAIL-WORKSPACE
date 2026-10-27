
-- E98 — kernel 0.4.0 darj karna: naye modules intent@1 (wada + deadline, email ka waqt/paisa) aur filectx@1 (email mein file ka zikr pakadna).
-- Teen round pass hone ke BAAD (cargo test 46/46, bun real-wasm 41, asli Chromium 27 Oct) — Rule 52. wasm sha256 = repo ki pin.gen.ts.
-- Idempotent: dobara chalane par wahi row. Polar :3400 NO-TOUCH.
set lock_timeout = '5s';
set statement_timeout = '30s';

do $$ begin
  if to_regprocedure('public.kernel_release_publish(text,text,text[],text)') is null then raise exception 'E98 PREFLIGHT: E90 (kernel_release_publish) nahi'; end if;
  if to_regclass('public.kernel_modules') is null then raise exception 'E98 PREFLIGHT: kernel_modules nahi (E90)'; end if;
end $$;

set search_path = public, extensions;

insert into public.kernel_modules (name, version, since, article, summary) values
 ('intent',  1, '0.3.0', 1, 'compose: email text mein wada + deadline (English + Roman Urdu) aur padhne ka waqt/paisa, sab browser mein, deterministic'),
 ('filectx', 1, '0.4.0', 1, 'compose: email text mein file ka zikr ("latest CRM sheet", Q3_budget.xlsx) pehchanna; asli file server se')
on conflict (name, version) do nothing;

select public.kernel_release_publish('0.4.0', '7499188264a10c8da1a3f82a9ddad20cc2da791b8362b862f11b94925901f88c',
  array['hmac@1','intent@1','filectx@1','live@1','rank@1','rpc@1','sha256@1','sniff@1'],
  'intent@1 + filectx@1 (compose Business Outcomes + File Context). 3 rounds: cargo 46/46, bun wasm, Chromium.');

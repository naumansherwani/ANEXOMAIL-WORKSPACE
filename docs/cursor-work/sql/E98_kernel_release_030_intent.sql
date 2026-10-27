
-- E98 — kernel 0.3.0 darj karna: naya module intent@1 (wada + deadline, email ka waqt/paisa; browser mein, deterministic).
-- Teen round pass hone ke BAAD (cargo test 40/40, bun real-wasm 40/40, asli Chromium 27 Oct) — Rule 52. wasm sha256 = repo ki pin.gen.ts.
-- Idempotent: dobara chalane par wahi row. Polar :3400 NO-TOUCH.
set lock_timeout = '5s';
set statement_timeout = '30s';

do $$ begin
  if to_regprocedure('public.kernel_release_publish(text,text,text[],text)') is null then raise exception 'E98 PREFLIGHT: E90 (kernel_release_publish) nahi'; end if;
  if to_regclass('public.kernel_modules') is null then raise exception 'E98 PREFLIGHT: kernel_modules nahi (E90)'; end if;
end $$;

set search_path = public, extensions;

insert into public.kernel_modules (name, version, since, article, summary) values
 ('intent', 1, '0.3.0', 1, 'compose: email text mein wada + deadline (English + Roman Urdu) aur padhne ka waqt/paisa, sab browser mein, deterministic')
on conflict (name, version) do nothing;

select public.kernel_release_publish('0.3.0', 'd19eded45df6e6ae421ad2b209b33352ed701f1970d5c0dacbdd46669a873482',
  array['hmac@1','intent@1','live@1','rank@1','rpc@1','sha256@1','sniff@1'],
  'intent@1: promise scan + attention cost (compose Business Outcomes). 3 rounds: cargo 40/40, bun wasm, Chromium.');

-- ANEXOMAIL — Phase 49b HOTFIX
-- Error: "function gen_random_bytes(integer) does not exist"
-- Wajah: Supabase par pgcrypto `extensions` schema mein hota hai, aur hamare
-- SECURITY DEFINER functions ka search_path sirf `public` hai.
-- Fix: token core Postgres `gen_random_uuid()` se banao (koi pgcrypto zaroorat nahi).
-- Idempotent — jitni baar chalao safe hai.

begin;

create extension if not exists pgcrypto with schema extensions;

create or replace function public.billing_state_hash(p_entity text, p_id uuid, p_state text, p_version int)
returns text language sql immutable set search_path = public, extensions as $$
  select encode(extensions.digest(coalesce(p_entity,'')||'|'||coalesce(p_id::text,'')||'|'||
                       coalesce(p_state,'')||'|'||coalesce(p_version::text,''), 'sha256'), 'hex');
$$;

-- Runtime endpoint exact naam `billing_guest_intent_open` call karta hai.
-- Purane hotfix mein lafzon ki ترتیب ulat thi, is liye live function replace
-- nahi hua aur purana gen_random_bytes() wala body chalta raha.
drop function if exists public.billing_intent_open_guest(text,text,text,text,text,int,numeric,text,text);

create or replace function public.billing_guest_intent_open(
  p_kind text,
  p_plan text default null,
  p_band text default null,
  p_product_key text default null,
  p_product_id text default null,
  p_seats int default 1,
  p_amount numeric default null,
  p_currency text default 'GBP',
  p_email text default null
) returns table (intent_id uuid, guest_token text)
language plpgsql security definer set search_path = public, extensions as $$
declare v_id uuid; v_tok text;
begin
  v_tok := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');

  insert into public.billing_intents
    (user_id, kind, plan, band, product_key, product_id, seats, amount_expected, currency,
     guest_email, guest_token, fsm_state, expires_at)
  values (null, coalesce(p_kind,'plan'), p_plan, p_band, p_product_key, p_product_id,
          greatest(1, coalesce(p_seats,1)), p_amount, coalesce(p_currency,'GBP'),
          nullif(trim(coalesce(p_email,'')),''), v_tok, 'CHECKOUT_OPEN', now() + interval '2 hours')
  returning id into v_id;

  insert into public.billing_state_versions
    (entity_type, entity_id, state_version, state, state_hash, source)
  values ('intent', v_id, 1, 'CHECKOUT_OPEN',
          public.billing_state_hash('intent', v_id, 'CHECKOUT_OPEN', 1), 'app');

  return query select v_id, v_tok;
end;
$$;

revoke execute on function public.billing_guest_intent_open(text,text,text,text,text,int,numeric,text,text)
  from public, anon, authenticated;
grant execute on function public.billing_guest_intent_open(text,text,text,text,text,int,numeric,text,text)
  to service_role;

-- Phase 37 ka same masla (movein verification_id default)
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='movein_verifications'
                and column_name='verification_id') then
    alter table public.movein_verifications
      alter column verification_id set default replace(gen_random_uuid()::text, '-', '');
  end if;
end $$;

commit;

-- Verify (result mein gen_random_bytes nahi aana chahiye):
-- select pg_get_functiondef('public.billing_guest_intent_open(text,text,text,text,text,integer,numeric,text,text)'::regprocedure);

-- E147 — Approve a new key from a device you already trust (founder order 7 Nov 2026 17:27: "the phone has no passkey; make this phase really work").
-- Problem found live: a second key is a T2 step-up (E117/E139): an EXISTING key must approve it. On a phone with no key yet, the browser asks for a key the phone does not have, so nothing could ever be added from the phone.
-- This file adds the read side of the fix; the approval itself still goes through the same grant (founder_stepup_issue -> founder_passkey_add), proved by a key on ANY approved device.
--   1) founder_passkey_pending(uid): the parked registrations waiting for approval (label, kind, credential tail, the device that made it, seconds left, the nonce the approval is bound to).
--      It never returns a key body. A ceremony lives 5 minutes at most (E117 constraint), so a forgotten request dies by itself.
--   2) the answer lists ONLY this founder's open, unused, unexpired register_pending ceremonies; closed to anon and authenticated.
--   3) selftest (rolls back) + CHECK_E147.sql.
-- Needs E117, E139. Safe to run again.

create or replace function public.founder_passkey_pending(p_uid uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  perform public._fs_assert_founder(p_uid);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'ceremony', c.id,
             'label', c.state ->> 'label',
             'credential_id', c.state #>> '{reg,credential_id}',
             'tail', right(c.state #>> '{reg,credential_id}', 8),
             'attachment', coalesce(c.state #>> '{reg,facts,attachment}', 'unknown'),
             'nonce', c.state ->> 'nonce',
             'device', coalesce((select d.label from public.founder_devices d where d.id::text = c.state ->> 'device'), 'unknown device'),
             'device_id', c.state ->> 'device',
             'left_s', greatest(0, extract(epoch from c.expires_at - now())::integer)) order by c.created_at)
      from public.founder_passkey_ceremonies c
     where c.user_id = p_uid and c.kind = 'register' and c.used_at is null and c.expires_at > now() and c.state ->> 'purpose' = 'register_pending'), '[]'::jsonb);
end $$;
revoke all on function public.founder_passkey_pending(uuid) from public, anon, authenticated;
grant execute on function public.founder_passkey_pending(uuid) to service_role;

create or replace function public.founder_passkey_pending_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare u uuid; r text := ''; c uuid; c2 uuid; j jsonb;
begin
  select user_id into u from public.founder_accounts order by user_id limit 1;
  if u is null then return 'E147 selftest SKIP — no founder account'; end if;
  begin
    if jsonb_array_length(public.founder_passkey_pending(u)) <> 0 then raise exception 'there is already a pending request'; end if;
    c := public.founder_passkey_ceremony_begin(u, 'register', jsonb_build_object('purpose', 'register_pending', 'device', gen_random_uuid()::text, 'label', 'Phone fingerprint', 'nonce', 'e147-nonce-0123456789',
           'reg', jsonb_build_object('credential_id', 'CRED-0123456789abcdefghijklmnopqrstuvwxyz', 'key', jsonb_build_object('SECRET', 'x'), 'facts', jsonb_build_object('attachment', 'platform'))));
    c2 := public.founder_passkey_ceremony_begin(u, 'register', jsonb_build_object('purpose', 'register', 'label', 'not pending'));
    j := public.founder_passkey_pending(u);
    if jsonb_array_length(j) <> 1 then raise exception 'expected exactly the one pending request, got %', jsonb_array_length(j); end if;
    if j -> 0 ->> 'label' <> 'Phone fingerprint' or j -> 0 ->> 'attachment' <> 'platform' or j -> 0 ->> 'tail' <> right('CRED-0123456789abcdefghijklmnopqrstuvwxyz', 8) then raise exception 'pending row wrong: %', j; end if;
    if j::text like '%SECRET%' or j::text like '%"key"%' then raise exception 'a key body leaked into the pending list'; end if;
    if (j -> 0 ->> 'left_s')::int not between 1 and 300 then raise exception 'time left is wrong'; end if;
    r := r || 'only the parked registration is listed, no key body, time left within 5 minutes; ';
    update public.founder_passkey_ceremonies set used_at = now() where id = c;
    if jsonb_array_length(public.founder_passkey_pending(u)) <> 0 then raise exception 'a used request is still listed'; end if;
    r := r || 'a used request disappears; ';
    if has_function_privilege('anon', 'public.founder_passkey_pending(uuid)', 'execute') or has_function_privilege('authenticated', 'public.founder_passkey_pending(uuid)', 'execute') then raise exception 'pending list is open to anon or authenticated'; end if;
    raise exception using errcode = 'P0001', message = 'E147 selftest PASS: ' || r;
  exception when others then
    if sqlerrm like 'E147 selftest PASS%' then return sqlerrm; end if;
    return 'E147 selftest FAIL: ' || sqlerrm || ' (after: ' || r || ')';
  end;
end $$;
revoke all on function public.founder_passkey_pending_selftest() from public, anon, authenticated;
grant execute on function public.founder_passkey_pending_selftest() to service_role;

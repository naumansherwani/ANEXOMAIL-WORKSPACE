-- E43 — passkey lazmi (password + passkey dono) ka database hissa: recovery codes + passkey status — Blueprint G35 — 20 Oct 2026
--
-- Founder ka faisla (20 Oct 2026): password aur passkey DONO rakhne hain; passkey lazmi hai; 2 passkey (phone + laptop) + recovery codes.
-- Is file mein:
--   * account_recovery_codes   — 10 ek-bar-ke code, DB mein sirf bcrypt hash (plain code sirf bante waqt ek baar user ko dikhta hai)
--   * recovery_codes_regenerate(_user)  -> text[] (plain codes, sirf ek baar), purane unused code mita deta hai
--   * recovery_code_redeem(_email,_code) -> jsonb {ok, user_id} ; 15 minute mein 5 galat koshish ke baad rok
--   * passkey_policy           — enforce kab se (naye account foran; purane accounts ko grace_days)
--   * passkey_status(_user)    -> jsonb {count, target, codes_remaining, required, hard, grace_until}
-- Dobara chalana safe. Kuch delete nahi hota (sirf naye table/function). Plain code kabhi log/table mein nahi.
set search_path = public, extensions;
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.account_recovery_codes (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  code_hash  text not null,
  created_at timestamptz not null default now(),
  used_at    timestamptz
);
create index if not exists account_recovery_codes_user_idx on public.account_recovery_codes (user_id) where used_at is null;

create table if not exists public.account_recovery_code_attempts (
  id      bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  at      timestamptz not null default now(),
  ok      boolean not null default false
);
create index if not exists account_recovery_code_attempts_idx on public.account_recovery_code_attempts (user_id, at desc);

alter table public.account_recovery_codes enable row level security;
alter table public.account_recovery_code_attempts enable row level security;
revoke all on public.account_recovery_codes, public.account_recovery_code_attempts from public, anon, authenticated;
grant all on public.account_recovery_codes, public.account_recovery_code_attempts to service_role;
grant usage, select on sequence public.account_recovery_code_attempts_id_seq to service_role;

create table if not exists public.passkey_policy (
  id          int primary key default 1 check (id = 1),
  enforced_at timestamptz not null default now(),
  grace_days  int not null default 7,
  target      int not null default 2
);
insert into public.passkey_policy (id) values (1) on conflict (id) do nothing;
alter table public.passkey_policy enable row level security;
revoke all on public.passkey_policy from public, anon, authenticated;
grant all on public.passkey_policy to service_role;

-- 10 code, har ek XXXX-XXXX-XXXX (32 akshar ka alphabet, 0/O/1/I nahi) = 60 bit
create or replace function public.recovery_codes_regenerate(_user uuid)
returns text[]
language plpgsql security definer
set search_path = public, extensions as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  codes text[] := '{}';
  c text;
  b bytea;
  i int;
  j int;
begin
  if _user is null then raise exception 'user_required'; end if;
  delete from public.account_recovery_codes where user_id = _user and used_at is null;
  for i in 1..10 loop
    b := gen_random_bytes(12);
    c := '';
    for j in 0..11 loop
      c := c || substr(alphabet, (get_byte(b, j) % 32) + 1, 1);
      if j in (3, 7) then c := c || '-'; end if;
    end loop;
    codes := codes || c;
    insert into public.account_recovery_codes (user_id, code_hash)
    values (_user, crypt(replace(c, '-', ''), gen_salt('bf', 8)));
  end loop;
  return codes;
end $$;

create or replace function public.recovery_code_redeem(_email text, _code text)
returns jsonb
language plpgsql security definer
set search_path = public, extensions as $$
declare
  uid    uuid;
  norm   text := upper(regexp_replace(coalesce(_code, ''), '[^A-Za-z0-9]', '', 'g'));
  r      record;
  recent int;
begin
  select u.id into uid from auth.users u where lower(u.email) = lower(btrim(coalesce(_email, ''))) limit 1;
  -- ek jaisa jawab: account hai ya nahi, yeh nahi batate
  if uid is null or length(norm) <> 12 then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  select count(*) into recent from public.account_recovery_code_attempts
   where user_id = uid and ok = false and at > now() - interval '15 minutes';
  if recent >= 5 then
    return jsonb_build_object('ok', false, 'error', 'too_many_attempts');
  end if;
  for r in select id, code_hash from public.account_recovery_codes where user_id = uid and used_at is null loop
    if crypt(norm, r.code_hash) = r.code_hash then
      update public.account_recovery_codes set used_at = now() where id = r.id and used_at is null;
      insert into public.account_recovery_code_attempts (user_id, ok) values (uid, true);
      return jsonb_build_object('ok', true, 'user_id', uid,
        'codes_left', (select count(*) from public.account_recovery_codes where user_id = uid and used_at is null));
    end if;
  end loop;
  insert into public.account_recovery_code_attempts (user_id, ok) values (uid, false);
  return jsonb_build_object('ok', false, 'error', 'invalid');
end $$;

-- required: bina passkey wale ke liye. hard = ab bypass nahi (naya account, ya grace khatam)
create or replace function public.passkey_status(_user uuid)
returns jsonb
language plpgsql stable security definer
set search_path = public, extensions as $$
declare
  p      public.passkey_policy;
  n      int;
  codes  int;
  made   timestamptz;
  grace  timestamptz;
  hard   boolean;
begin
  select * into p from public.passkey_policy where id = 1;
  select count(*) into n from public.webauthn_credentials where user_id = _user;
  select count(*) into codes from public.account_recovery_codes where user_id = _user and used_at is null;
  select u.created_at into made from auth.users u where u.id = _user;
  grace := p.enforced_at + make_interval(days => p.grace_days);
  -- naya account (policy ke baad bana) ya grace khatam => hard
  hard := n = 0 and (made > p.enforced_at or now() > grace);
  return jsonb_build_object(
    'count', n, 'target', p.target, 'codes_remaining', codes,
    'required', n = 0, 'hard', hard,
    'grace_until', case when made > p.enforced_at then null else grace end);
end $$;

revoke all on function public.recovery_codes_regenerate(uuid) from public, anon, authenticated;
revoke all on function public.recovery_code_redeem(text, text) from public, anon, authenticated;
revoke all on function public.passkey_status(uuid) from public, anon, authenticated;
grant execute on function public.recovery_codes_regenerate(uuid) to service_role;
grant execute on function public.recovery_code_redeem(text, text) to service_role;
grant execute on function public.passkey_status(uuid) to service_role;

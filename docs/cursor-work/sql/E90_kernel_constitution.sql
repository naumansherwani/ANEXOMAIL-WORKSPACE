
-- ============================================================================
-- E90 — ANEXOMAIL KERNEL CONSTITUTION  (founder Nauman Sherwani, 26 Oct 2026, Rule 52)
--
--   ############################################################################
--   #  STAMP — ARTICLE ZERO                                                    #
--   #  anexomail.com ka har page, har subdomain, har user, BROWSER mein        #
--   #  chalta hai:  WASM KERNEL  =  Rust  +  async  +  Tokio  +  WebTransport  #
--   #  aur HMAC-SHA256 us kernel mein BUILTIN hai.                             #
--   #  Koi bhi naya feature PEHLE yahan se shuru hota hai: kernel (Rust,       #
--   #  Tokio, async, WebTransport, HMAC-SHA256) -> phir page / endpoint.       #
--   ############################################################################
--
-- Yeh file DATABASE ka dastoor hai: kaun si kernel release asli hai (wasm SHA-256 pin), kaun si surface (host) kernel ke bagair nahi
-- chal sakti, HMAC-SHA256 chaabiyan kaun si hain (rotation ke saath), session ticket kaise bante/parakhe jate hain, aur kernel ki
-- sehat ka hisaab. Dastoor ke articles append-only hain: badalna ho to NAYA article jo purane ko supersede kare.
--
-- Hissay:  1 constitution (immutable)   2 releases + modules + surfaces   3 HMAC keys (rotate)   4 sign / verify (constant-time)
--          5 session tickets + request tags   6 policy check + audit   7 compliance + self-audit   8 revenue truth (founder)
-- Sab SECURITY DEFINER, search_path pinned, EXECUTE sirf service_role (Rust engine). Tables par RLS on, koi policy nahi => anon/
-- authenticated ko kuch nahi dikhta. Rule 38/42/43/44: pehli line khali, apna BEGIN/COMMIT nahi, idempotent.
-- ============================================================================

create extension if not exists pgcrypto with schema extensions;

do $$ begin
  if to_regprocedure('extensions.hmac(bytea,bytea,text)') is null then
    raise exception 'E90 PREFLIGHT: pgcrypto (extensions.hmac) nahi mila';
  end if;
end $$;

-- ---------------------------------------------------------------- 1. CONSTITUTION (append-only)
create table if not exists public.kernel_constitution (
  article     integer primary key check (article >= 0),
  title       text not null check (length(title) between 3 and 160),
  body        text not null check (length(body) >= 20),
  supersedes  integer references public.kernel_constitution(article),
  enacted_at  timestamptz not null default now(),
  enacted_by  text not null default 'founder:nauman-sherwani'
);
alter table public.kernel_constitution enable row level security;
revoke all on public.kernel_constitution from public, anon, authenticated;
grant select, insert on public.kernel_constitution to service_role;

create or replace function public.kernel_constitution_immutable()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  raise exception 'KERNEL CONSTITUTION append-only hai: article % ko badla/hataya nahi ja sakta; naya article likho jo supersede kare', old.article
    using errcode = '42501';
end $$;

drop trigger if exists kernel_constitution_no_change on public.kernel_constitution;
create trigger kernel_constitution_no_change
  before update or delete on public.kernel_constitution
  for each row execute function public.kernel_constitution_immutable();

insert into public.kernel_constitution (article, title, body) values
 (0, 'STAMP: kernel pehle',
  'anexomail.com ka har page, har subdomain aur har user browser mein WASM KERNEL par chalta hai: Rust, async, Tokio, WebTransport; HMAC-SHA256 us mein builtin hai. Har naya kaam yahin se shuru hota hai: pehle kernel, phir page.'),
 (1, 'Ek kernel, Rust + async + Tokio',
  'Browser ka compute aur transport EK WASM kernel hai jo Rust mein likha gaya, Tokio ke LocalSet par async chalta hai. Bikhri hui wasm files, alag JS engines ya feature-wise transport banana mana hai. Naya client-heavy kaam = kernel ka naya module + version bump.'),
 (2, 'HMAC-SHA256 builtin',
  'Har signed cheez (session ticket, request tag, chunk tag, link, webhook, audit) HMAC-SHA256 hai. Kernel mein hmac@1 module hai; server par kernel_hmac_sign/verify. Chaabi kabhi browser ke page code ko nahi milti: server sirf is session ki derived key deta hai.'),
 (3, 'Ek connection, ek generic RPC',
  'Poori website ke liye EK WebTransport/QUIC connection aur EK generic rpc@1 hai. Har proc usi raaste se guzarta hai; alag endpoint ya page sirf isliye nahi banta ke feature naya hai.'),
 (4, 'Server hi gate hai',
  'WebTransport ka har stream wohi server dispatch() chalata hai jo HTTP chalata hai: package gate, rate limit, auth sab ek jagah. UI sirf aaina hai. Kernel ya UI ko gate samajhna mana hai.'),
 (5, 'Sacha fallback',
  'Kernel ya WebTransport na chale (purana browser, network, hash mismatch) to page plain fetch/HTTP par chalta rehta hai aur transport sachai se "fetch" likhta hai. Fallback kabhi chhupaya nahi jata, kabhi page nahi rokta.'),
 (6, 'Pin aur tamper',
  'Har kernel release ka wasm SHA-256 yahan (kernel_releases) aur frontend pin mein likha hai. Browser hash na milne par kernel load karne se inkaar karta hai. Revoked release hamesha block hoti hai.'),
 (7, 'Teen round test',
  'Kernel ki har release teen round se guzarti hai: (1) native Rust tests, (2) asli wasm bun mein, (3) asli browser + asli QUIC server. Teeno green hone par hi release current hoti hai.'),
 (8, 'Har surface registered',
  'anexomail.com ka har host (apex, www, har subdomain) kernel_surfaces mein darj hai. Naya subdomain pehle yahan likha jata hai, phir DNS/Caddy. Jo host darj nahi woh compliance mein violation dikhta hai.'),
 (9, 'Telemetry mein raaz nahi',
  'kernel_report sirf host, kernel version, wasm hash aur transport likhta hai. Na token, na email, na user ka content. HMAC chaabiyan kabhi log, response ya report mein nahi aati.'),
 (10, 'Flat price, kernel ke bagair bhi sach',
  'Kernel koi package gate nahi kholta aur koi qeemat nahi badalta. Rule 51 (flat per-company price) aur Rule 53 (gate pehle formula file mein) kernel se upar hain.')
on conflict (article) do nothing;

-- ---------------------------------------------------------------- 2. RELEASES, MODULES, SURFACES
create or replace function public.kernel_semver_arr(p_v text)
returns integer[]
language sql
immutable
set search_path = public, pg_temp
as $$
  select case when p_v ~ '^[0-9]+\.[0-9]+\.[0-9]+$'
              then array(select x::integer from unnest(string_to_array(p_v, '.')) as x)
              else null end;
$$;

create table if not exists public.kernel_releases (
  version       text primary key check (public.kernel_semver_arr(version) is not null),
  wasm_sha256   text not null check (wasm_sha256 ~ '^[0-9a-f]{64}$'),
  abi           integer not null default 1 check (abi >= 1),
  modules       text[] not null,
  status        text not null default 'supported' check (status in ('current','supported','deprecated','revoked')),
  notes         text not null default '',
  published_at  timestamptz not null default now(),
  unique (wasm_sha256)
);
create unique index if not exists kernel_releases_one_current on public.kernel_releases ((status)) where status = 'current';
alter table public.kernel_releases enable row level security;
revoke all on public.kernel_releases from public, anon, authenticated;
grant select, insert, update on public.kernel_releases to service_role;

insert into public.kernel_releases (version, wasm_sha256, abi, modules, status, notes) values
 ('0.1.0', '0533758d867ff015c43ef7bc3b8210e8abe4853dbc995cb6bf32a74cf7f978c1', 1,
  array['sha256@1','sniff@1','rank@1','live@1','rpc@1'], 'deprecated', 'pehli release: live + rpc, hmac nahi'),
 ('0.2.0', '7b1ddb7c7e31d7a8d6ffd78593470563fae99e4823a12344a8c600d109f01312', 1,
  array['sha256@1','hmac@1','sniff@1','rank@1','live@1','rpc@1'], 'current', 'HMAC-SHA256 builtin, rpc in-flight gate (32)')
on conflict (version) do nothing;

create table if not exists public.kernel_modules (
  name        text not null,
  version     integer not null default 1 check (version >= 1),
  since       text not null check (public.kernel_semver_arr(since) is not null),
  article     integer not null references public.kernel_constitution(article),
  summary     text not null,
  primary key (name, version)
);
alter table public.kernel_modules enable row level security;
revoke all on public.kernel_modules from public, anon, authenticated;
grant select, insert on public.kernel_modules to service_role;

insert into public.kernel_modules (name, version, since, article, summary) values
 ('sha256', 1, '0.1.0', 2, 'streaming SHA-256: upload se pehle bade attachment ka digest'),
 ('hmac',   1, '0.2.0', 2, 'HMAC-SHA256 (RFC 2104/4231): session tag, constant-time verify'),
 ('sniff',  1, '0.1.0', 4, 'attachment ke asli bytes (magic) ki jaanch: exe / naam-bytes mismatch'),
 ('rank',   1, '0.1.0', 1, 'bade lists ki fast ranking browser mein'),
 ('live',   1, '0.1.0', 3, 'live push (mail/calendar/crm/work/people/org) WebTransport par'),
 ('rpc',    1, '0.1.0', 3, 'ek QUIC session, har call naya bidi stream, generic proc')
on conflict (name, version) do nothing;

create table if not exists public.kernel_surfaces (
  host_pattern   text primary key check (host_pattern = lower(host_pattern) and host_pattern ~ '^(\*\.)?[a-z0-9.-]+$'),
  label          text not null,
  kind           text not null check (kind in ('apex','www','subdomain','wildcard')),
  requires_kernel boolean not null default true,
  min_kernel     text not null default '0.2.0' check (public.kernel_semver_arr(min_kernel) is not null),
  transport      text not null default 'webtransport' check (transport in ('webtransport')),
  fallback       text not null default 'fetch' check (fallback in ('fetch')),
  created_at     timestamptz not null default now()
);
alter table public.kernel_surfaces enable row level security;
revoke all on public.kernel_surfaces from public, anon, authenticated;
grant select, insert, update on public.kernel_surfaces to service_role;

insert into public.kernel_surfaces (host_pattern, label, kind) values
 ('anexomail.com',                'ANEXOMAIL apex (marketing + app)',      'apex'),
 ('www.anexomail.com',            'ANEXOMAIL www',                         'www'),
 ('mail.anexomail.com',           'ANEXOMAIL mail',                        'subdomain'),
 ('anexochat.anexomail.com',      'ANEXOChat + WebTransport udp/3443',     'subdomain'),
 ('anexovideocall.anexomail.com', 'ANEXOVideoCall',                        'subdomain'),
 ('rooms.anexomail.com',          'Rooms',                                 'subdomain'),
 ('crm.anexomail.com',            'CRM',                                   'subdomain'),
 ('aicrm.anexomail.com',          'AI CRM',                                'subdomain'),
 ('ai.anexomail.com',             'AI (COMING SOON)',                      'subdomain'),
 ('aiemail.anexomail.com',        'AI email (COMING SOON)',                'subdomain'),
 ('founderworkspace.anexomail.com','Founder workspace',                    'subdomain'),
 ('polarpayments.anexomail.com',  'Payments (Polar)',                      'subdomain'),
 ('billingportal.anexomail.com',  'Billing portal',                        'subdomain'),
 ('security-check.anexomail.com', 'Security check',                        'subdomain'),
 ('api.anexomail.com',            'API gateway',                           'subdomain'),
 ('*.anexomail.com',              'Koi bhi aur subdomain (Article 8: pehle darj karo)', 'wildcard')
on conflict (host_pattern) do nothing;

-- Host ke liye sab se khaas (specific) surface: exact > wildcard.
create or replace function public.kernel_surface_for(p_host text)
returns public.kernel_surfaces
language sql
stable
set search_path = public, pg_temp
as $$
  select s.* from public.kernel_surfaces s
   where s.host_pattern = lower(btrim(p_host))
      or (s.host_pattern like '*.%' and lower(btrim(p_host)) like '%' || substr(s.host_pattern, 2)
          and lower(btrim(p_host)) <> substr(s.host_pattern, 3))
   order by (s.host_pattern = lower(btrim(p_host))) desc, length(s.host_pattern) desc
   limit 1;
$$;

create or replace function public.kernel_semver_lt(p_a text, p_b text)
returns boolean
language sql
immutable
set search_path = public, pg_temp
as $$ select public.kernel_semver_arr(p_a) < public.kernel_semver_arr(p_b); $$;

-- ---------------------------------------------------------------- 3. HMAC KEYS (rotation ke saath)
create table if not exists public.kernel_hmac_keys (
  key_id      text primary key default encode(extensions.gen_random_bytes(6), 'hex'),
  purpose     text not null check (purpose in ('ticket','chunk','link','webhook','audit')),
  secret      bytea not null check (octet_length(secret) = 32),
  status      text not null default 'active' check (status in ('active','retiring','revoked')),
  not_before  timestamptz not null default now(),
  not_after   timestamptz,
  created_at  timestamptz not null default now(),
  check (not_after is null or not_after > not_before)
);
create unique index if not exists kernel_hmac_one_active on public.kernel_hmac_keys (purpose) where status = 'active';
alter table public.kernel_hmac_keys enable row level security;
revoke all on public.kernel_hmac_keys from public, anon, authenticated;
-- service_role bhi seedha secret nahi padhta: sirf neeche ke SECURITY DEFINER functions.
revoke all on public.kernel_hmac_keys from service_role;

create or replace function public.kernel_hmac_ensure_keys()
returns integer
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare p text; n integer := 0;
begin
  foreach p in array array['ticket','chunk','link','webhook','audit'] loop
    if not exists (select 1 from public.kernel_hmac_keys where purpose = p and status = 'active') then
      insert into public.kernel_hmac_keys (purpose, secret) values (p, extensions.gen_random_bytes(32));
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;

-- Rotation: purani active "retiring" (24h tak verify chalta hai, sign nahi), nayi active.
create or replace function public.kernel_hmac_rotate(p_purpose text, p_grace interval default interval '24 hours')
returns text
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare k text;
begin
  if p_purpose not in ('ticket','chunk','link','webhook','audit') then
    raise exception 'unknown purpose %', p_purpose using errcode = '22023';
  end if;
  update public.kernel_hmac_keys
     set status = 'retiring', not_after = now() + p_grace
   where purpose = p_purpose and status = 'active';
  insert into public.kernel_hmac_keys (purpose, secret) values (p_purpose, extensions.gen_random_bytes(32))
  returning key_id into k;
  return k;
end $$;

-- ---------------------------------------------------------------- 4. SIGN / VERIFY
-- Tag format: "<key_id>.<hex hmac-sha256>". Message domain-separated: purpose || ':' || msg.
create or replace function public.kernel_hmac_sign(p_purpose text, p_msg text)
returns text
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare k record;
begin
  select key_id, secret into k from public.kernel_hmac_keys
   where purpose = p_purpose and status = 'active' and not_before <= now() limit 1;
  if not found then
    perform public.kernel_hmac_ensure_keys();
    select key_id, secret into k from public.kernel_hmac_keys
     where purpose = p_purpose and status = 'active' and not_before <= now() limit 1;
    if not found then raise exception 'no active hmac key for %', p_purpose using errcode = '55000'; end if;
  end if;
  return k.key_id || '.' || encode(extensions.hmac(convert_to(p_purpose || ':' || coalesce(p_msg, ''), 'UTF8'), k.secret, 'sha256'), 'hex');
end $$;

-- Constant-time-ish: dono tags ko ek taaza random key se dobara HMAC karke barabar dekhte hain (timing se tag andaza nahi).
create or replace function public.kernel_hmac_verify(p_purpose text, p_msg text, p_tag text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare kid text; given text; k record; want text; salt bytea := extensions.gen_random_bytes(16);
begin
  if p_tag is null or position('.' in p_tag) = 0 then return false; end if;
  kid := split_part(p_tag, '.', 1);
  given := substr(p_tag, length(kid) + 2);
  if given !~ '^[0-9a-f]{64}$' then return false; end if;
  select secret into k from public.kernel_hmac_keys
   where key_id = kid and purpose = p_purpose and status in ('active','retiring')
     and not_before <= now() and (not_after is null or not_after > now());
  if not found then return false; end if;
  want := encode(extensions.hmac(convert_to(p_purpose || ':' || coalesce(p_msg, ''), 'UTF8'), k.secret, 'sha256'), 'hex');
  return extensions.hmac(convert_to(want, 'UTF8'), salt, 'sha256') = extensions.hmac(convert_to(given, 'UTF8'), salt, 'sha256');
end $$;

-- ---------------------------------------------------------------- 5. SESSION TICKET + REQUEST TAG
-- Ticket: v1.<user>.<exp_epoch>.<nonce>.<kid>.<tag>   (tag = HMAC('ticket', user|exp|nonce|host))
-- Session key (browser ko TLS par ek baar milti hai, kernel hmac@1 se har request par tag lagata hai):
--   hex(HMAC-SHA256(server_secret, 'session-key:' || ticket_body))
create or replace function public.kernel_ticket_issue(p_user uuid, p_host text, p_ttl_s integer default 900)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare ttl integer := least(greatest(coalesce(p_ttl_s, 900), 30), 3600);
        exp bigint := extract(epoch from now())::bigint + ttl;
        nonce text := encode(extensions.gen_random_bytes(8), 'hex');
        host text := lower(btrim(coalesce(p_host, '')));
        body text; tag text; skey text;
begin
  if p_user is null or host = '' then raise exception 'user and host required' using errcode = '22023'; end if;
  body := p_user::text || '|' || exp || '|' || nonce || '|' || host;
  tag := public.kernel_hmac_sign('ticket', body);
  skey := public.kernel_hmac_sign('ticket', 'session-key:' || body);
  return jsonb_build_object(
    'ticket', 'v1.' || p_user::text || '.' || exp || '.' || nonce || '.' || tag,
    'expires_at', to_char(to_timestamp(exp) at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'session_key', split_part(skey, '.', 2),
    'transport', 'webtransport', 'tag_alg', 'HMAC-SHA256');
end $$;

create or replace function public.kernel_ticket_verify(p_ticket text, p_host text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare parts text[]; uid uuid; exp bigint; body text; host text := lower(btrim(coalesce(p_host, '')));
begin
  parts := string_to_array(coalesce(p_ticket, ''), '.');
  if coalesce(array_length(parts, 1), 0) <> 6 or parts[1] <> 'v1' then
    return jsonb_build_object('ok', false, 'reason', 'malformed');
  end if;
  begin
    uid := parts[2]::uuid; exp := parts[3]::bigint;
  exception when others then
    return jsonb_build_object('ok', false, 'reason', 'malformed');
  end;
  if exp < extract(epoch from now())::bigint then return jsonb_build_object('ok', false, 'reason', 'expired'); end if;
  body := uid::text || '|' || exp || '|' || parts[4] || '|' || host;
  if not public.kernel_hmac_verify('ticket', body, parts[5] || '.' || parts[6]) then
    return jsonb_build_object('ok', false, 'reason', 'bad_tag');
  end if;
  return jsonb_build_object('ok', true, 'user_id', uid, 'expires_epoch', exp);
end $$;

-- Request tag: browser kernel ne HMAC-SHA256(session_key, msg) bheja; server wahi session key dobara nikaal kar compare karta hai.
create or replace function public.kernel_request_verify(p_ticket text, p_host text, p_msg text, p_tag_hex text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare v jsonb; parts text[]; body text; skey text; want text; salt bytea := extensions.gen_random_bytes(16);
begin
  v := public.kernel_ticket_verify(p_ticket, p_host);
  if not coalesce((v->>'ok')::boolean, false) then return false; end if;
  if p_tag_hex is null or p_tag_hex !~ '^[0-9a-f]{64}$' then return false; end if;
  parts := string_to_array(p_ticket, '.');
  body := parts[2] || '|' || parts[3] || '|' || parts[4] || '|' || lower(btrim(p_host));
  skey := split_part(public.kernel_hmac_sign('ticket', 'session-key:' || body), '.', 2);
  want := encode(extensions.hmac(convert_to(coalesce(p_msg, ''), 'UTF8'), convert_to(skey, 'UTF8'), 'sha256'), 'hex');
  return extensions.hmac(convert_to(want, 'UTF8'), salt, 'sha256') = extensions.hmac(convert_to(p_tag_hex, 'UTF8'), salt, 'sha256');
end $$;

-- ---------------------------------------------------------------- 6. POLICY CHECK + AUDIT
create table if not exists public.kernel_sessions (
  id           bigint generated always as identity primary key,
  user_id      uuid,
  host         text not null check (length(host) <= 253),
  kernel_version text not null check (length(kernel_version) <= 32),
  wasm_sha256  text check (wasm_sha256 is null or wasm_sha256 ~ '^[0-9a-f]{64}$'),
  transport    text not null check (transport in ('webtransport','fetch','none')),
  allowed      boolean not null,
  action       text not null check (action in ('ok','upgrade','block')),
  reason       text not null default 'ok',
  created_at   timestamptz not null default now()
);
create index if not exists kernel_sessions_recent on public.kernel_sessions (created_at desc);
create index if not exists kernel_sessions_host_recent on public.kernel_sessions (host, created_at desc);
alter table public.kernel_sessions enable row level security;
revoke all on public.kernel_sessions from public, anon, authenticated;
grant select on public.kernel_sessions to service_role;

-- Dastoor ka faisla: (host, version, sha, transport) -> {allowed, action: ok|upgrade|block, reason, degraded, current}
create or replace function public.kernel_policy_check(p_host text, p_version text, p_sha text, p_transport text default 'webtransport')
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare s public.kernel_surfaces; r public.kernel_releases; cur text; reason text := 'ok'; act text := 'ok'; degraded boolean;
begin
  select version into cur from public.kernel_releases where status = 'current';
  s := public.kernel_surface_for(p_host);
  select * into r from public.kernel_releases where version = p_version;
  degraded := coalesce(p_transport, 'none') <> 'webtransport';
  if r.version is null then
    act := 'upgrade'; reason := 'unknown_version';
  elsif lower(coalesce(p_sha, '')) <> r.wasm_sha256 then
    act := 'block'; reason := 'tampered';
  elsif r.status = 'revoked' then
    act := 'block'; reason := 'revoked';
  elsif r.status = 'deprecated' then
    act := 'upgrade'; reason := 'deprecated';
  elsif s.host_pattern is not null and public.kernel_semver_lt(p_version, s.min_kernel) then
    act := 'upgrade'; reason := 'below_surface_minimum';
  end if;
  return jsonb_build_object(
    'allowed', act <> 'block', 'action', act, 'reason', reason, 'degraded', degraded,
    'current', cur, 'surface', s.host_pattern, 'registered', s.host_pattern is not null,
    'article', case act when 'block' then 6 when 'upgrade' then 7 else 0 end);
end $$;

create or replace function public.kernel_report(p_user uuid, p_host text, p_version text, p_sha text, p_transport text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v jsonb; t text := case when p_transport in ('webtransport','fetch') then p_transport else 'none' end;
        host text := left(lower(btrim(coalesce(p_host, ''))), 253);
begin
  if host = '' then raise exception 'host required' using errcode = '22023'; end if;
  v := public.kernel_policy_check(host, left(coalesce(p_version, ''), 32), p_sha, t);
  insert into public.kernel_sessions (user_id, host, kernel_version, wasm_sha256, transport, allowed, action, reason)
  values (p_user, host, left(coalesce(p_version, ''), 32),
          case when lower(coalesce(p_sha, '')) ~ '^[0-9a-f]{64}$' then lower(p_sha) end,
          t, (v->>'allowed')::boolean, v->>'action', v->>'reason');
  return v;
end $$;

create or replace function public.kernel_prune(p_days integer default 30)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare n integer;
begin
  delete from public.kernel_sessions where created_at < now() - make_interval(days => greatest(coalesce(p_days, 30), 7));
  get diagnostics n = row_count;
  return n;
end $$;

-- ---------------------------------------------------------------- 7. COMPLIANCE + SELF-AUDIT
-- Pichle 24 ghante: har host par kitne session, kitne asli WebTransport par, kitne block / upgrade.
create or replace view public.kernel_compliance as
select s.host,
       count(*)                                                         as sessions,
       count(*) filter (where s.transport = 'webtransport')             as webtransport,
       round(100.0 * count(*) filter (where s.transport = 'webtransport') / greatest(count(*), 1), 1) as webtransport_pct,
       count(*) filter (where s.action = 'upgrade')                     as need_upgrade,
       count(*) filter (where s.action = 'block')                       as blocked,
       max(s.created_at)                                                as last_seen
  from public.kernel_sessions s
 where s.created_at > now() - interval '24 hours'
 group by s.host;
revoke all on public.kernel_compliance from public, anon, authenticated;
grant select on public.kernel_compliance to service_role;

-- Dastoor ki khud-jaanch: ok=false to violations mein wajah. (CHECK_E90 isi ko chalata hai.)
create or replace function public.kernel_constitution_ok()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare v text[] := '{}'; cur public.kernel_releases; need text; n integer;
begin
  select * into cur from public.kernel_releases where status = 'current';
  if cur.version is null then v := v || 'no_current_release'; end if;
  if cur.version is not null and not ('hmac@1' = any (cur.modules) and 'rpc@1' = any (cur.modules) and 'live@1' = any (cur.modules)) then
    v := v || 'current_release_missing_hmac_rpc_or_live';
  end if;
  select count(*) into n from public.kernel_constitution where article between 0 and 10;
  if n < 11 then v := v || 'constitution_articles_missing'; end if;
  foreach need in array array['sha256','hmac','sniff','rank','live','rpc'] loop
    if not exists (select 1 from public.kernel_modules where name = need) then v := v || ('module_missing:' || need); end if;
  end loop;
  foreach need in array array['ticket','chunk','link','webhook','audit'] loop
    if not exists (select 1 from public.kernel_hmac_keys where purpose = need and status = 'active') then
      v := v || ('no_active_hmac_key:' || need);
    end if;
  end loop;
  if cur.version is not null and exists (select 1 from public.kernel_surfaces s
        where s.requires_kernel and public.kernel_semver_lt(cur.version, s.min_kernel)) then
    v := v || 'surface_requires_newer_kernel_than_current';
  end if;
  if not exists (select 1 from public.kernel_surfaces where host_pattern = '*.anexomail.com') then
    v := v || 'wildcard_surface_missing';
  end if;
  if exists (select 1 from public.kernel_surfaces where not requires_kernel) then
    v := v || 'surface_without_kernel';
  end if;
  return jsonb_build_object('ok', coalesce(array_length(v, 1), 0) = 0, 'violations', to_jsonb(v),
                            'current', cur.version, 'stamp', 'Rust + async + Tokio + WebTransport + HMAC-SHA256');
end $$;

-- Naya wasm build ke baad: is function se release darj karo (build-kernel.sh yahi INSERT chhapta hai). current tabhi jab 3 round pass.
create or replace function public.kernel_release_publish(p_version text, p_sha text, p_modules text[], p_notes text default '')
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.kernel_releases set status = 'deprecated' where status = 'current';
  insert into public.kernel_releases (version, wasm_sha256, modules, status, notes)
  values (p_version, lower(p_sha), p_modules, 'current', coalesce(p_notes, ''))
  on conflict (version) do update set wasm_sha256 = excluded.wasm_sha256, modules = excluded.modules,
        status = 'current', notes = excluded.notes;
  return public.kernel_constitution_ok();
end $$;

-- ---------------------------------------------------------------- 8. REVENUE TRUTH (founder): flat price, Rule 51
do $$ begin
  if to_regclass('public.revenue_accounts') is not null then
    alter table public.revenue_accounts add column if not exists cancelled_at timestamptz;
    alter table public.revenue_accounts drop constraint if exists revenue_accounts_plan_check;
    alter table public.revenue_accounts add constraint revenue_accounts_plan_check
      check (plan in ('basic','pro','business','business_pro','enterprise'));
    alter table public.revenue_accounts drop constraint if exists revenue_accounts_status_check;
    alter table public.revenue_accounts add constraint revenue_accounts_status_check
      check (status in ('trial','active','past_due','paused','churned'));
  end if;
end $$;

create or replace function public.flat_plan_price(p_plan text)
returns numeric
language sql
immutable
set search_path = public, pg_temp
as $$ select case lower(coalesce(p_plan, ''))
        when 'basic' then 40 when 'pro' then 105 when 'business' then 360 when 'business_pro' then 2850
        else 0 end::numeric; $$;   -- enterprise: apni mrr_gbp row (alag contract)

create or replace function public.founder_revenue_truth()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare out jsonb;
begin
  if to_regclass('public.revenue_accounts') is null then
    return jsonb_build_object('mrr', 0, 'arr', 0, 'currency', 'GBP', 'paying_tenants', 0, 'trialing', 0, 'past_due', 0,
                              'churn_30d', 0, 'by_plan', '[]'::jsonb, 'unpaid_total', 0, 'method', 'revenue_accounts table nahi');
  end if;
  with a as (
    select plan, status,
           case when mrr_gbp > 0 then mrr_gbp else public.flat_plan_price(plan) end as m,
           cancelled_at
      from public.revenue_accounts)
  select jsonb_build_object(
    'mrr',            coalesce(sum(m) filter (where status in ('active','past_due')), 0),
    'arr',            coalesce(sum(m) filter (where status in ('active','past_due')), 0) * 12,
    'currency',       'GBP',
    'paying_tenants', count(*) filter (where status = 'active'),
    'trialing',       count(*) filter (where status = 'trial'),
    'past_due',       count(*) filter (where status = 'past_due'),
    'churn_30d',      count(*) filter (where status = 'churned' and cancelled_at > now() - interval '30 days'),
    'unpaid_total',   coalesce(sum(m) filter (where status = 'past_due'), 0),
    'by_plan', coalesce((select jsonb_agg(jsonb_build_object('plan', p.plan, 'tenants', p.t, 'mrr', p.s) order by p.s desc)
                           from (select plan, count(*) as t, sum(m) as s from a where status in ('active','past_due') group by plan) p), '[]'::jsonb),
    'method', 'flat per-company price (Rule 51); mrr_gbp > 0 ho to wahi; enterprise apni row')
  into out from a;
  return out;
end $$;

-- ---------------------------------------------------------------- 9. GRANTS: sirf Rust engine (service_role)
do $$
declare f text;
begin
  foreach f in array array[
    'kernel_hmac_ensure_keys()', 'kernel_hmac_rotate(text,interval)', 'kernel_hmac_sign(text,text)', 'kernel_hmac_verify(text,text,text)',
    'kernel_ticket_issue(uuid,text,integer)', 'kernel_ticket_verify(text,text)', 'kernel_request_verify(text,text,text,text)',
    'kernel_policy_check(text,text,text,text)', 'kernel_report(uuid,text,text,text,text)', 'kernel_prune(integer)',
    'kernel_constitution_ok()', 'kernel_release_publish(text,text,text[],text)', 'founder_revenue_truth()'
  ] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to service_role', f);
  end loop;
end $$;

-- ---------------------------------------------------------------- 10. SHURU: chaabiyan banao + khud-jaanch
select public.kernel_hmac_ensure_keys();

do $$
declare r jsonb; t jsonb; ok boolean;
begin
  r := public.kernel_constitution_ok();
  if not (r->>'ok')::boolean then raise exception 'E90 SELF-TEST: constitution violations %', r->'violations'; end if;
  -- HMAC: RFC 4231 test case 2 (Jefe) — extensions.hmac wahi deta hai jo browser kernel deta hai
  if encode(extensions.hmac(convert_to('what do ya want for nothing?', 'UTF8'), convert_to('Jefe', 'UTF8'), 'sha256'), 'hex')
       <> '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843' then
    raise exception 'E90 SELF-TEST: HMAC-SHA256 RFC4231 vector fail';
  end if;
  -- sign/verify round trip + tamper
  if not public.kernel_hmac_verify('link', 'x', public.kernel_hmac_sign('link', 'x')) then raise exception 'E90 SELF-TEST: sign/verify'; end if;
  if public.kernel_hmac_verify('link', 'y', public.kernel_hmac_sign('link', 'x')) then raise exception 'E90 SELF-TEST: tamper accepted'; end if;
  if public.kernel_hmac_verify('chunk', 'x', public.kernel_hmac_sign('link', 'x')) then raise exception 'E90 SELF-TEST: purpose separation'; end if;
  -- ticket + request tag
  t := public.kernel_ticket_issue('00000000-0000-4000-8000-000000000001', 'anexomail.com', 120);
  if not (public.kernel_ticket_verify(t->>'ticket', 'anexomail.com')->>'ok')::boolean then raise exception 'E90 SELF-TEST: ticket'; end if;
  if (public.kernel_ticket_verify(t->>'ticket', 'evil.example')->>'ok')::boolean then raise exception 'E90 SELF-TEST: ticket host binding'; end if;
  ok := public.kernel_request_verify(t->>'ticket', 'anexomail.com', 'mail.threads',
          encode(extensions.hmac(convert_to('mail.threads', 'UTF8'), convert_to(t->>'session_key', 'UTF8'), 'sha256'), 'hex'));
  if not ok then raise exception 'E90 SELF-TEST: request tag'; end if;
  -- policy
  if (public.kernel_policy_check('crm.anexomail.com', '0.2.0', '7b1ddb7c7e31d7a8d6ffd78593470563fae99e4823a12344a8c600d109f01312')->>'action') <> 'ok' then
    raise exception 'E90 SELF-TEST: policy ok'; end if;
  if (public.kernel_policy_check('crm.anexomail.com', '0.2.0', repeat('0', 64))->>'action') <> 'block' then raise exception 'E90 SELF-TEST: tamper block'; end if;
  if (public.kernel_policy_check('crm.anexomail.com', '0.1.0', '0533758d867ff015c43ef7bc3b8210e8abe4853dbc995cb6bf32a74cf7f978c1')->>'action') <> 'upgrade' then
    raise exception 'E90 SELF-TEST: deprecated upgrade'; end if;
end $$;

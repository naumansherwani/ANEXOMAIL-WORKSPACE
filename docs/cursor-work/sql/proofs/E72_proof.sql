-- E72 behaviour proof (sandbox ONLY, rollback). Chalao: cd docs/cursor-work/sql/proofs && psql -v ON_ERROR_STOP=1 -f E72_proof.sql
-- Live phase23/E68 tables ke chhote stubs ke saath E72 lagti hai (do baar: idempotent), phir har dewar ka saboot.
begin;
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key, email text, created_at timestamptz not null default now());
create schema if not exists extensions;
create table public.device_ban_appeals (id uuid primary key default gen_random_uuid(), device_hash text not null, user_id uuid not null, statement text not null,
  state text not null default 'new' check (state in ('new','reviewing','granted','denied')), decided_by uuid, decision_reason text,
  created_at timestamptz not null default now(), decided_at timestamptz);
create table public.device_bans (device_hash text primary key, appealable boolean not null default true);
create table public.device_vault (id uuid primary key default gen_random_uuid(), user_id uuid not null, device_hash text not null);
create table public.device_trust_events (id bigserial primary key, user_id uuid, device_hash text, event text, actor text, detail jsonb);
create table public.account_integrity (user_id uuid primary key, state text not null default 'clean');
create table public.founder_accounts (user_id uuid primary key);
create or replace function public.safety_can_review(_user uuid) returns boolean language sql stable as $f$ select exists (select 1 from public.founder_accounts where user_id = _user) $f$;
create table public.identity_signup_appeals (id uuid primary key default gen_random_uuid(), created_at timestamptz not null default now(),
  contact text not null, statement text not null check (char_length(statement) between 20 and 2000), state text not null default 'new');
\i ../E72_appeal_evidence.sql
\i ../E72_appeal_evidence.sql
create temp table r (ord int, item text, ok boolean) on commit drop;
do $$
declare
  f uuid := gen_random_uuid(); u uuid := gen_random_uuid(); s uuid := gen_random_uuid(); x uuid := gen_random_uuid(); g uuid := gen_random_uuid();
  res jsonb; i int; id1 uuid; id2 uuid; ev uuid[] := '{}'; ap uuid; raised boolean; sha text; n int;
  big text := repeat('a', 20000);
begin
  insert into auth.users (id, email) values (f, 'f@x'), (u, 'u@x'), (s, 's@x'), (x, 'x@x'), (g, 'g@x');
  insert into public.founder_accounts values (f);
  insert into public.device_bans (device_hash) values ('dev-u'), ('dev-u2'), ('dev-x');
  insert into public.device_vault (user_id, device_hash) values (u, 'dev-u'), (u, 'dev-u2'), (x, 'dev-x');
  insert into public.account_integrity values (u, 'blocked'), (x, 'blocked');

  -- ===== 1. kaun upload kar sakta hai =====
  res := public.appeal_evidence_register(s, repeat('1', 64), 100, 'a.png', 'image/png', 'appeals/' || s || '/11/' || repeat('1', 64) || '-aaaaaaaa');
  insert into r values (1, 'jis par koi ban nahi => nothing_to_appeal (storage ka galat istemal nahi)', res ->> 'error' = 'nothing_to_appeal');
  res := public.appeal_evidence_ctx(u);
  insert into r values (2, 'ctx: eligible, 20000 / 5 files / 10MB / 25MB', (res ->> 'eligible')::boolean and (res ->> 'statement_max')::int = 20000 and (res ->> 'max_files')::int = 5
    and (res ->> 'max_file_bytes')::bigint = 10000000 and (res ->> 'max_total_bytes')::bigint = 25000000);
  res := public.appeal_evidence_ctx(null);
  insert into r values (3, 'ctx bina user => unauthorized', res ->> 'error' = 'unauthorized');

  -- ===== 2. register =====
  sha := repeat('a', 64);
  res := public.appeal_evidence_register(u, sha, 1234, 'shot.png', 'image/png', 'appeals/' || u || '/aa/' || sha || '-00000001', '{"scanned":true}');
  id1 := (res ->> 'id')::uuid;
  insert into r values (4, 'pehli file ok, deduped false', (res ->> 'ok')::boolean and not (res ->> 'deduped')::boolean and id1 is not null);
  res := public.appeal_evidence_register(u, sha, 1234, 'again.png', 'image/png', 'appeals/' || u || '/aa/' || sha || '-00000002');
  insert into r values (5, 'wahi file dobara => deduped true, wahi id, nayi row nahi', (res ->> 'deduped')::boolean and (res ->> 'id')::uuid = id1
    and (select count(*) from public.appeal_evidence where user_id = u) = 1);
  res := public.appeal_evidence_register(x, sha, 1234, 'shot.png', 'image/png', 'appeals/' || x || '/aa/' || sha || '-00000003');
  insert into r values (6, 'dedup sirf usi user ke andar (doosre user ki wahi file alag row)', (res ->> 'ok')::boolean and not (res ->> 'deduped')::boolean and (res ->> 'id')::uuid <> id1);
  res := public.appeal_evidence_register(u, repeat('b', 64), 10000001, 'big.pdf', 'application/pdf', 'appeals/' || u || '/bb/' || repeat('b', 64) || '-00000001');
  insert into r values (7, '10,000,001 bytes => file_too_large (limit 10,000,000)', res ->> 'error' = 'file_too_large' and (res ->> 'limit_bytes')::bigint = 10000000);
  res := public.appeal_evidence_register(u, 'xyz', 10, 'a', 'x', 'appeals/' || u || '/aa/' || sha || '-00000001');
  insert into r values (8, 'ghalat sha256 => bad_file', res ->> 'error' = 'bad_file');
  res := public.appeal_evidence_register(u, repeat('c', 64), 0, 'a', 'x', 'appeals/' || u || '/cc/' || repeat('c', 64) || '-00000001');
  insert into r values (9, '0 bytes => bad_file', res ->> 'error' = 'bad_file');
  begin
    perform public.appeal_evidence_register(u, repeat('d', 64), 10, 'a', 'x', '../../etc/passwd'); raised := false;
  exception when check_violation then raised := true; end;
  insert into r values (10, 'rel_path ki shakl ghalat (../ wagera) => DB hi rad kar deta hai', raised);

  -- ===== 3. hadein: 5 files, 25MB, rate =====
  for i in 2..5 loop
    res := public.appeal_evidence_register(u, repeat(i::text, 64), 1000 * i, 'f' || i || '.pdf', 'application/pdf', 'appeals/' || u || '/' || repeat(i::text, 2) || '/' || repeat(i::text, 64) || '-0000000' || i);
  end loop;
  insert into r values (11, '5 files tak ok', (select count(*) from public.appeal_evidence where user_id = u and removed_at is null) = 5);
  res := public.appeal_evidence_register(u, repeat('6', 64), 1000, 'f6.pdf', 'application/pdf', 'appeals/' || u || '/66/' || repeat('6', 64) || '-00000006');
  insert into r values (12, '6thi file => too_many_files (limit 5)', res ->> 'error' = 'too_many_files' and (res ->> 'limit')::int = 5);
  -- 25MB
  res := public.appeal_evidence_register(g, repeat('7', 64), 9000000, 'a.pdf', 'application/pdf', 'appeals/' || g || '/77/' || repeat('7', 64) || '-00000001');
  insert into r values (13, 'baghair ban wale user ko 9MB bhi nahi (g eligible nahi)', res ->> 'error' = 'nothing_to_appeal');
  insert into public.account_integrity values (g, 'warned');
  perform public.appeal_evidence_register(g, repeat('7', 64), 9000000, 'a.pdf', 'application/pdf', 'appeals/' || g || '/77/' || repeat('7', 64) || '-00000001');
  perform public.appeal_evidence_register(g, repeat('8', 64), 9000000, 'b.pdf', 'application/pdf', 'appeals/' || g || '/88/' || repeat('8', 64) || '-00000001');
  res := public.appeal_evidence_register(g, repeat('9', 64), 9000000, 'c.pdf', 'application/pdf', 'appeals/' || g || '/99/' || repeat('9', 64) || '-00000001');
  insert into r values (14, '3 x 9MB = 27MB > 25MB => total_too_large', res ->> 'error' = 'total_too_large' and (res ->> 'limit_bytes')::bigint = 25000000);
  update public.appeal_limits set value = 2 where key = 'max_uploads_per_day';
  res := public.appeal_evidence_register(g, repeat('e', 64), 10, 'd.pdf', 'application/pdf', 'appeals/' || g || '/ee/' || repeat('e', 64) || '-00000001');
  insert into r values (15, '24 ghante mein upload had paar => rate_limited', res ->> 'error' = 'rate_limited');
  update public.appeal_limits set value = 20 where key = 'max_uploads_per_day';

  -- ===== 4. remove =====
  select id into id2 from public.appeal_evidence where user_id = u and sha256 = repeat('5', 64);
  res := public.appeal_evidence_remove(u, id2);
  insert into r values (16, 'staged file hatai => ok', (res ->> 'ok')::boolean);
  res := public.appeal_evidence_remove(u, id2);
  insert into r values (17, 'dobara hatana => not_found', res ->> 'error' = 'not_found');
  res := public.appeal_evidence_remove(x, id1);
  insert into r values (18, 'doosre ki file nahi hata sakte => not_found', res ->> 'error' = 'not_found');
  res := public.appeal_evidence_register(u, repeat('5', 64), 5000, 'f5.pdf', 'application/pdf', 'appeals/' || u || '/55/' || repeat('5', 64) || '-0000000a');
  insert into r values (19, 'hatane ke baad wahi file naye sire se upload ho sakti hai (jagah khuli)', (res ->> 'ok')::boolean and not (res ->> 'deduped')::boolean);

  -- ===== 5. statement ki had =====
  res := public.device_appeal_open_v2(u, 'dev-u', repeat('a', 19), '{}');
  insert into r values (20, '19 characters => statement_required', res ->> 'error' = 'statement_required');
  res := public.device_appeal_open_v2(u, 'dev-u', big || 'b', '{}');
  insert into r values (21, '20,001 characters => statement_too_long (limit 20000), appeal nahi bana', res ->> 'error' = 'statement_too_long' and (res ->> 'limit')::int = 20000
    and not exists (select 1 from public.device_ban_appeals where user_id = u));
  res := public.device_appeal_open_v2(u, 'dev-zzz', big, '{}');
  insert into r values (22, 'ban hi nahi => no_appealable_ban', res ->> 'error' = 'no_appealable_ban');

  -- ===== 6. appeal + evidence ek transaction mein =====
  select array_agg(id order by created_at) into ev from public.appeal_evidence where user_id = u and removed_at is null;
  res := public.device_appeal_open_v2(u, 'dev-u', big, ev);
  ap := (res ->> 'appeal_id')::uuid;
  insert into r values (23, '20,000 characters + 5 files => ok, evidence 5', (res ->> 'ok')::boolean and (res ->> 'evidence')::int = 5
    and (select char_length(statement) from public.device_ban_appeals where id = ap) = 20000
    and (select count(*) from public.appeal_evidence_links where appeal_id = ap) = 5);
  res := public.device_appeal_open_v2(u, 'dev-u', big, '{}');
  insert into r values (24, 'usi device par dusra open appeal => appeal_already_open', res ->> 'error' = 'appeal_already_open');
  res := public.appeal_evidence_remove(u, ev[1]);
  insert into r values (25, 'appeal mein lagi file wapas nahi li ja sakti => file_in_appeal', res ->> 'error' = 'file_in_appeal');
  res := public.appeal_evidence_register(u, repeat('f', 64), 10, 'late.pdf', 'application/pdf', 'appeals/' || u || '/ff/' || repeat('f', 64) || '-00000001');
  insert into r values (26, 'judi files ab "staged" ginti mein nahi — nayi upload ki jagah hai', (res ->> 'ok')::boolean);

  -- ===== 7. ghalat evidence => poora appeal wapas =====
  select id into id2 from public.appeal_evidence where user_id = x limit 1;
  res := public.device_appeal_open_v2(u, 'dev-u2', big, array[id2]);
  insert into r values (27, 'doosre user ki file id => evidence_invalid aur appeal BANA HI NAHI (adhoora nahi)', res ->> 'error' = 'evidence_invalid'
    and not exists (select 1 from public.device_ban_appeals where user_id = u and device_hash = 'dev-u2')
    and not exists (select 1 from public.device_trust_events where device_hash = 'dev-u2'));
  res := public.device_appeal_open_v2(u, 'dev-u2', big, array[gen_random_uuid()]);
  insert into r values (28, 'wajood hi nahi rakhne wali id => evidence_invalid', res ->> 'error' = 'evidence_invalid');
  res := public.device_appeal_open_v2(u, 'dev-u2', big, (select array_agg(gen_random_uuid()) from generate_series(1, 6)));
  insert into r values (29, '6 ids => too_many_files', res ->> 'error' = 'too_many_files' and not exists (select 1 from public.device_ban_appeals where device_hash = 'dev-u2'));
  res := public.device_appeal_open_v2(u, 'dev-u2', 'Mera ghalat ban hua hai, ye saboot hai.', '{}');
  insert into r values (30, 'bina evidence ke bhi appeal chalta hai (evidence zaroori nahi)', (res ->> 'ok')::boolean and (res ->> 'evidence')::int = 0);

  -- ===== 8. list / resolve / access log =====
  res := public.appeal_evidence_list(f, ap);
  insert into r values (31, 'reviewer: 5 files ki list', (res ->> 'ok')::boolean and jsonb_array_length(res -> 'files') = 5);
  res := public.appeal_evidence_list(u, ap);
  insert into r values (32, 'malik: apne appeal ki list', (res ->> 'ok')::boolean and jsonb_array_length(res -> 'files') = 5);
  res := public.appeal_evidence_list(s, ap);
  insert into r values (33, 'ajnabi => not_allowed', res ->> 'error' = 'not_allowed');
  res := public.appeal_evidence_resolve(f, ev[1]);
  insert into r values (34, 'reviewer judi file utaar sakta hai, path+naam milta hai', (res ->> 'ok')::boolean and res ->> 'rel_path' like 'appeals/%' and res ->> 'filename' is not null);
  insert into r values (35, 'reviewer ka download access log mein likha gaya', (select count(*) from public.appeal_evidence_access where evidence_id = ev[1] and actor = f and kind = 'download') = 1);
  res := public.appeal_evidence_resolve(u, ev[1]);
  insert into r values (36, 'malik apni file utare => ok, log mein NAHI (apni hi file)', (res ->> 'ok')::boolean and (select count(*) from public.appeal_evidence_access where actor = u) = 0);
  select id into id2 from public.appeal_evidence where user_id = u and sha256 = repeat('f', 64);
  res := public.appeal_evidence_resolve(f, id2);
  insert into r values (37, 'reviewer ko BINA JUDI (abhi staged) file nahi milti => not_found', res ->> 'error' = 'not_found');
  res := public.appeal_evidence_resolve(s, ev[1]);
  insert into r values (38, 'ajnabi => not_found (file ka wajood bhi nahi batate)', res ->> 'error' = 'not_found');
  res := public.appeal_evidence_resolve(null, ev[1]);
  insert into r values (39, 'bina user => unauthorized', res ->> 'error' = 'unauthorized');
  res := public.device_appeal_queue(f, null);
  insert into r values (40, 'queue: reviewer ko pura statement (20,000) + files ki ginti', (res ->> 'allowed')::boolean
    and exists (select 1 from jsonb_array_elements(res -> 'appeals') a where (a ->> 'id')::uuid = ap and (a ->> 'evidence')::int = 5 and char_length(a ->> 'statement') = 20000));
  res := public.device_appeal_queue(u, null);
  insert into r values (41, 'queue: reviewer nahi => allowed false, kuch nahi', not (res ->> 'allowed')::boolean and jsonb_array_length(res -> 'appeals') = 0);

  -- ===== 9. purane naam wale wrappers =====
  update public.device_ban_appeals set state = 'denied', decided_at = now() where device_hash = 'dev-u2';
  res := public.device_appeal_open(u, 'dev-u2', big || 'b');
  insert into r values (42, 'purana device_appeal_open(3 args) bhi ab 20,000 ki had maanta hai', res ->> 'error' = 'statement_too_long');
  res := public.account_integrity_appeal(x, 'short');
  insert into r values (43, 'purana account_integrity_appeal => statement_required (wohi behaviour)', res ->> 'error' = 'statement_required');
  select array_agg(id) into ev from public.appeal_evidence where user_id = x and removed_at is null;
  res := public.account_integrity_appeal_v2(x, 'Yeh block ghalat hai, mere paas saboot hai.', ev);
  insert into r values (44, 'account_integrity_appeal_v2: appeal + evidence jud gayi', (res ->> 'ok')::boolean and (select count(*) from public.appeal_evidence_links l join public.device_ban_appeals a on a.id = l.appeal_id where a.user_id = x) = 1);
  update public.device_ban_appeals set state = 'denied', decided_at = now() where user_id = x;
  update public.appeal_limits set value = 1 where key = 'max_appeals_per_day';
  res := public.device_appeal_open_v2(x, 'dev-x', 'Dusri baar appeal likh raha hoon, saboot ke saath.', '{}');
  insert into r values (45, 'roz ke appeals ki had => rate_limited', res ->> 'error' = 'rate_limited');
  update public.appeal_limits set value = 10 where key = 'max_appeals_per_day';

  -- ===== 10. safai =====
  -- (a) hataya hua 1 ghante se purana
  select id into id2 from public.appeal_evidence where user_id = u and sha256 = repeat('5', 64) and removed_at is null;
  update public.appeal_evidence set removed_at = now() - interval '2 hours' where user_id = u and removed_at is not null;
  insert into r values (46, 'purge_list: 1 ghante se purani hatai hui file aati hai', exists (select 1 from jsonb_array_elements(public.appeal_evidence_purge_list(100) -> 'files') a where (a ->> 'id')::uuid = (select id from public.appeal_evidence where user_id = u and removed_at is not null limit 1)));
  -- (b) appeal se na judi, TTL guzri
  update public.appeal_evidence set created_at = now() - interval '3 days' where user_id = g;
  insert into r values (47, 'purge_list: 48 ghante se purani, appeal se na judi file aati hai', (select count(*) from jsonb_array_elements(public.appeal_evidence_purge_list(100) -> 'files') a
    where (a ->> 'id')::uuid in (select id from public.appeal_evidence where user_id = g)) = 2);
  -- judi hui + appeal khula hai => KABHI nahi
  insert into r values (48, 'purge_list: khule appeal ki file kabhi nahi aati', not exists (select 1 from jsonb_array_elements(public.appeal_evidence_purge_list(2000) -> 'files') a
    where (a ->> 'id')::uuid in (select evidence_id from public.appeal_evidence_links where appeal_id = ap)));
  -- (c) faisla + 90 din
  update public.device_ban_appeals set state = 'denied', decided_at = now() - interval '89 days' where id = ap;
  insert into r values (49, 'faisle ko 89 din => abhi rakhi hui', not exists (select 1 from jsonb_array_elements(public.appeal_evidence_purge_list(2000) -> 'files') a
    where (a ->> 'id')::uuid in (select evidence_id from public.appeal_evidence_links where appeal_id = ap)));
  update public.device_ban_appeals set decided_at = now() - interval '91 days' where id = ap;
  insert into r values (50, 'faisle ko 91 din => safai ki list mein (5 files)', (select count(*) from jsonb_array_elements(public.appeal_evidence_purge_list(2000) -> 'files') a
    where (a ->> 'id')::uuid in (select evidence_id from public.appeal_evidence_links where appeal_id = ap)) = 5);
  -- (d) account mit gaya
  delete from auth.users where id = x;
  insert into r values (51, 'mite hue account ki file safai ki list mein', exists (select 1 from jsonb_array_elements(public.appeal_evidence_purge_list(2000) -> 'files') a
    where (a ->> 'id')::uuid in (select id from public.appeal_evidence where user_id = x)));
  -- done
  select count(*) into n from jsonb_array_elements(public.appeal_evidence_purge_list(2000) -> 'files');
  res := public.appeal_evidence_purge_done((select array_agg((a ->> 'id')::uuid) from jsonb_array_elements(public.appeal_evidence_purge_list(2000) -> 'files') a));
  insert into r values (52, 'purge_done: rows gayi (links bhi), ginti list jitni', (res ->> 'deleted')::int = n and n > 0
    and not exists (select 1 from public.appeal_evidence_links where appeal_id = ap)
    and (select count(*) from jsonb_array_elements(public.appeal_evidence_purge_list(2000) -> 'files')) = 0);
  insert into r values (53, 'access log purge ke baad bhi rehta hai ("kisne dekha" ka record)', (select count(*) from public.appeal_evidence_access where actor = f) = 1);
  insert into r values (54, 'purge_list limit: 1 maangne par 1 se zyada nahi', jsonb_array_length(public.appeal_evidence_purge_list(1) -> 'files') <= 1);

  -- ===== 11. table-level hadein =====
  insert into public.identity_signup_appeals (contact, statement) values ('a@b.co', big);
  insert into r values (55, 'logged-out sign-up appeal: 20,000 characters table mein ghus jata hai', exists (select 1 from public.identity_signup_appeals where char_length(statement) = 20000));
  begin insert into public.identity_signup_appeals (contact, statement) values ('a@b.co', big || 'b'); raised := false; exception when check_violation then raised := true; end;
  insert into r values (56, 'sign-up appeal 20,001 => DB rad karta hai', raised);
  begin insert into public.identity_signup_appeals (contact, statement) values ('a@b.co', 'short'); raised := false; exception when check_violation then raised := true; end;
  insert into r values (57, 'sign-up appeal 5 characters => DB rad karta hai (minimum 20 kayam)', raised);
  begin insert into public.device_ban_appeals (device_hash, user_id, statement) values ('dev-u', u, big || 'b'); raised := false; exception when check_violation then raised := true; end;
  insert into r values (58, 'device appeal table: seedha 20,001 => DB rad karta hai', raised);
  insert into r values (59, 'purani 2000 wali constraint ab nahi, nayi ek hi hai', (select count(*) from pg_constraint where conrelid = 'public.identity_signup_appeals'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%char_length(statement)%') = 1);

  -- ===== 12. suraksha =====
  insert into r values (60, '4 naye tables RLS ON, anon/authenticated ko koi haq nahi', (select count(*) from pg_class where relname in ('appeal_limits', 'appeal_evidence', 'appeal_evidence_links', 'appeal_evidence_access') and relrowsecurity) = 4
    and not has_table_privilege('anon', 'public.appeal_evidence', 'select') and not has_table_privilege('authenticated', 'public.appeal_evidence', 'insert')
    and not has_table_privilege('authenticated', 'public.appeal_evidence_access', 'select'));
  insert into r values (61, 'functions: authenticated/anon ka EXECUTE band, service_role ka khula', not has_function_privilege('authenticated', 'public.appeal_evidence_resolve(uuid,uuid)', 'execute')
    and not has_function_privilege('anon', 'public.device_appeal_open_v2(uuid,text,text,uuid[])', 'execute')
    and not has_function_privilege('authenticated', 'public.appeal_evidence_purge_done(uuid[])', 'execute')
    and has_function_privilege('service_role', 'public.appeal_evidence_register(uuid,text,bigint,text,text,text,jsonb)', 'execute'));
  insert into r values (62, 'har appeal_*/device_appeal_* function ka search_path pinned', not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and (p.proname like 'appeal\_%' or p.proname like 'device\_appeal%' or p.proname like '\_ap%' or p.proname = 'account_integrity_appeal_v2') and p.proconfig is null));
  insert into r values (63, 'E72 do baar chali: limits ke 9 rows (duplicate nahi), policies ek-ek', (select count(*) from public.appeal_limits) = 9
    and (select count(*) from pg_policy where polrelid = 'public.appeal_evidence'::regclass) = 1);
end $$;
select ord, item, ok from r order by ord;
select case when count(*) filter (where not ok) = 0 then 'ALL ' || count(*) || ' OK' else 'FAILED: ' || count(*) filter (where not ok) end as verdict from r;
rollback;

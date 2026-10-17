-- ANEXOMAIL — Phase 64: a REAL tamper-evident audit chain (Organisation → Audit ledger, Admin → Audit log).
-- Problem: server/routes/org.ts promised "append-only, hash-chained — verify it yourself", but no SQL file in this repo ever
-- created what it read, so every ledger() call was swallowed and the page showed "Nothing recorded yet" forever.
-- v2 (18 Oct 2026): the founder's database ALREADY has a table called org_audit_ledger with a different shape
-- (organisation_id NOT NULL …), so the first version of this file failed its self-test and rolled back (nothing was changed).
-- This version therefore creates its OWN objects under NEW names and never touches, alters or drops anything that exists:
--   table  public.org_audit_chain            (the old org_audit_ledger and its functions stay exactly as they are)
--   funcs  public.org_chain_append / org_chain_verify / org_chain_hash
-- One hash chain PER ORGANISATION (org_id null = platform/system actions), so a tenant can only ever see and verify its own entries.
-- Tamper-evident, not magic: UPDATE/DELETE/TRUNCATE are blocked by triggers and every entry carries the sha-256 of the one before
-- it, so an edited entry is detected by org_chain_verify(). (Someone with full database-owner rights could still rebuild the
-- whole chain — which is why the wording everywhere is "tamper-evident", never "nobody can rewrite".)
-- Safe: only the new objects. Polar / payment / mail tables are NOT touched. Idempotent.
-- Run:  bash sql/run.sh sql/phase64_org_audit_chain.sql   (or paste the whole file into the SQL editor)

begin;

-- 1. table
create table if not exists public.org_audit_chain (
  id          uuid primary key default gen_random_uuid(),
  org_id      uuid,
  seq         bigint not null,
  actor       text not null default '',
  action      text not null,
  target      text,
  ip          text,
  prev_hash   text,
  hash        text not null,
  created_at  timestamptz not null default clock_timestamp()
);

-- one chain per organisation; seq is per chain (#1, #2 … for each organisation)
create unique index if not exists org_audit_chain_chain_uniq
  on public.org_audit_chain ((coalesce(org_id, '00000000-0000-0000-0000-000000000000'::uuid)), seq);
create index if not exists org_audit_chain_org_seq_idx on public.org_audit_chain (org_id, seq desc);

-- 2. append-only: no UPDATE, no DELETE, no TRUNCATE — not for the service role, not for anyone
create or replace function public.org_audit_chain_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'org_audit_chain is append-only (% blocked)', tg_op using errcode = '42501';
end;
$$;

drop trigger if exists org_audit_chain_no_update on public.org_audit_chain;
create trigger org_audit_chain_no_update before update or delete on public.org_audit_chain
  for each row execute function public.org_audit_chain_immutable();
drop trigger if exists org_audit_chain_no_truncate on public.org_audit_chain;
create trigger org_audit_chain_no_truncate before truncate on public.org_audit_chain
  for each statement execute function public.org_audit_chain_immutable();

-- 3. nobody reads or writes the table directly from the browser — only the server (service role) through the functions
alter table public.org_audit_chain enable row level security;
revoke all on public.org_audit_chain from public, anon, authenticated;
grant select on public.org_audit_chain to service_role;
-- explicit policy so the server's read works whether or not the service role carries BYPASSRLS on this database
drop policy if exists org_audit_chain_service_read on public.org_audit_chain;
create policy org_audit_chain_service_read on public.org_audit_chain for select to service_role using (true);

-- 4. canonical hash of one entry (same text is rebuilt by the verifier)
create or replace function public.org_chain_hash(
  p_prev text, p_org uuid, p_seq bigint, p_actor text, p_action text, p_target text, p_ip text, p_at timestamptz
) returns text
language sql immutable as $$
  select encode(sha256(convert_to(
    coalesce(p_prev, 'genesis') || '|' || coalesce(p_org::text, '-') || '|' || p_seq::text || '|' ||
    coalesce(p_actor, '') || '|' || coalesce(p_action, '') || '|' || coalesce(p_target, '') || '|' ||
    coalesce(p_ip, '') || '|' || to_char(p_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US'),
    'UTF8')), 'hex');
$$;

-- 5. functions (new names: nothing older can collide, so there is nothing to drop)
create or replace function public.org_chain_append(
  p_actor text, p_action text, p_target text default null, p_ip text default null, p_org uuid default null
) returns bigint
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_seq bigint; v_prev text; v_at timestamptz := clock_timestamp();
begin
  if coalesce(trim(p_action), '') = '' then
    raise exception 'org_chain_append: action is required';
  end if;
  -- serialise appends per chain so seq / prev_hash can never fork
  perform pg_advisory_xact_lock(hashtextextended('org_audit_chain:' || coalesce(p_org::text, '-'), 0));
  select l.seq, l.hash into v_seq, v_prev
    from public.org_audit_chain l
   where l.org_id is not distinct from p_org
   order by l.seq desc limit 1;
  v_seq := coalesce(v_seq, 0) + 1;
  insert into public.org_audit_chain (org_id, seq, actor, action, target, ip, prev_hash, hash, created_at)
  values (p_org, v_seq, coalesce(p_actor, ''), p_action, p_target, p_ip, v_prev,
          public.org_chain_hash(v_prev, p_org, v_seq, coalesce(p_actor, ''), p_action, p_target, p_ip, v_at), v_at);
  return v_seq;
end;
$$;

create or replace function public.org_chain_verify(p_org uuid default null)
returns table (ok boolean, checked bigint, broken_at_seq bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  r record; v_prev text := null; v_n bigint := 0; v_expect bigint := 0;
begin
  for r in
    select * from public.org_audit_chain l where l.org_id is not distinct from p_org order by l.seq
  loop
    v_n := v_n + 1;
    v_expect := v_expect + 1;
    if r.seq <> v_expect
       or r.prev_hash is distinct from v_prev
       or r.hash <> public.org_chain_hash(v_prev, r.org_id, r.seq, r.actor, r.action, r.target, r.ip, r.created_at) then
      return query select false, v_n, r.seq;
      return;
    end if;
    v_prev := r.hash;
  end loop;
  return query select true, v_n, null::bigint;
end;
$$;

revoke all on function public.org_chain_append(text, text, text, text, uuid) from public, anon, authenticated;
revoke all on function public.org_chain_verify(uuid) from public, anon, authenticated;
grant execute on function public.org_chain_append(text, text, text, text, uuid) to service_role;
grant execute on function public.org_chain_verify(uuid) to service_role;

-- 6. self-test inside a sub-transaction (rolled back): append two, verify ok, edit must be refused
do $$
declare v_org uuid := gen_random_uuid(); v1 bigint; v2 bigint; v_ok boolean; v_n bigint; v_blocked boolean := false;
begin
  begin
    v1 := public.org_chain_append('phase64@selftest', 'selftest.one', null, null, v_org);
    v2 := public.org_chain_append('phase64@selftest', 'selftest.two', 'x', '203.0.113.9', v_org);
    select o.ok, o.checked into v_ok, v_n from public.org_chain_verify(v_org) o;
    if not (v1 = 1 and v2 = 2 and v_ok and v_n = 2) then
      raise exception 'phase64 FAILED: chain test v1=% v2=% ok=% n=%', v1, v2, v_ok, v_n;
    end if;
    begin
      update public.org_audit_chain set action = 'tampered' where org_id = v_org;
    exception when insufficient_privilege then
      v_blocked := true;
    end;
    if not v_blocked then
      raise exception 'phase64 FAILED: update was not blocked';
    end if;
    raise exception 'phase64_selftest_ok';
  exception when others then
    if sqlerrm <> 'phase64_selftest_ok' then
      raise exception '%', sqlerrm;
    end if;
  end;
end $$;

commit;

-- read-only proof (run after):
--   select count(*) from public.org_audit_chain;
--   select * from public.org_chain_verify(null);

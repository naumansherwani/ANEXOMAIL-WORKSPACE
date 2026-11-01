-- E121 — Founder G5a (SQL half): RFC 9162 section 2.1.4 CONSISTENCY proofs over the E107 audit tree (founder 2 Nov 2026 03:37, "God level").
-- "The ledger of `second` entries extends the ledger of `first` entries without changing any of the first ones." The browser kernel (merkle@2, next step) checks
-- the proof; this file only GENERATES it from the real ledger. Three independent implementations must agree: this SQL, server/rust/merkle_core.rs,
-- docs/cursor-work/server/g5a-reference.py (Python, written from the RFC). The selftest here carries literal vectors from the Python reference.
-- Technology: SQL (Supabase Postgres, RLS on, read-only doors). Safe to run again. The selftest rolls back everything it writes.

do $$
begin
  if to_regprocedure('public._fm_mth(bytea[],integer,integer)') is null or to_regprocedure('public._fm_leaves(bigint)') is null then
    raise exception 'E121 needs E107 first (sql-run.sh E107_founder_audit_merkle)';
  end if;
  if to_regprocedure('public._fs_fails(text)') is null then raise exception 'E121 needs E113 first (helper _fs_fails)'; end if;
end $$;

-- SUBPROOF(m, D[lo..hi], b) exactly as RFC 9162 2.1.4.1 (1-based inclusive range, as _fm_mth). Output order = the recursion's append order.
create or replace function public._fm_subproof(p_leaves bytea[], p_m integer, p_lo integer, p_hi integer, p_b boolean) returns bytea[]
language plpgsql immutable set search_path = pg_catalog, public, extensions as $$
declare n integer := p_hi - p_lo + 1; k integer := 1;
begin
  if p_m < 1 or p_m > n then raise exception 'E121: m 1..% hona chahiye', n using errcode = '22023'; end if;
  if p_m = n then
    if p_b then return array[]::bytea[]; end if;
    return array[public._fm_mth(p_leaves, p_lo, p_hi)];
  end if;
  while k * 2 < n loop k := k * 2; end loop;
  if p_m <= k then
    return public._fm_subproof(p_leaves, p_m, p_lo, p_lo + k - 1, p_b) || array[public._fm_mth(p_leaves, p_lo + k, p_hi)];
  end if;
  return public._fm_subproof(p_leaves, p_m - k, p_lo + k, p_hi, false) || array[public._fm_mth(p_leaves, p_lo, p_lo + k - 1)];
end $$;
revoke all on function public._fm_subproof(bytea[], integer, integer, integer, boolean) from public, anon, authenticated;

-- proof over any leaf array (the real ledger and the test vectors use the same code)
create or replace function public._fm_consistency_from_leaves(p_leaves bytea[], p_first integer, p_second integer) returns jsonb
language plpgsql immutable set search_path = pg_catalog, public, extensions as $$
declare v_len integer := coalesce(array_length(p_leaves, 1), 0); v_proof bytea[];
begin
  if p_first is null or p_second is null or p_first < 1 or p_first > p_second or p_second > v_len then
    raise exception 'E121: 1 <= first <= second <= % hona chahiye', v_len using errcode = '22023';
  end if;
  v_proof := public._fm_subproof(p_leaves[1:p_second], p_first, 1, p_second, true);
  return jsonb_build_object('first', p_first, 'second', p_second,
    'first_root', encode(public._fm_mth(p_leaves, 1, p_first), 'hex'), 'second_root', encode(public._fm_mth(p_leaves, 1, p_second), 'hex'),
    'proof', coalesce((select jsonb_agg(encode(x, 'hex') order by o) from unnest(v_proof) with ordinality as t(x, o)), '[]'::jsonb));
end $$;
revoke all on function public._fm_consistency_from_leaves(bytea[], integer, integer) from public, anon, authenticated;

-- RFC 9162 2.1.4.2 verifier (the SQL witness of the same algorithm Rust and the kernel run). Pure: no table is read.
create or replace function public._fm_consistency_check(p_first bigint, p_second bigint, p_first_root text, p_second_root text, p_proof jsonb) returns boolean
language plpgsql immutable set search_path = pg_catalog, public, extensions as $$
declare p bytea[] := array[]::bytea[]; x jsonb; fr bytea; sr bytea; fnn bigint; sn bigint; c bytea; i integer; v_fr bytea; v_sr bytea;
begin
  if p_first is null or p_second is null or p_first_root is null or p_second_root is null or p_proof is null then return false; end if;   -- NULL is never an answer
  if p_first < 1 or p_first > p_second then return false; end if;
  if p_first_root !~ '^[0-9a-f]{64}$' or p_second_root !~ '^[0-9a-f]{64}$' then return false; end if;
  if jsonb_typeof(p_proof) <> 'array' or jsonb_array_length(p_proof) > 65 then return false; end if;
  fr := decode(p_first_root, 'hex'); sr := decode(p_second_root, 'hex');
  for x in select value from jsonb_array_elements(p_proof) loop
    if jsonb_typeof(x) <> 'string' or (x #>> '{}') !~ '^[0-9a-f]{64}$' then return false; end if;
    p := p || decode(x #>> '{}', 'hex');
  end loop;
  if p_first = p_second then return coalesce(array_length(p, 1), 0) = 0 and fr = sr; end if;
  if coalesce(array_length(p, 1), 0) = 0 then return false; end if;
  if (p_first & (p_first - 1)) = 0 then p := array[fr] || p; end if;      -- first is a power of two: the old tree is a complete subtree
  fnn := p_first - 1; sn := p_second - 1;
  while (fnn & 1) = 1 loop fnn := fnn >> 1; sn := sn >> 1; end loop;
  v_fr := p[1]; v_sr := p[1];
  for i in 2 .. array_length(p, 1) loop
    c := p[i];
    if sn = 0 then return false; end if;
    if (fnn & 1) = 1 or fnn = sn then
      v_fr := public._fm_node(c, v_fr); v_sr := public._fm_node(c, v_sr);
      if (fnn & 1) = 0 then while (fnn & 1) = 0 and fnn <> 0 loop fnn := fnn >> 1; sn := sn >> 1; end loop; end if;
    else
      v_sr := public._fm_node(v_sr, c);
    end if;
    fnn := fnn >> 1; sn := sn >> 1;
  end loop;
  return v_fr = fr and v_sr = sr and sn = 0;
end $$;
revoke all on function public._fm_consistency_check(bigint, bigint, text, text, jsonb) from public, anon, authenticated;

-- test vectors: the same rows the E107 vectors and the Rust/Python references use (row hash g = sha256('founder-merkle-vector-' || g))
create or replace function public._fm_g5a_vector(p_first integer, p_second integer) returns jsonb
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select public._fm_consistency_from_leaves(
    (select array_agg(public._fm_leaf(encode(sha256(convert_to('founder-merkle-vector-' || g, 'UTF8')), 'hex')) order by g) from generate_series(1, greatest(p_second, 1)) g), p_first, p_second)
$$;
revoke all on function public._fm_g5a_vector(integer, integer) from public, anon, authenticated;

-- THE DOOR: consistency proof from the real ledger. Read-only. Also says which signed seals (E107 checkpoints) sit at exactly those sizes: the SIZES are bound
-- by the seals, not by the roots (a Merkle root does not commit to its own size).
create or replace function public.founder_audit_consistency_proof(p_first bigint, p_second bigint) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare v_head bigint; v_max integer; v_out jsonb; v_a jsonb; v_b jsonb;
begin
  select coalesce(max(seq), 0) into v_head from public.founder_audit;
  select max_leaves into v_max from public.founder_audit_merkle_policy where id;
  if v_head = 0 then raise exception 'E121: audit chain mein koi row nahi' using errcode = '22023'; end if;
  if p_first is null or p_second is null or p_first < 1 or p_first > p_second or p_second > v_head then
    raise exception 'E121: 1 <= first <= second <= head (%) hona chahiye', v_head using errcode = '22023'; end if;
  if p_second > v_max then raise exception 'E121: second % policy ke max_leaves % se bara', p_second, v_max using errcode = '22023'; end if;
  v_out := public._fm_consistency_from_leaves(public._fm_leaves(p_second), p_first::integer, p_second::integer);
  select jsonb_build_object('id', id, 'cp_hash', cp_hash, 'root', root) into v_a from public.founder_audit_checkpoints where upto_seq = p_first order by id desc limit 1;
  select jsonb_build_object('id', id, 'cp_hash', cp_hash, 'root', root) into v_b from public.founder_audit_checkpoints where upto_seq = p_second order by id desc limit 1;
  -- the seal's stored root is NOT compared here: the caller (the browser, from the signed seal) compares it to first_root; the selftest checks they agree
  return v_out || jsonb_build_object('head', v_head, 'first_seal', v_a, 'second_seal', v_b,
                                     'rule', 'RFC 9162 2.1.4; leaf=sha256(00||row_hash) node=sha256(01||left||right)');
end $$;
revoke all on function public.founder_audit_consistency_proof(bigint, bigint) from public, anon, authenticated;
grant execute on function public.founder_audit_consistency_proof(bigint, bigint) to service_role;

-- SELFTEST (rolls back): literal vectors from the Python reference, every pair for 1..40 leaves verified by the SQL verifier, negatives, then the REAL ledger.
create or replace function public.founder_audit_consistency_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare r text := ''; v jsonb; v_uid uuid; b_aud bigint; b_cp bigint; m integer; n integer; i integer; j jsonb; bad jsonb; cnt integer := 0; v_head bigint; real jsonb;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then raise exception 'E121 selftest needs one founder account'; end if;
  select count(*) into b_aud from public.founder_audit; select count(*) into b_cp from public.founder_audit_checkpoints;
  begin
    -- 1) literal vectors written by docs/cursor-work/server/g5a-reference.py (an independent implementation, Python)
    v := public._fm_g5a_vector(3, 7);
    if v ->> 'first_root' <> 'affb9317bdc52d5109a09da7a9e5ae9503f6b95b5476b5ea2de70b050e7b09b9' or v ->> 'second_root' <> 'de5464e0406c1157d9b964a79975e75723285ba73ad8679366179f1aa607c1c4' or v -> 'proof' <> '["a4b9bd6a4376225072ad781f2073d7a7d5bb2c55f7c492edda0aac5a7fcef7ce", "0fb45a9030c90c4d74139a44b1739613f277b88028dc9cc1eb2af2f6b610f3c3", "619933a6cda3bcd1faba11b3fb9ec2d8bd13d4ec4d9c8787d3c830cea5220476", "743a3fc036b9569e8f68d1dcf834fdbe6bd3fada46d07641df30cafa80f27065"]'::jsonb then raise exception 'vector (3,7) differs from the Python reference: %', v; end if;
    v := public._fm_g5a_vector(6, 7);
    if v ->> 'first_root' <> '2fd96038f719600ebbac1068f6748310b47a0cadb7c87fa51e308f36856e8f90' or v -> 'proof' <> '["81b5936b8934b3e356e873b8364a5712fbd56d2bdcc57859532a87354b8cdd1d", "bd58d3efcebb04c9ee29acccca7652100104b2e196ba758fffaee3de40b505d4", "b0c9b4dbdc617bb2c4a37c4d2658abf14b6b564a44565ae550544a4f53d58072"]'::jsonb then raise exception 'vector (6,7) differs from the Python reference: %', v; end if;
    v := public._fm_g5a_vector(1, 8);
    if v -> 'proof' <> '["781a5b1e623bbd1b0c8dea05f1629d72b12228118bacc97c7e24ac35e54d65d2", "0d2bb1bfa9e59da48cbad77be9584a197002628f9175b315ddf3044c39ffd052", "82809cb116287fa3a6ac54bcfd167bbc0b03e5fa6896ca51bb2f37ccea529729"]'::jsonb then raise exception 'vector (1,8) differs from the Python reference: %', v; end if;
    r := r || 'python vectors OK; ';
    -- 2) every pair 1..40: generated proof verifies, a flipped hash is refused, wrong sizes are refused
    for n in 1 .. 40 loop
      for m in 1 .. n loop
        v := public._fm_g5a_vector(m, n); cnt := cnt + 1;
        if not public._fm_consistency_check(m, n, v ->> 'first_root', v ->> 'second_root', v -> 'proof') then raise exception 'pair (%,%) did not verify', m, n; end if;
        if m < n then
          bad := jsonb_set(v -> 'proof', '{0}', to_jsonb(translate(substr(v -> 'proof' ->> 0, 1, 1), '0123456789abcdef', '123456789abcdef0') || substr(v -> 'proof' ->> 0, 2)));
          if public._fm_consistency_check(m, n, v ->> 'first_root', v ->> 'second_root', bad) then raise exception 'pair (%,%) accepted a changed proof hash', m, n; end if;
          if public._fm_consistency_check(m, n, v ->> 'second_root', v ->> 'first_root', v -> 'proof') then raise exception 'pair (%,%) accepted swapped roots', m, n; end if;
          if public._fm_consistency_check(m, n, v ->> 'first_root', v ->> 'second_root', '[]'::jsonb) then raise exception 'pair (%,%) accepted an empty proof', m, n; end if;
          if public._fm_consistency_check(m, n, v ->> 'first_root', v ->> 'second_root', (v -> 'proof') || to_jsonb(repeat('0', 64))) then raise exception 'pair (%,%) accepted an extended proof', m, n; end if;
        end if;
      end loop;
    end loop;
    r := r || cnt || ' pairs verified, tampering refused; ';
    -- 3) input validation
    if not public._fs_fails($q$select public._fm_g5a_vector(0, 5)$q$) then raise exception 'first=0 accepted'; end if;
    if not public._fs_fails($q$select public._fm_g5a_vector(6, 5)$q$) then raise exception 'first>second accepted'; end if;
    if public._fm_consistency_check(1, 2, 'XYZ', repeat('a', 64), '[]'::jsonb) or public._fm_consistency_check(1, 2, repeat('a', 64), repeat('a', 64), '"x"'::jsonb)
       or public._fm_consistency_check(1, 2, repeat('a', 64), repeat('a', 64), jsonb_build_array(5)) or public._fm_consistency_check(1, 2, repeat('A', 64), repeat('a', 64), '[]'::jsonb) then
      raise exception 'malformed input accepted'; end if;
    if public._fm_consistency_check(3, 3, repeat('a', 64), repeat('a', 64), null) is not false or public._fm_consistency_check(1, 2, null, repeat('a', 64), '[]'::jsonb) is not false
       or public._fm_consistency_check(1, 2, repeat('a', 64), null, '[]'::jsonb) is not false or public._fm_consistency_check(null, 2, repeat('a', 64), repeat('a', 64), '[]'::jsonb) is not false then
      raise exception 'NULL input did not give false'; end if;
    if public._fm_consistency_check(2, 9, repeat('a', 64), repeat('b', 64), (select jsonb_agg(repeat('1', 64)) from generate_series(1, 66))) then raise exception '66 hashes accepted'; end if;
    if public._fm_consistency_check(2, 9, repeat('a', 64), repeat('b', 64), jsonb_build_array(repeat('1', 64), null)) then raise exception 'a NULL proof element accepted'; end if;
    if public._fm_consistency_check(4611686018427387904, 9223372036854775807, repeat('a', 64), repeat('b', 64), jsonb_build_array(repeat('1', 64), repeat('2', 64))) then raise exception 'huge sizes accepted'; end if;
    r := r || 'validation OK; ';
    -- 4) the REAL ledger door: grow it, seal in the middle, prove old -> new, SQL verifier accepts, roots equal the E107 roots, seals are named
    for i in 1 .. 6 loop perform public.founder_audit_append(v_uid, 'g5a.selftest', 'row-' || i, 'selftest entry number ' || i, '{}'::jsonb); end loop;
    perform public.founder_audit_checkpoint(v_uid, 'selftest seal for the consistency check');
    select max(seq) into v_head from public.founder_audit;
    for i in 1 .. 4 loop perform public.founder_audit_append(v_uid, 'g5a.selftest', 'later-' || i, 'selftest later entry ' || i, '{}'::jsonb); end loop;
    select max(seq) into v_head from public.founder_audit;
    select upto_seq into m from public.founder_audit_checkpoints order by id desc limit 1;
    real := public.founder_audit_consistency_proof(m, v_head);
    if not public._fm_consistency_check(m, v_head, real ->> 'first_root', real ->> 'second_root', real -> 'proof') then raise exception 'real ledger proof did not verify: %', real; end if;
    if real ->> 'first_root' <> (public.founder_audit_merkle_root(m) ->> 'root') or real ->> 'second_root' <> (public.founder_audit_merkle_root(v_head) ->> 'root') then
      raise exception 'proof roots differ from the E107 roots: %', real; end if;
    if real -> 'first_seal' ->> 'root' <> real ->> 'first_root' then raise exception 'the seal at the old size does not carry the old root: %', real; end if;
    if real -> 'second_seal' <> 'null'::jsonb then raise exception 'there is no seal at the new size yet: %', real; end if;
    if not public._fs_fails(format('select public.founder_audit_consistency_proof(%s, %s)', v_head + 1, v_head + 2)) then raise exception 'sizes beyond the ledger accepted'; end if;
    if not public._fs_fails('select public.founder_audit_consistency_proof(5, 2)') then raise exception 'first>second accepted by the door'; end if;
    r := r || 'real ledger OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E121 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_audit) <> b_aud or (select count(*) from public.founder_audit_checkpoints) <> b_cp then raise exception 'E121 selftest left rows behind'; end if;
  return 'E121 selftest OK — ' || r || 'rollback clean';
end $$;
revoke all on function public.founder_audit_consistency_selftest() from public, anon, authenticated;
grant execute on function public.founder_audit_consistency_selftest() to service_role;

-- E107 — FOUNDER AUDIT MERKLE (master order step 5, F2c): audit chain ke upar Merkle tree, signed-ready checkpoints, inclusion proof, export.
-- ---------------------------------------------------------------------------------------------------------------------------
-- Technology: Postgres 15+ (Supabase), pgcrypto SHA-256 (schema extensions), security definer RPC (service_role only, search_path + statement_timeout pinned),
--             RLS on, append-only hash-chained checkpoints, E102 audit chain, E109 live source. Idempotent (dobara chalana safe).
-- Design:     docs/claude/FOUNDER-F2C-MERKLE-DESIGN-01NOV.md   Order: docs/claude/FOUNDER-MASTER-ORDER-28OCT.md step 5.
-- Founder orders: 1 Nov 08:11 "sab tarteeb se wire" · 08:22 "E107 SQL folder mein tarteeb se nazar aaye, kitni baar chalega, edit to nahi hota" · "SQL kam se kam 800 lines".
--
-- E107 KITNI BAAR CHALTA HAI / KYA EDIT HOTA HAI (founder ka sawal)
--   * sql-run.sh har file ka sha256 ledger (/var/lib/anexomail/sql-applied.tsv) mein likhta hai. Wahi file wahi sha = DOBARA NAHI chalti (FORCE=1 se chalegi).
--   * Yeh file idempotent hai (create ... if not exists / create or replace / on conflict do nothing): do baar chal jaye to kuch nahi bigadta, koi row duplicate nahi.
--   * Jo E107 server par chal chuki, uska matlab badalna ho to us file ko dobara edit nahi karte: nayi E-file (E113+) banti hai. Sirf typo/comment fix par sha badal
--     jata hai aur sql-run.sh use dobara chala deta hai, jo idempotent hone ki wajah se safe hai.
--   * E107 ka number E106 aur E108 ke beech hai: E108 pehle se server par hai. Auto mode "jo ledger mein nahi" chalata hai, isliye E107 ab bhi chalegi
--     (number ki tarteeb file ke mutabiq hai, dependency sirf E102 aur E109 par hai, E108 par nahi).
--
-- TREE KA QAIDA (RFC 6962 jaisa, kernel mein bhi bilkul yehi)
--   leaf = sha256( 0x00 || bytes(audit_row_hash) )          node = sha256( 0x01 || left || right )
--   Neeche se upar: har level par jodi banao; aakhri akela node jaisa hai waisa agle level par chala jata hai (duplicate nahi hota: second-preimage ka darwaza band).
--   Leaf ki tarteeb = seq 1..N. Isliye chain ka seq beech se gaya hua nahi hona chahiye (founder_audit_verify pehle saaf hona chahiye); yeh file khud bhi ginti check karti hai.
--
-- SECTIONS
--   0) Preflight                    1) policy table (kitni rows par checkpoint)       2) founder_audit_checkpoints (append-only chain)
--   3) hash helpers                 4) tree: leaves / root / levels                   5) root + proof RPC
--   6) proof check (SQL parity)     7) checkpoint make / verify / list / due           8) export
--   9) stats (Dashboard gauge)     10) live source                                   11) grants
--  12) selftest (poora rollback)    + CHECK_E107.sql

set lock_timeout = '10s';
set statement_timeout = '60s';
set search_path = pg_catalog, public, extensions;

-- ==============================================================================================================================
-- 0) PREFLIGHT — E102 (audit chain) aur E109 (live sources) pehle honi chahiye. Aadhi table kabhi nahi banti.
-- ==============================================================================================================================
do $$
begin
  if to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is null then raise exception 'E107: pehle E102 chalayein (founder_audit_append nahi)'; end if;
  if to_regprocedure('public.founder_audit_verify(bigint)') is null then raise exception 'E107: pehle E102 chalayein (founder_audit_verify nahi)'; end if;
  if to_regprocedure('public._fa_lp(text)') is null then raise exception 'E107: pehle E102 chalayein (_fa_lp nahi)'; end if;
  if to_regclass('public.founder_audit') is null then raise exception 'E107: founder_audit table nahi (E102)'; end if;
  if to_regclass('public.founder_live_sources') is null then raise exception 'E107: pehle E109 chalayein (founder_live_sources nahi)'; end if;
  if to_regclass('public.founder_accounts') is null then raise exception 'E107: founder_accounts nahi (E100)'; end if;
  if to_regprocedure('extensions.digest(bytea,text)') is null and to_regprocedure('public.digest(bytea,text)') is null then raise exception 'E107: pgcrypto digest nahi'; end if;
end $$;

-- ==============================================================================================================================
-- 1) POLICY — kitni nayi audit rows ke baad naya checkpoint "due" hota hai. Ek hi row, badalna = audited RPC.
-- ==============================================================================================================================
do $$
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_merkle:ddl', 0));

  create table if not exists public.founder_audit_merkle_policy (
    id            boolean primary key default true check (id),                           -- sirf ek row
    every_rows    integer not null default 50 check (every_rows between 5 and 100000),    -- itni nayi rows ke baad checkpoint due
    warn_lag_rows integer not null default 200 check (warn_lag_rows between 10 and 1000000), -- itni rows bina checkpoint = warn
    fail_lag_rows integer not null default 2000 check (fail_lag_rows between 20 and 10000000), -- itni rows bina checkpoint = fail
    max_leaves    integer not null default 200000 check (max_leaves between 1000 and 5000000), -- tree ka upar ka had (memory/time ki hifazat)
    updated_ms    bigint not null default (extract(epoch from clock_timestamp()) * 1000)::bigint,
    constraint founder_audit_merkle_policy_order check (warn_lag_rows >= every_rows and fail_lag_rows > warn_lag_rows)
  );
  alter table public.founder_audit_merkle_policy enable row level security;
  revoke all on public.founder_audit_merkle_policy from public, anon, authenticated;
  grant select on public.founder_audit_merkle_policy to service_role;
  insert into public.founder_audit_merkle_policy (id) values (true) on conflict (id) do nothing;
end $$;

-- ==============================================================================================================================
-- 2) CHECKPOINTS — har checkpoint = "seq 1..upto_seq ka Merkle root yeh hai". Khud ek hash-chain: pichhla checkpoint hash shamil.
--    Append-only (update/delete/truncate band), service_role ko sirf select+insert.
-- ==============================================================================================================================
do $$
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_merkle:ddl', 0));

  create table if not exists public.founder_audit_checkpoints (
    id            bigint primary key check (id >= 1),
    upto_seq      bigint not null unique check (upto_seq >= 1),            -- tree ke leaves: seq 1..upto_seq
    leaves        bigint not null check (leaves >= 1),                     -- hamesha upto_seq ke barabar (chain beech se kata nahi)
    root          text   not null check (root ~ '^[0-9a-f]{64}$'),
    head_hash     text   not null check (head_hash ~ '^[0-9a-f]{64}$'),    -- audit row upto_seq ka hash: root ko chain ke sir se bandhta hai
    prev_cp_hash  text   not null check (prev_cp_hash ~ '^[0-9a-f]{64}$'),
    cp_hash       text   not null unique check (cp_hash ~ '^[0-9a-f]{64}$'),
    created_ms    bigint not null check (created_ms > 0),
    actor         uuid   not null,
    reason        text   not null check (length(reason) between 8 and 300),
    constraint founder_audit_checkpoints_leaves_eq check (leaves = upto_seq)
  );
  create index if not exists founder_audit_checkpoints_created_idx on public.founder_audit_checkpoints (created_ms desc);

  alter table public.founder_audit_checkpoints enable row level security;
  revoke all on public.founder_audit_checkpoints from public, anon, authenticated;
  grant select, insert on public.founder_audit_checkpoints to service_role;
  -- Supabase default privileges service_role ko sab dete hain: UPDATE/DELETE/TRUNCATE saaf hata do (trigger ke upar doosri deewar)
  revoke update, delete, truncate, references, trigger on public.founder_audit_checkpoints from service_role;
end $$;

create or replace function public._fm_immutable() returns trigger language plpgsql as $$
begin
  raise exception 'founder_audit_checkpoints append-only hai (% band)', tg_op using errcode = '42501';
end $$;
drop trigger if exists founder_audit_checkpoints_no_upd on public.founder_audit_checkpoints;
create trigger founder_audit_checkpoints_no_upd before update or delete on public.founder_audit_checkpoints for each row execute function public._fm_immutable();
drop trigger if exists founder_audit_checkpoints_no_trunc on public.founder_audit_checkpoints;
create trigger founder_audit_checkpoints_no_trunc before truncate on public.founder_audit_checkpoints for each statement execute function public._fm_immutable();

-- ==============================================================================================================================
-- 3) HASH HELPERS — leaf/node ke prefix alag (0x00 / 0x01) taake leaf ko node samajhne ki galti na ho (RFC 6962).
-- ==============================================================================================================================
create or replace function public._fm_leaf(p_hash text) returns bytea
language sql immutable strict set search_path = pg_catalog, public, extensions as $$
  select extensions.digest('\x00'::bytea || decode(p_hash, 'hex'), 'sha256')
$$;

create or replace function public._fm_node(p_left bytea, p_right bytea) returns bytea
language sql immutable strict set search_path = pg_catalog, public, extensions as $$
  select extensions.digest('\x01'::bytea || p_left || p_right, 'sha256')
$$;

-- Checkpoint ka apna hash: har maidan length-prefixed (E102 ka _fa_lp), isliye maidan ki sarhad par dhoka nahi.
create or replace function public._fm_cp_hash(p_prev text, p_id bigint, p_upto bigint, p_leaves bigint, p_root text, p_head text, p_ms bigint, p_actor uuid)
returns text language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(
    public._fa_lp(p_prev) || public._fa_lp(p_id::text) || public._fa_lp(p_upto::text) || public._fa_lp(p_leaves::text)
    || public._fa_lp(p_root) || public._fa_lp(p_head) || public._fa_lp(p_ms::text) || public._fa_lp(p_actor::text), 'sha256'), 'hex')
$$;

create or replace function public._fm_hexes(p_arr bytea[]) returns text[]
language sql immutable set search_path = pg_catalog, public as $$
  select coalesce(array_agg(encode(x, 'hex') order by o), '{}'::text[]) from unnest(p_arr) with ordinality as t(x, o)
$$;

-- ==============================================================================================================================
-- 4) TREE — leaves (seq 1..N), ek level ka agla level, poora root, poore levels (proof ke liye).
-- ==============================================================================================================================
-- Ek level se agla level: jodi (1,2),(3,4)...; aakhri akela node waisa hi upar. Set-based: array mein baar baar jodna nahi (O(n^2) nahi).
create or replace function public._fm_next_level(p_cur bytea[]) returns bytea[]
language plpgsql immutable set search_path = pg_catalog, public, extensions as $$
declare n integer := cardinality(p_cur);
begin
  if n <= 1 then return p_cur; end if;
  return (select array_agg(case when i + 1 <= n then public._fm_node(p_cur[i], p_cur[i + 1]) else p_cur[i] end order by i)
            from generate_series(1, n, 2) as i);
end $$;

create or replace function public._fm_root_of(p_leaves bytea[]) returns bytea
language plpgsql immutable set search_path = pg_catalog, public, extensions as $$
declare cur bytea[] := p_leaves;
begin
  if cardinality(cur) = 0 then raise exception 'E107: leaves khali nahi ho sakte' using errcode = '22023'; end if;
  while cardinality(cur) > 1 loop cur := public._fm_next_level(cur); end loop;
  return cur[1];
end $$;

-- Saare levels hex mein: [[leaf...],[level1...],...,[root]] — ek baar bana kar har seq ka proof sasta nikalta hai.
create or replace function public._fm_levels(p_leaves bytea[]) returns jsonb
language plpgsql immutable set search_path = pg_catalog, public, extensions as $$
declare cur bytea[] := p_leaves; out jsonb;
begin
  if cardinality(cur) = 0 then raise exception 'E107: leaves khali nahi ho sakte' using errcode = '22023'; end if;
  out := jsonb_build_array(to_jsonb(public._fm_hexes(cur)));
  while cardinality(cur) > 1 loop
    cur := public._fm_next_level(cur);
    out := out || jsonb_build_array(to_jsonb(public._fm_hexes(cur)));
  end loop;
  return out;
end $$;

-- Proof path ek leaf index ke liye levels se: har level par bhai-node (agar hai) aur uski taraf ('L' = bhai baayen, 'R' = bhai daayen).
create or replace function public._fm_path_from_levels(p_levels jsonb, p_index integer) returns jsonb
language plpgsql immutable set search_path = pg_catalog, public as $$
declare lv integer; idx integer := p_index; len integer; sib integer; out jsonb := '[]'::jsonb; nlev integer := jsonb_array_length(p_levels);
begin
  for lv in 0 .. nlev - 2 loop
    len := jsonb_array_length(p_levels -> lv);
    sib := idx # 1;                                   -- XOR 1: bhai ka index
    if sib < len then
      out := out || jsonb_build_array(jsonb_build_object('s', case when idx % 2 = 0 then 'R' else 'L' end, 'h', p_levels -> lv ->> sib));
    end if;                                           -- bhai nahi = akela node, upar waisa hi chala jata hai
    idx := idx / 2;
  end loop;
  return out;
end $$;

-- audit rows ke hash (seq 1..upto) bytea[] leaves mein. Ginti check: seq beech se nahi gaya, upar ka had.
create or replace function public._fm_leaves(p_upto bigint) returns bytea[]
language plpgsql stable set search_path = pg_catalog, public, extensions as $$
declare v_max integer; v_cnt bigint; v_leaves bytea[];
begin
  select max_leaves into v_max from public.founder_audit_merkle_policy where id;
  if p_upto > coalesce(v_max, 200000) then raise exception 'E107: chain % rows se lambi hai (had %)', p_upto, v_max using errcode = '54000'; end if;
  select count(*) into v_cnt from public.founder_audit where seq <= p_upto;
  if v_cnt <> p_upto then raise exception 'E107: seq 1..% mein % rows hain (beech se kata hua chain)', p_upto, v_cnt using errcode = 'XX001'; end if;
  select array_agg(public._fm_leaf(hash) order by seq) into v_leaves from public.founder_audit where seq <= p_upto;
  return v_leaves;
end $$;

-- ==============================================================================================================================
-- 5) ROOT + PROOF RPC
-- ==============================================================================================================================
create or replace function public.founder_audit_merkle_root(p_upto bigint default null) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare v_head bigint; v_upto bigint; v_hh text;
begin
  select coalesce(max(seq), 0) into v_head from public.founder_audit;
  if v_head = 0 then return jsonb_build_object('upto', 0, 'leaves', 0, 'root', null, 'head_hash', null); end if;
  v_upto := coalesce(p_upto, v_head);
  if v_upto < 1 or v_upto > v_head then raise exception 'E107: upto 1..% ke beech hona chahiye', v_head using errcode = '22023'; end if;
  select hash into v_hh from public.founder_audit where seq = v_upto;
  return jsonb_build_object('upto', v_upto, 'leaves', v_upto, 'head_hash', v_hh,
                            'root', encode(public._fm_root_of(public._fm_leaves(v_upto)), 'hex'));
end $$;

create or replace function public.founder_audit_merkle_proof(p_seq bigint, p_upto bigint default null) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare v_head bigint; v_upto bigint; v_levels jsonb; v_leaf text; v_hash text;
begin
  select coalesce(max(seq), 0) into v_head from public.founder_audit;
  if v_head = 0 then raise exception 'E107: audit chain mein koi row nahi' using errcode = '22023'; end if;
  v_upto := coalesce(p_upto, v_head);
  if v_upto < 1 or v_upto > v_head then raise exception 'E107: upto 1..% ke beech hona chahiye', v_head using errcode = '22023'; end if;
  if p_seq is null or p_seq < 1 or p_seq > v_upto then raise exception 'E107: seq 1..% ke beech hona chahiye', v_upto using errcode = '22023'; end if;
  select hash into v_hash from public.founder_audit where seq = p_seq;
  v_levels := public._fm_levels(public._fm_leaves(v_upto));
  v_leaf := v_levels -> 0 ->> (p_seq - 1)::int;
  return jsonb_build_object('seq', p_seq, 'upto', v_upto, 'row_hash', v_hash, 'leaf', v_leaf,
                            'path', public._fm_path_from_levels(v_levels, (p_seq - 1)::int),
                            'root', v_levels -> (jsonb_array_length(v_levels) - 1) ->> 0);
end $$;

-- ==============================================================================================================================
-- 6) PROOF CHECK — SQL mein wohi hisab jo Rust aur WASM kernel karte hain (teeno ek hi test-vector se milte hain).
--    Neeche se upar: s='R' => bhai daayen (node || bhai), s='L' => bhai baayen (bhai || node).
-- ==============================================================================================================================
create or replace function public.founder_audit_proof_check(p_row_hash text, p_path jsonb, p_root text) returns boolean
language plpgsql immutable set search_path = pg_catalog, public, extensions as $$
declare node bytea; el jsonb; sib bytea;
begin
  if p_row_hash is null or p_root is null or p_path is null then return false; end if;
  if p_row_hash !~ '^[0-9a-f]{64}$' or p_root !~ '^[0-9a-f]{64}$' or jsonb_typeof(p_path) <> 'array' then return false; end if;
  if jsonb_array_length(p_path) > 64 then return false; end if;                              -- 2^64 leaves se zyada nahi hote
  node := public._fm_leaf(p_row_hash);
  for el in select * from jsonb_array_elements(p_path) loop
    if jsonb_typeof(el) <> 'object' or (el ->> 's') not in ('L', 'R') or coalesce(el ->> 'h', '') !~ '^[0-9a-f]{64}$' then return false; end if;
    sib := decode(el ->> 'h', 'hex');
    node := case when el ->> 's' = 'R' then public._fm_node(node, sib) else public._fm_node(sib, node) end;
  end loop;
  return encode(node, 'hex') = p_root;
end $$;

-- ==============================================================================================================================
-- 7) CHECKPOINTS — banao / jaancho / dikhao / due hai ya nahi / consistency
-- ==============================================================================================================================
-- 7a) founder_audit_checkpoint(actor, reason): chain ke aaj ke sir tak ka root pakka karta hai. Naya audit row nahi aaya to naya checkpoint nahi banta (dobara-dobara wahi).
create or replace function public.founder_audit_checkpoint(p_actor uuid, p_reason text default 'scheduled checkpoint')
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare
  v_head bigint; v_last public.founder_audit_checkpoints%rowtype; v_id bigint; v_prev text; v_root text; v_hh text; v_ms bigint; v_cp text; v_au jsonb; v_reason text;
begin
  if p_actor is null then raise exception 'E107: actor lazmi' using errcode = '22023'; end if;
  if not exists (select 1 from public.founder_accounts where user_id = p_actor) then raise exception 'E107: actor founder nahi' using errcode = '42501'; end if;
  v_reason := btrim(coalesce(p_reason, ''));
  if length(v_reason) < 8 or length(v_reason) > 300 then raise exception 'E107: wajah 8 se 300 akshar' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtext('founder_audit_chain'));        -- audit append wala hi lock: root hisab ke dauran chain aage nahi barhti
  perform pg_advisory_xact_lock(hashtextextended('founder_merkle:cp', 0));
  select coalesce(max(seq), 0) into v_head from public.founder_audit;
  if v_head = 0 then return jsonb_build_object('created', false, 'reason', 'chain mein abhi koi row nahi'); end if;
  select * into v_last from public.founder_audit_checkpoints order by id desc limit 1;
  if found and v_last.upto_seq = v_head then
    return jsonb_build_object('created', false, 'reason', 'is sir par checkpoint pehle se hai', 'id', v_last.id, 'upto_seq', v_last.upto_seq, 'root', v_last.root, 'cp_hash', v_last.cp_hash);
  end if;
  if found and v_last.upto_seq > v_head then raise exception 'E107: checkpoint chain ke sir se aage hai (upto % > head %)', v_last.upto_seq, v_head using errcode = 'XX001'; end if;
  v_root := encode(public._fm_root_of(public._fm_leaves(v_head)), 'hex');
  select hash into v_hh from public.founder_audit where seq = v_head;
  v_id := coalesce(v_last.id, 0) + 1;
  v_prev := coalesce(v_last.cp_hash, repeat('0', 64));
  v_ms := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_cp := public._fm_cp_hash(v_prev, v_id, v_head, v_head, v_root, v_hh, v_ms, p_actor);
  insert into public.founder_audit_checkpoints (id, upto_seq, leaves, root, head_hash, prev_cp_hash, cp_hash, created_ms, actor, reason)
    values (v_id, v_head, v_head, v_root, v_hh, v_prev, v_cp, v_ms, p_actor, v_reason);
  -- Checkpoint khud bhi audit mein: kisne kab pakka kiya. (Yeh row upto_seq ke BAAD aati hai, agle checkpoint mein shamil hogi.)
  v_au := public.founder_audit_append(p_actor, 'audit.checkpoint', 'cp:' || v_id, v_reason,
                                      jsonb_build_object('cp', v_id, 'upto_seq', v_head, 'root', v_root, 'cp_hash', v_cp));
  return jsonb_build_object('created', true, 'id', v_id, 'upto_seq', v_head, 'leaves', v_head, 'root', v_root, 'head_hash', v_hh, 'cp_hash', v_cp,
                            'prev_cp_hash', v_prev, 'created_ms', v_ms, 'audit_seq', v_au -> 'seq');
end $$;

-- 7b) due hai? (Rust tick yeh poochta hai; kuch nahi badalta.)
create or replace function public.founder_audit_checkpoint_due() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_head bigint; v_upto bigint; v_every integer; v_lag bigint;
begin
  select coalesce(max(seq), 0) into v_head from public.founder_audit;
  select coalesce(max(upto_seq), 0) into v_upto from public.founder_audit_checkpoints;
  select every_rows into v_every from public.founder_audit_merkle_policy where id;
  v_lag := v_head - v_upto;
  return jsonb_build_object('due', v_lag >= coalesce(v_every, 50), 'head_seq', v_head, 'last_upto', v_upto, 'lag_rows', v_lag, 'every_rows', coalesce(v_every, 50));
end $$;

-- 7c) verify: har checkpoint (aakhri p_last) ka root chain se dobara nikaal kar milao, aur checkpoint-chain ki hash bhi.
--     Pehli kharabi ka checkpoint id deta hai; saaf ho to null.
create or replace function public.founder_audit_checkpoint_verify(p_last integer default 20) returns bigint
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare r record; v_prev text; v_expect bigint; v_root text; v_hh text; v_first bigint; v_started boolean := false;
begin
  if p_last is null or p_last < 1 or p_last > 1000 then raise exception 'E107: last 1..1000' using errcode = '22023'; end if;
  select min(id) into v_first from (select id from public.founder_audit_checkpoints order by id desc limit p_last) t;
  if v_first is null then return null; end if;
  for r in select * from public.founder_audit_checkpoints where id >= v_first order by id loop
    if not v_started then
      v_started := true;
      if r.id = 1 then v_prev := repeat('0', 64);
      else select cp_hash into v_prev from public.founder_audit_checkpoints where id = r.id - 1; if v_prev is null then return r.id; end if; end if;
      v_expect := r.id;
    end if;
    if r.id <> v_expect or r.prev_cp_hash <> v_prev or r.leaves <> r.upto_seq then return r.id; end if;
    if r.cp_hash <> public._fm_cp_hash(r.prev_cp_hash, r.id, r.upto_seq, r.leaves, r.root, r.head_hash, r.created_ms, r.actor) then return r.id; end if;
    select hash into v_hh from public.founder_audit where seq = r.upto_seq;
    if v_hh is null or v_hh <> r.head_hash then return r.id; end if;                       -- chain ka sir badal gaya
    v_root := encode(public._fm_root_of(public._fm_leaves(r.upto_seq)), 'hex');
    if v_root <> r.root then return r.id; end if;                                          -- koi purani audit row badli
    v_prev := r.cp_hash; v_expect := r.id + 1;
  end loop;
  return null;
end $$;

-- 7d) list: Audit ledger page ke liye (naye pehle)
create or replace function public.founder_audit_checkpoint_list(p_limit integer default 20) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
begin
  if p_limit is null or p_limit < 1 or p_limit > 200 then raise exception 'E107: limit 1..200' using errcode = '22023'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'upto_seq', upto_seq, 'leaves', leaves, 'root', root, 'head_hash', head_hash,
                                                      'cp_hash', cp_hash, 'prev_cp_hash', prev_cp_hash, 'created_ms', created_ms, 'reason', reason) order by id desc)
                     from (select * from public.founder_audit_checkpoints order by id desc limit p_limit) t), '[]'::jsonb);
end $$;

-- 7e) consistency: purane checkpoint ka root aaj ki chain se dobara nikalo (chain sirf aage barhi hai, purani rows nahi badli)
create or replace function public.founder_audit_consistency(p_cp bigint) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare c public.founder_audit_checkpoints%rowtype; v_now text; v_head bigint;
begin
  select * into c from public.founder_audit_checkpoints where id = p_cp;
  if not found then raise exception 'E107: checkpoint % nahi mila', p_cp using errcode = '22023'; end if;
  select coalesce(max(seq), 0) into v_head from public.founder_audit;
  v_now := encode(public._fm_root_of(public._fm_leaves(c.upto_seq)), 'hex');
  return jsonb_build_object('cp', c.id, 'upto_seq', c.upto_seq, 'stored_root', c.root, 'recomputed_root', v_now, 'ok', v_now = c.root, 'rows_since', v_head - c.upto_seq);
end $$;

-- 7f) policy badalna (audit mein likha jata hai)
create or replace function public.founder_audit_merkle_policy_set(p_actor uuid, p_every integer, p_warn integer, p_fail integer, p_reason text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare v_old public.founder_audit_merkle_policy%rowtype;
begin
  if p_every is null or p_warn is null or p_fail is null then raise exception 'E107: teeno hadd chahiye' using errcode = '22023'; end if;
  if p_every < 5 or p_every > 100000 or p_warn < p_every or p_fail <= p_warn then raise exception 'E107: every >= 5, warn >= every, fail > warn' using errcode = '22023'; end if;
  select * into v_old from public.founder_audit_merkle_policy where id;
  update public.founder_audit_merkle_policy set every_rows = p_every, warn_lag_rows = p_warn, fail_lag_rows = p_fail,
         updated_ms = (extract(epoch from clock_timestamp()) * 1000)::bigint where id;
  perform public.founder_audit_append(p_actor, 'audit.merkle_policy', 'policy', p_reason,
                                      jsonb_build_object('every', jsonb_build_array(v_old.every_rows, p_every), 'warn', jsonb_build_array(v_old.warn_lag_rows, p_warn),
                                                         'fail', jsonb_build_array(v_old.fail_lag_rows, p_fail)));
  return jsonb_build_object('every_rows', p_every, 'warn_lag_rows', p_warn, 'fail_lag_rows', p_fail);
end $$;

-- ==============================================================================================================================
-- 8) EXPORT — ek seq-range ki asli audit rows + har row ka inclusion proof + root. Koi bhi kernel se offline verify kar sakta hai.
--    Cap: 200 rows ek baar mein (response chhota rahe); upto = p_to, isliye root wahi jo us waqt ke checkpoint ka tha.
-- ==============================================================================================================================
create or replace function public.founder_audit_export(p_from bigint, p_to bigint) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare v_head bigint; v_levels jsonb; v_root text; v_rows jsonb; v_cp jsonb;
begin
  select coalesce(max(seq), 0) into v_head from public.founder_audit;
  if v_head = 0 then raise exception 'E107: audit chain mein koi row nahi' using errcode = '22023'; end if;
  if p_from is null or p_to is null or p_from < 1 or p_to < p_from or p_to > v_head then raise exception 'E107: range 1 <= from <= to <= %', v_head using errcode = '22023'; end if;
  if p_to - p_from >= 200 then raise exception 'E107: ek export mein 200 rows se zyada nahi' using errcode = '22023'; end if;
  v_levels := public._fm_levels(public._fm_leaves(p_to));
  v_root := v_levels -> (jsonb_array_length(v_levels) - 1) ->> 0;
  select jsonb_agg(jsonb_build_object('seq', a.seq, 'ts_ms', a.ts_ms, 'actor', a.actor, 'action', a.action, 'target', a.target, 'reason', a.reason, 'meta', a.meta,
                                      'prev_hash', a.prev_hash, 'hash', a.hash, 'path', public._fm_path_from_levels(v_levels, (a.seq - 1)::int)) order by a.seq)
    into v_rows from public.founder_audit a where a.seq between p_from and p_to;
  select jsonb_build_object('id', id, 'cp_hash', cp_hash, 'created_ms', created_ms) into v_cp from public.founder_audit_checkpoints where upto_seq = p_to;
  return jsonb_build_object('from', p_from, 'to', p_to, 'upto', p_to, 'root', v_root, 'checkpoint', v_cp, 'rows', coalesce(v_rows, '[]'::jsonb),
                            'rule', 'leaf=sha256(00||row_hash) node=sha256(01||left||right), odd node promoted');
end $$;

-- ==============================================================================================================================
-- 9) STATS — Dashboard "Ledger Integrity Gauge" ke asli aankre: chain saaf? checkpoint saaf? kitne rows bina checkpoint ke?
-- ==============================================================================================================================
create or replace function public.founder_audit_merkle_stats() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare
  v_head bigint; v_cnt integer; v_last public.founder_audit_checkpoints%rowtype; v_pol public.founder_audit_merkle_policy%rowtype;
  v_chain bigint; v_cpbad bigint; v_lag bigint; v_level text := 'ok'; v_reasons jsonb := '[]'::jsonb;
begin
  select coalesce(max(seq), 0) into v_head from public.founder_audit;
  select count(*) into v_cnt from public.founder_audit_checkpoints;
  select * into v_last from public.founder_audit_checkpoints order by id desc limit 1;
  select * into v_pol from public.founder_audit_merkle_policy where id;
  v_chain := public.founder_audit_verify(1);
  v_cpbad := public.founder_audit_checkpoint_verify(5);
  v_lag := v_head - coalesce(v_last.upto_seq, 0);
  if v_chain is not null then v_level := 'fail'; v_reasons := v_reasons || to_jsonb('audit chain row ' || v_chain || ' par toot'::text); end if;
  if v_cpbad is not null then v_level := 'fail'; v_reasons := v_reasons || to_jsonb('checkpoint ' || v_cpbad || ' root se nahi milta'::text); end if;
  if v_level <> 'fail' and v_lag >= v_pol.fail_lag_rows then v_level := 'fail'; v_reasons := v_reasons || to_jsonb(v_lag || ' rows bina checkpoint'::text);
  elsif v_level = 'ok' and v_lag >= v_pol.warn_lag_rows then v_level := 'warn'; v_reasons := v_reasons || to_jsonb(v_lag || ' rows bina checkpoint'::text); end if;
  return jsonb_build_object('level', v_level, 'reasons', v_reasons, 'rows', v_head, 'checkpoints', v_cnt, 'lag_rows', v_lag,
    'chain_ok', v_chain is null, 'chain_bad_seq', v_chain, 'checkpoint_ok', v_cpbad is null, 'checkpoint_bad_id', v_cpbad,
    'last_checkpoint', case when v_last.id is null then null else jsonb_build_object('id', v_last.id, 'upto_seq', v_last.upto_seq, 'root', v_last.root,
                                                                                   'created_ms', v_last.created_ms, 'cp_hash', v_last.cp_hash) end,
    'policy', jsonb_build_object('every_rows', v_pol.every_rows, 'warn_lag_rows', v_pol.warn_lag_rows, 'fail_lag_rows', v_pol.fail_lag_rows));
end $$;

-- ==============================================================================================================================
-- 9b) TEST VECTORS — kernel (WASM) aur Rust inhi se milaate hain. Hash literal hain: koi DB data nahi, isliye hamesha wahi jawab.
--     Chhote (1..9 leaves) trees: har size ka root + har leaf ka path. Odd-node promotion ka saboot.
-- ==============================================================================================================================
create or replace function public.founder_audit_merkle_vectors() returns jsonb
language plpgsql immutable set search_path = pg_catalog, public, extensions as $$
declare n integer; i integer; hs text[]; lv bytea[]; levels jsonb; out jsonb := '[]'::jsonb; paths jsonb;
begin
  for n in 1 .. 9 loop
    hs := array(select encode(extensions.digest(convert_to('founder-merkle-vector-' || g, 'UTF8'), 'sha256'), 'hex') from generate_series(1, n) g order by g);
    lv := array(select public._fm_leaf(h) from unnest(hs) with ordinality as t(h, o) order by o);
    levels := public._fm_levels(lv);
    paths := '[]'::jsonb;
    for i in 0 .. n - 1 loop paths := paths || jsonb_build_array(public._fm_path_from_levels(levels, i)); end loop;
    out := out || jsonb_build_array(jsonb_build_object('n', n, 'hashes', to_jsonb(hs), 'root', levels -> (jsonb_array_length(levels) - 1) ->> 0, 'paths', paths));
  end loop;
  return out;
end $$;

-- ==============================================================================================================================
-- 10) LIVE SOURCE — checkpoints E109 ka live source banta hai (Recent changes mein "Checkpoint +1"); chalte rehne ki umeed: roz kam az kam ek
-- ==============================================================================================================================
do $$
begin
  insert into public.founder_live_sources (key, label, relation, ts_candidates, ts_unit, owner, expect_max_age_secs, sort)
    values ('audit_checkpoints', 'Audit checkpoints', 'public.founder_audit_checkpoints', array['created_ms'], 'epoch_ms', 'founder', null, 140)
  on conflict (key) do nothing;
end $$;

-- ==============================================================================================================================
-- 11) GRANTS — sab RPC sirf service_role (Rust). Browser/anon/authenticated kabhi seedha nahi.
-- ==============================================================================================================================
do $$
declare f text;
begin
  foreach f in array array[
    'public.founder_audit_merkle_root(bigint)', 'public.founder_audit_merkle_proof(bigint,bigint)', 'public.founder_audit_proof_check(text,jsonb,text)',
    'public.founder_audit_checkpoint(uuid,text)', 'public.founder_audit_checkpoint_due()', 'public.founder_audit_checkpoint_verify(integer)',
    'public.founder_audit_checkpoint_list(integer)', 'public.founder_audit_consistency(bigint)',
    'public.founder_audit_merkle_policy_set(uuid,integer,integer,integer,text)', 'public.founder_audit_export(bigint,bigint)',
    'public.founder_audit_merkle_stats()', 'public.founder_audit_merkle_vectors()',
    'public._fm_leaf(text)', 'public._fm_node(bytea,bytea)', 'public._fm_cp_hash(text,bigint,bigint,bigint,text,text,bigint,uuid)', 'public._fm_hexes(bytea[])',
    'public._fm_next_level(bytea[])', 'public._fm_root_of(bytea[])', 'public._fm_levels(bytea[])', 'public._fm_path_from_levels(jsonb,integer)',
    'public._fm_leaves(bigint)', 'public._fm_immutable()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ==============================================================================================================================
-- 11b) PULSE + GET — Dashboard har 5 second jo poochhta hai wo SASTA hona chahiye: sirf ginti + aakhri checkpoint, poori chain dobara nahi nikalta.
--      (Poora hisab founder_audit_merkle_stats() mein hai: Audit ledger page kholne par ya checkpoint banne par.)
-- ==============================================================================================================================
create or replace function public.founder_audit_merkle_pulse() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare v_head bigint; v_last public.founder_audit_checkpoints%rowtype; v_pol public.founder_audit_merkle_policy%rowtype; v_lag bigint; v_level text := 'ok';
begin
  select coalesce(max(seq), 0) into v_head from public.founder_audit;
  select * into v_last from public.founder_audit_checkpoints order by id desc limit 1;
  select * into v_pol from public.founder_audit_merkle_policy where id;
  v_lag := v_head - coalesce(v_last.upto_seq, 0);
  if v_lag >= v_pol.fail_lag_rows then v_level := 'fail'; elsif v_lag >= v_pol.warn_lag_rows then v_level := 'warn'; end if;
  return jsonb_build_object('level', v_level, 'rows', v_head, 'lag_rows', v_lag, 'every_rows', v_pol.every_rows,
                            'due', v_lag >= v_pol.every_rows,
                            'last_checkpoint', case when v_last.id is null then null
                                               else jsonb_build_object('id', v_last.id, 'upto_seq', v_last.upto_seq, 'root', v_last.root, 'created_ms', v_last.created_ms) end);
end $$;

create or replace function public.founder_audit_checkpoint_get(p_id bigint) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare c public.founder_audit_checkpoints%rowtype;
begin
  select * into c from public.founder_audit_checkpoints where id = p_id;
  if not found then raise exception 'E107: checkpoint % nahi mila', p_id using errcode = '22023'; end if;
  return jsonb_build_object('id', c.id, 'upto_seq', c.upto_seq, 'leaves', c.leaves, 'root', c.root, 'head_hash', c.head_hash, 'prev_cp_hash', c.prev_cp_hash,
                            'cp_hash', c.cp_hash, 'created_ms', c.created_ms, 'actor', c.actor, 'reason', c.reason);
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.founder_audit_merkle_pulse()', 'public.founder_audit_checkpoint_get(bigint)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ==============================================================================================================================
-- 12) SELFTEST — poora rollback (kuch persist nahi). Asli DB par chalta hai: nakli founder nahi banta, sirf maujooda founder use hota hai.
--     Agar founder nahi mila to behaviour wala hissa SKIP hota hai (CHECK_E107 phir bhi structure jaanchta hai).
-- ==============================================================================================================================
create or replace function public.founder_audit_merkle_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '120s' as $$
declare
  v_uid uuid; msg text := 'E107 selftest OK'; r jsonb; r2 jsonb; vec jsonb; v jsonb; i integer; j integer; n integer; h text; lv bytea[]; root1 text; root2 text;
  v_bad bigint; v_before bigint; v_cps bigint; ex jsonb; tampered boolean := false;
begin
  if to_regclass('public.founder_audit_checkpoints') is null then return 'E107 selftest SKIP: E107 chalayein'; end if;
  select user_id into v_uid from public.founder_accounts limit 1;
  begin
    -- ---------- A) hash qaide: leaf/node prefix, determinism ----------
    h := repeat('ab', 32);
    if public._fm_leaf(h) = public._fm_leaf(repeat('ac', 32)) then raise exception 'alag hash ka leaf ek jaisa'; end if;
    if public._fm_leaf(h) <> public._fm_leaf(h) then raise exception 'leaf deterministic nahi'; end if;
    if encode(public._fm_leaf(h), 'hex') = encode(extensions.digest(decode(h, 'hex'), 'sha256'), 'hex') then raise exception 'leaf par 0x00 prefix nahi laga'; end if;
    if public._fm_node('\x01'::bytea, '\x02'::bytea) = public._fm_node('\x02'::bytea, '\x01'::bytea) then raise exception 'node left/right mein farq nahi'; end if;
    if public._fm_leaf(h) = public._fm_node(decode(repeat('00', 32), 'hex'), decode(repeat('00', 32), 'hex')) then raise exception 'leaf aur node domain alag nahi'; end if;
    begin perform public._fm_leaf('zz'); raise exception 'ghalat hex leaf chal gaya'; exception when others then if sqlerrm like 'ghalat hex%' then raise; end if; end;

    -- ---------- B) tree: chhote sizes, odd promotion ----------
    lv := array[public._fm_leaf(repeat('01', 32))];
    if public._fm_root_of(lv) <> lv[1] then raise exception '1 leaf ka root leaf honi chahiye'; end if;
    lv := array[public._fm_leaf(repeat('01', 32)), public._fm_leaf(repeat('02', 32))];
    if public._fm_root_of(lv) <> public._fm_node(lv[1], lv[2]) then raise exception '2 leaves ka root galat'; end if;
    lv := array[public._fm_leaf(repeat('01', 32)), public._fm_leaf(repeat('02', 32)), public._fm_leaf(repeat('03', 32))];
    if public._fm_root_of(lv) <> public._fm_node(public._fm_node(lv[1], lv[2]), lv[3]) then raise exception '3 leaves: aakhri node promote nahi hua'; end if;
    if public._fm_root_of(lv) = public._fm_node(public._fm_node(lv[1], lv[2]), public._fm_node(lv[3], lv[3])) then raise exception '3 leaves: duplicate hua (galat)'; end if;
    begin perform public._fm_root_of('{}'::bytea[]); raise exception 'khali tree chal gaya'; exception when sqlstate '22023' then null; end;
    if jsonb_array_length(public._fm_levels(lv)) <> 3 then raise exception '3 leaves ke 3 levels (3,2,1)'; end if;

    -- ---------- C) test vectors: har size, har leaf ka path, SQL proof check, tamper ----------
    vec := public.founder_audit_merkle_vectors();
    if jsonb_array_length(vec) <> 9 then raise exception 'vectors 9 hone chahiye'; end if;
    for i in 0 .. 8 loop
      v := vec -> i; n := (v ->> 'n')::int;
      if jsonb_array_length(v -> 'hashes') <> n or jsonb_array_length(v -> 'paths') <> n then raise exception 'vector % ki ginti galat', n; end if;
      for j in 0 .. n - 1 loop
        if not public.founder_audit_proof_check(v -> 'hashes' ->> j, v -> 'paths' -> j, v ->> 'root') then raise exception 'vector n=% leaf % proof fail', n, j; end if;
        if n > 1 and public.founder_audit_proof_check(v -> 'hashes' ->> ((j + 1) % n), v -> 'paths' -> j, v ->> 'root') then raise exception 'vector n=%: doosre leaf par proof chal gaya', n; end if;
      end loop;
      if public.founder_audit_proof_check(repeat('00', 32), v -> 'paths' -> 0, v ->> 'root') then raise exception 'vector n=%: ghalat row hash par proof chal gaya', n; end if;
      if public.founder_audit_proof_check(v -> 'hashes' ->> 0, v -> 'paths' -> 0, repeat('00', 32)) then raise exception 'vector n=%: ghalat root par proof chal gaya', n; end if;
    end loop;
    if jsonb_array_length((vec -> 0) -> 'paths' -> 0) <> 0 then raise exception '1 leaf ka path khali hona chahiye'; end if;
    if jsonb_array_length((vec -> 2) -> 'paths' -> 2) <> 1 then raise exception '3 leaves mein aakhri leaf ka path 1 hop (promote)'; end if;
    if public.founder_audit_merkle_vectors() <> vec then raise exception 'vectors deterministic nahi'; end if;
    -- proof check shape guard
    if public.founder_audit_proof_check(null, '[]'::jsonb, repeat('00', 32)) then raise exception 'null hash chal gaya'; end if;
    if public.founder_audit_proof_check('xyz', '[]'::jsonb, repeat('00', 32)) then raise exception 'ghalat hash shape chal gayi'; end if;
    if public.founder_audit_proof_check(repeat('00', 32), '{}'::jsonb, repeat('00', 32)) then raise exception 'object path chal gaya'; end if;
    if public.founder_audit_proof_check(repeat('00', 32), '[{"s":"X","h":"00"}]'::jsonb, repeat('00', 32)) then raise exception 'ghalat side chal gayi'; end if;
    if public.founder_audit_proof_check(repeat('00', 32), (select jsonb_agg(jsonb_build_object('s', 'L', 'h', repeat('00', 32))) from generate_series(1, 65)), repeat('00', 32)) then raise exception '65 hop chal gaye'; end if;

    -- ---------- D) argument validation ----------
    begin perform public.founder_audit_merkle_proof(0); raise exception 'seq 0 chal gaya'; exception when sqlstate '22023' then null; end;
    begin perform public.founder_audit_merkle_proof(null); raise exception 'seq null chal gaya'; exception when sqlstate '22023' then null; end;
    begin perform public.founder_audit_export(5, 2); raise exception 'ulta range chal gaya'; exception when sqlstate '22023' then null; end;
    begin perform public.founder_audit_checkpoint_verify(0); raise exception 'last 0 chal gaya'; exception when sqlstate '22023' then null; end;
    begin perform public.founder_audit_checkpoint_list(1000); raise exception 'limit 1000 chal gaya'; exception when sqlstate '22023' then null; end;
    begin perform public.founder_audit_consistency(-5); raise exception 'ghalat checkpoint chal gaya'; exception when sqlstate '22023' then null; end;
    begin perform public.founder_audit_checkpoint_get(-5); raise exception 'ghalat checkpoint get chal gaya'; exception when sqlstate '22023' then null; end;
    begin perform public.founder_audit_checkpoint(null, 'koi wajah thik hai'); raise exception 'null actor chal gaya'; exception when sqlstate '22023' then null; end;

    -- ---------- E) asli chain par behaviour (founder chahiye) ----------
    if v_uid is not null then
      begin perform public.founder_audit_checkpoint(v_uid, 'chhota'); raise exception 'chhoti wajah chal gayi'; exception when sqlstate '22023' then null; end;
      begin perform public.founder_audit_checkpoint(gen_random_uuid(), 'nakli founder actor'); raise exception 'nakli actor chal gaya'; exception when sqlstate '42501' then null; end;
      -- chain mein kam az kam 7 rows (ginti odd bhi, even bhi)
      for i in 1 .. 7 loop perform public.founder_audit_append(v_uid, 'selftest.merkle', 'row:' || i, 'E107 selftest row number ' || i); end loop;
      n := (select max(seq) from public.founder_audit);
      r := public.founder_audit_merkle_root();
      if (r ->> 'upto')::bigint <> n or (r ->> 'leaves')::bigint <> n then raise exception 'root upto/leaves galat: %', r; end if;
      if r ->> 'root' !~ '^[0-9a-f]{64}$' then raise exception 'root shape galat'; end if;
      if r ->> 'head_hash' <> (select hash from public.founder_audit where seq = n) then raise exception 'head_hash galat'; end if;
      if public.founder_audit_merkle_root(n) <> r then raise exception 'root(upto=head) alag'; end if;
      if (public.founder_audit_merkle_root(1) ->> 'root') <> encode(public._fm_leaf((select hash from public.founder_audit where seq = 1)), 'hex') then raise exception '1 row ka root = uska leaf'; end if;
      -- har seq ka proof asli root se milta hai; kisi aur seq ke hash par nahi
      for i in 1 .. n loop
        r2 := public.founder_audit_merkle_proof(i);
        if r2 ->> 'root' <> r ->> 'root' then raise exception 'seq % proof ka root alag', i; end if;
        if not public.founder_audit_proof_check(r2 ->> 'row_hash', r2 -> 'path', r ->> 'root') then raise exception 'seq % proof fail', i; end if;
        if n > 1 and public.founder_audit_proof_check((select hash from public.founder_audit where seq = case when i = 1 then 2 else 1 end), r2 -> 'path', r ->> 'root') then
          raise exception 'seq % ka path doosri row par chal gaya', i; end if;
      end loop;
      -- purane upto par bhi proof (chhota tree)
      r2 := public.founder_audit_merkle_proof(2, 3);
      if not public.founder_audit_proof_check(r2 ->> 'row_hash', r2 -> 'path', public.founder_audit_merkle_root(3) ->> 'root') then raise exception 'upto=3 proof fail'; end if;
      begin perform public.founder_audit_merkle_proof(n + 1); raise exception 'head ke baad ka seq chal gaya'; exception when sqlstate '22023' then null; end;
      begin perform public.founder_audit_merkle_proof(3, 2); raise exception 'seq > upto chal gaya'; exception when sqlstate '22023' then null; end;
      begin perform public.founder_audit_merkle_root(n + 1); raise exception 'upto > head chal gaya'; exception when sqlstate '22023' then null; end;

      -- ---------- F) checkpoint banana, dobara na banana, chain ----------
      v_cps := (select count(*) from public.founder_audit_checkpoints);
      root1 := public.founder_audit_merkle_root() ->> 'root';
      r := public.founder_audit_checkpoint(v_uid, 'E107 selftest checkpoint one');
      if not (r ->> 'created')::boolean then raise exception 'checkpoint bana nahi: %', r; end if;
      if r ->> 'root' <> root1 then raise exception 'checkpoint root != root'; end if;
      if (r ->> 'upto_seq')::bigint <> n then raise exception 'checkpoint upto galat'; end if;
      if (select count(*) from public.founder_audit_checkpoints) <> v_cps + 1 then raise exception 'checkpoint row nahi bani'; end if;
      if (select action from public.founder_audit where seq = (r ->> 'audit_seq')::bigint) <> 'audit.checkpoint' then raise exception 'checkpoint audit mein nahi likha'; end if;
      -- wahi sir par dobara = naya nahi (lekin audit.checkpoint row aa chuki, isliye head aage barh gaya hai: naya checkpoint BANNA chahiye)
      r2 := public.founder_audit_checkpoint(v_uid, 'E107 selftest checkpoint two');
      if not (r2 ->> 'created')::boolean then raise exception 'doosra checkpoint (audit.checkpoint row ke baad) bana nahi'; end if;
      if (r2 ->> 'upto_seq')::bigint <> (r ->> 'audit_seq')::bigint then raise exception 'doosra upto = pehle ki audit row hona chahiye'; end if;
      if r2 ->> 'prev_cp_hash' <> r ->> 'cp_hash' then raise exception 'checkpoint chain judi nahi'; end if;
      if public.founder_audit_checkpoint_verify(10) is not null then raise exception 'saaf checkpoints verify fail'; end if;
      if not (public.founder_audit_consistency((r ->> 'id')::bigint) ->> 'ok')::boolean then raise exception 'purane checkpoint ki consistency fail'; end if;
      if (public.founder_audit_checkpoint_get((r ->> 'id')::bigint) ->> 'cp_hash') <> r ->> 'cp_hash' then raise exception 'checkpoint_get galat'; end if;
      if jsonb_array_length(public.founder_audit_checkpoint_list(5)) < 2 then raise exception 'list mein 2 checkpoint nahi'; end if;
      if (public.founder_audit_checkpoint_list(5) -> 0 ->> 'id')::bigint <> (r2 ->> 'id')::bigint then raise exception 'list naye pehle nahi'; end if;
      -- append-only: update/delete/truncate band
      begin update public.founder_audit_checkpoints set reason = 'badla hua wajah text' where id = (r ->> 'id')::bigint; raise exception 'checkpoint update chal gaya';
      exception when sqlstate '42501' then null; end;
      begin delete from public.founder_audit_checkpoints where id = (r ->> 'id')::bigint; raise exception 'checkpoint delete chal gaya'; exception when sqlstate '42501' then null; end;
      begin truncate public.founder_audit_checkpoints; raise exception 'checkpoint truncate chal gaya'; exception when sqlstate '42501' then null; end;

      -- ---------- G) due / pulse / stats / policy ----------
      v := public.founder_audit_checkpoint_due();
      if (v ->> 'head_seq')::bigint <> (select max(seq) from public.founder_audit) then raise exception 'due head galat'; end if;
      if (v ->> 'lag_rows')::bigint <> (v ->> 'head_seq')::bigint - (v ->> 'last_upto')::bigint then raise exception 'due lag galat'; end if;
      v := public.founder_audit_merkle_pulse();
      if not (v ? 'level' and v ? 'rows' and v ? 'lag_rows' and v ? 'due' and v ? 'last_checkpoint') then raise exception 'pulse keys kam: %', v; end if;
      if (v -> 'last_checkpoint' ->> 'id')::bigint <> (r2 ->> 'id')::bigint then raise exception 'pulse aakhri checkpoint galat'; end if;
      v := public.founder_audit_merkle_stats();
      if not (v ? 'level' and v ? 'chain_ok' and v ? 'checkpoint_ok' and v ? 'policy' and v ? 'last_checkpoint') then raise exception 'stats keys kam: %', v; end if;
      if not (v ->> 'chain_ok')::boolean or not (v ->> 'checkpoint_ok')::boolean then raise exception 'saaf chain par stats fail: %', v; end if;
      begin perform public.founder_audit_merkle_policy_set(v_uid, 4, 10, 20, 'policy test chhoti hadd'); raise exception 'every < 5 chal gaya'; exception when sqlstate '22023' then null; end;
      begin perform public.founder_audit_merkle_policy_set(v_uid, 10, 5, 20, 'policy test ulti hadd'); raise exception 'warn < every chal gaya'; exception when sqlstate '22023' then null; end;
      v := public.founder_audit_merkle_policy_set(v_uid, 10, 20, 40, 'E107 selftest policy 10/20/40');
      if (v ->> 'every_rows')::int <> 10 then raise exception 'policy set nahi hui'; end if;
      -- lag > fail => pulse/stats fail dikhate hain
      for i in 1 .. 41 loop perform public.founder_audit_append(v_uid, 'selftest.merkle', 'lag:' || i, 'E107 selftest lag row ' || i); end loop;
      if public.founder_audit_merkle_pulse() ->> 'level' <> 'fail' then raise exception 'lag 41 par pulse fail nahi'; end if;
      if not (public.founder_audit_checkpoint_due() ->> 'due')::boolean then raise exception 'lag 41 par due nahi'; end if;
      r := public.founder_audit_checkpoint(v_uid, 'E107 selftest checkpoint three');
      if public.founder_audit_merkle_pulse() ->> 'level' <> 'ok' then raise exception 'checkpoint ke baad pulse ok nahi'; end if;

      -- ---------- H) export: rows + har row ka proof, cap ----------
      n := (select max(seq) from public.founder_audit);
      ex := public.founder_audit_export(n - 5, n);
      if jsonb_array_length(ex -> 'rows') <> 6 then raise exception 'export rows 6 nahi: %', jsonb_array_length(ex -> 'rows'); end if;
      if ex ->> 'root' <> public.founder_audit_merkle_root(n) ->> 'root' then raise exception 'export root galat'; end if;
      for i in 0 .. 5 loop
        if not public.founder_audit_proof_check(ex -> 'rows' -> i ->> 'hash', ex -> 'rows' -> i -> 'path', ex ->> 'root') then raise exception 'export row % proof fail', i; end if;
      end loop;
      begin perform public.founder_audit_export(1, 300); raise exception '200+ rows export chal gaya'; exception when sqlstate '22023' then null; end;
      begin perform public.founder_audit_export(1, n + 1); raise exception 'head ke aage export chal gaya'; exception when sqlstate '22023' then null; end;

      -- ---------- I) tamper pakda jata hai (trigger band karke purani audit row badlo; sab rollback) ----------
      begin
        alter table public.founder_audit disable trigger founder_audit_no_upd;
        update public.founder_audit set reason = 'koi chhupa hua badlav' where seq = 2;
        tampered := true;
        alter table public.founder_audit enable trigger founder_audit_no_upd;
      exception when insufficient_privilege then tampered := false;
      end;
      if tampered then
        if public.founder_audit_verify(1) is null then raise exception 'tamper audit chain ne nahi pakda'; end if;
        if (select (public.founder_audit_merkle_stats() ->> 'chain_ok')::boolean) then raise exception 'stats chain_ok true tamper par'; end if;
      end if;
      -- ab hash hi badal do (reason ke saath hash alag hota hai): checkpoint verify root se mismatch pakde
      begin
        alter table public.founder_audit disable trigger founder_audit_no_upd;
        update public.founder_audit set hash = repeat('f', 64) where seq = 3;
        alter table public.founder_audit enable trigger founder_audit_no_upd;
        v_bad := public.founder_audit_checkpoint_verify(50);
        if v_bad is null then raise exception 'row hash badla par checkpoint verify ne nahi pakda'; end if;
        if (public.founder_audit_merkle_stats() ->> 'level') <> 'fail' then raise exception 'tamper par level fail nahi'; end if;
      exception when insufficient_privilege then null;
      end;
    end if;

    raise exception 'E107_ROLLBACK_OK';
  exception when others then
    if sqlerrm = 'E107_ROLLBACK_OK' then msg := 'E107 selftest OK' || case when v_uid is null then ' (founder nahi mila: chain hissa SKIP)' else '' end;
    else msg := 'E107 selftest FAIL: ' || sqlerrm; end if;
  end;
  return msg;
end $$;
revoke all on function public.founder_audit_merkle_selftest() from public, anon, authenticated;
grant execute on function public.founder_audit_merkle_selftest() to service_role;

do $$ begin raise notice 'E107 founder audit merkle tayyar. Chalao: CHECK_E107.sql'; end $$;

-- ==============================================================================================================================
-- 13) CROSSCHECK — doosra, ALAG tareeqa: RFC 6962 ki recursive definition (MTH = split at largest power of two < n) se root nikalo aur upar ke
--     iterative (neeche se upar, odd promote) tareeqe se milao, 1..70 leaves. Dono ek hi tree banate hain: yeh uska hisaabi saboot hai.
--     Rust merkle.rs aur WASM kernel isi iterative tareeqe ko dohrate hain, isliye yeh test teeno ki buniyad hai.
-- ==============================================================================================================================
create or replace function public._fm_mth(p_leaves bytea[], p_lo integer, p_hi integer) returns bytea
language plpgsql immutable set search_path = pg_catalog, public, extensions as $$
declare n integer := p_hi - p_lo + 1; k integer := 1;
begin
  if n < 1 then raise exception 'E107: khali range' using errcode = '22023'; end if;
  if n = 1 then return p_leaves[p_lo]; end if;
  while k * 2 < n loop k := k * 2; end loop;                -- sab se bara 2 ka power jo n se chhota ho
  return public._fm_node(public._fm_mth(p_leaves, p_lo, p_lo + k - 1), public._fm_mth(p_leaves, p_lo + k, p_hi));
end $$;

create or replace function public.founder_audit_merkle_crosscheck() returns text
language plpgsql immutable set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare n integer; lv bytea[];
begin
  for n in 1 .. 70 loop
    lv := array(select public._fm_leaf(encode(extensions.digest(convert_to('crosscheck-' || g, 'UTF8'), 'sha256'), 'hex')) from generate_series(1, n) g order by g);
    if public._fm_mth(lv, 1, n) <> public._fm_root_of(lv) then return 'E107 crosscheck FAIL: n=' || n; end if;
  end loop;
  return 'E107 crosscheck OK (1..70 leaves, RFC 6962 recursive == iterative)';
end $$;

-- ==============================================================================================================================
-- 14) LEAF + QAIDA — debugging aur UI "yeh kaise kaam karta hai" ke liye (kuch badalta nahi)
-- ==============================================================================================================================
create or replace function public.founder_audit_merkle_leaf(p_seq bigint) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '5s' as $$
declare v_hash text;
begin
  select hash into v_hash from public.founder_audit where seq = p_seq;
  if v_hash is null then raise exception 'E107: seq % nahi mila', p_seq using errcode = '22023'; end if;
  return jsonb_build_object('seq', p_seq, 'row_hash', v_hash, 'leaf', encode(public._fm_leaf(v_hash), 'hex'));
end $$;

create or replace function public.founder_audit_merkle_rule() returns jsonb
language sql immutable set search_path = pg_catalog, public as $$
  select jsonb_build_object('leaf', 'sha256(0x00 || row_hash_bytes)', 'node', 'sha256(0x01 || left || right)',
                            'odd_node', 'promoted to the next level unchanged (never duplicated)', 'leaf_order', 'audit seq 1..N',
                            'checkpoint_hash', 'sha256 of length-prefixed (prev_cp_hash, id, upto_seq, leaves, root, head_hash, created_ms, actor)',
                            'proof_side', jsonb_build_object('R', 'sibling is on the right: node = H(01 || node || sibling)', 'L', 'sibling is on the left: node = H(01 || sibling || node)'))
$$;

do $$
declare f text;
begin
  foreach f in array array['public._fm_mth(bytea[],integer,integer)', 'public.founder_audit_merkle_crosscheck()', 'public.founder_audit_merkle_leaf(bigint)', 'public.founder_audit_merkle_rule()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- ==============================================================================================================================
-- 15) RUNBOOK (comment, code nahi) — kya karna hai jab kuch ghalat dikhe
-- ==============================================================================================================================
--  * Dashboard "Ledger Integrity" fail, reason "audit chain row N par toot": founder_audit ki row N ya uske baad ki koi row badli gayi.
--    Kuch mat mitao. Pehle founder_audit_verify(1) se pehli kharabi ka seq lo, phir pichhla backup (Supabase PITR) se us row ka hash milao.
--  * Reason "checkpoint K root se nahi milta": checkpoint K ke baad chain mein purani row badli, ya checkpoint table se chhed-chhad hui.
--    founder_audit_consistency(K) stored_root aur recomputed_root dono dikhata hai; founder_audit_export se wahi range kernel mein offline verify karo.
--  * Reason "N rows bina checkpoint": Rust tick checkpoint nahi bana raha (ya founder_accounts khali). founder_audit_checkpoint_due() dekho,
--    phir founder_audit_checkpoint(<founder uuid>, 'manual catch-up checkpoint') haath se chalao. Isse chain par koi asar nahi.
--  * Checkpoint kabhi delete nahi hote (trigger + privilege dono). Galat reason likha gaya to nayi row ke zariye audit mein sudhaar likha jata hai.
--  * Chain bahut lambi ho (max_leaves se zyada): policy mein max_leaves badhao ya Merkle ko segment (har 100k rows ek tree, upar ek tree) mein todo;
--    yeh alag E-file ka kaam hai, E107 ki leaves seedhi seq 1..N hain.
--  * Offline verification: founder_audit_export(from, to) ka jawab kernel ke `merkle` module ko do: wo har row ka path root tak chalata hai aur
--    root ko checkpoint ke root se milata hai; SQL ki founder_audit_proof_check() usi hisaab ka SQL roop hai.
-- ==============================================================================================================================
do $$ begin raise notice 'E107 crosscheck + runbook tayyar'; end $$;

-- ==============================================================================================================================
-- 16) PREVIEW + RANGE VERIFY — "abhi verify karo" button ke liye: kuch likhe bina dikhao ke checkpoint banta to kya banta; aur ek range ke
--     har row ka proof SQL mein dobara chala kar ginti do. (Kernel browser mein yehi karta hai; yeh server ki taraf ka doosra gawah hai.)
-- ==============================================================================================================================
create or replace function public.founder_audit_checkpoint_preview() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare v_head bigint; v_last public.founder_audit_checkpoints%rowtype; v_root text;
begin
  select coalesce(max(seq), 0) into v_head from public.founder_audit;
  if v_head = 0 then return jsonb_build_object('would_create', false, 'reason', 'chain mein abhi koi row nahi'); end if;
  select * into v_last from public.founder_audit_checkpoints order by id desc limit 1;
  v_root := encode(public._fm_root_of(public._fm_leaves(v_head)), 'hex');
  return jsonb_build_object('would_create', not found or v_last.upto_seq < v_head, 'next_id', coalesce(v_last.id, 0) + 1, 'upto_seq', v_head, 'root', v_root,
                            'rows_since_last', v_head - coalesce(v_last.upto_seq, 0), 'prev_cp_hash', coalesce(v_last.cp_hash, repeat('0', 64)));
end $$;

create or replace function public.founder_audit_merkle_verify_range(p_from bigint, p_to bigint) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare ex jsonb; i integer; ok_n integer := 0; bad jsonb := '[]'::jsonb; n integer;
begin
  ex := public.founder_audit_export(p_from, p_to);                       -- range/cap ki jaanch wahin
  n := jsonb_array_length(ex -> 'rows');
  for i in 0 .. n - 1 loop
    if public.founder_audit_proof_check(ex -> 'rows' -> i ->> 'hash', ex -> 'rows' -> i -> 'path', ex ->> 'root') then ok_n := ok_n + 1;
    else bad := bad || to_jsonb((ex -> 'rows' -> i ->> 'seq')::bigint); end if;
  end loop;
  return jsonb_build_object('from', p_from, 'to', p_to, 'checked', n, 'ok', ok_n, 'bad_seqs', bad, 'root', ex ->> 'root', 'all_ok', ok_n = n);
end $$;

-- Doosra selftest (alag taake pehle ka lamba test na bhare): preview + range verify, poora rollback.
create or replace function public.founder_audit_merkle_selftest2() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare v_uid uuid; msg text := 'E107 selftest2 OK'; r jsonb; i integer; n bigint;
begin
  if to_regclass('public.founder_audit_checkpoints') is null then return 'E107 selftest2 SKIP: E107 chalayein'; end if;
  select user_id into v_uid from public.founder_accounts limit 1;
  begin
    if v_uid is not null then
      for i in 1 .. 5 loop perform public.founder_audit_append(v_uid, 'selftest.merkle2', 'row:' || i, 'E107 selftest2 row number ' || i); end loop;
      n := (select max(seq) from public.founder_audit);
      r := public.founder_audit_checkpoint_preview();
      if not (r ->> 'would_create')::boolean or (r ->> 'upto_seq')::bigint <> n then raise exception 'preview galat: %', r; end if;
      if (select count(*) from public.founder_audit_checkpoints where upto_seq = n) <> 0 then raise exception 'preview ne likh diya'; end if;
      if r ->> 'root' <> public.founder_audit_merkle_root() ->> 'root' then raise exception 'preview root alag'; end if;
      r := public.founder_audit_merkle_verify_range(n - 4, n);
      if not (r ->> 'all_ok')::boolean or (r ->> 'checked')::int <> 5 then raise exception 'verify_range fail: %', r; end if;
      r := public.founder_audit_merkle_verify_range(1, n);
      if (r ->> 'checked')::bigint <> n then raise exception 'verify_range ginti galat (chhota chain)'; end if;
      begin perform public.founder_audit_merkle_verify_range(n, n + 1); raise exception 'head ke aage range chal gayi'; exception when sqlstate '22023' then null; end;
      if public.founder_audit_merkle_leaf(n) ->> 'leaf' <> encode(public._fm_leaf((select hash from public.founder_audit where seq = n)), 'hex') then raise exception 'leaf galat'; end if;
      begin perform public.founder_audit_merkle_leaf(n + 100); raise exception 'nakli seq ka leaf chal gaya'; exception when sqlstate '22023' then null; end;
      if not (public.founder_audit_merkle_rule() ? 'proof_side') then raise exception 'rule keys kam'; end if;
    end if;
    raise exception 'E107_ROLLBACK_OK';
  exception when others then
    if sqlerrm = 'E107_ROLLBACK_OK' then msg := 'E107 selftest2 OK' || case when v_uid is null then ' (founder nahi mila: SKIP)' else '' end;
    else msg := 'E107 selftest2 FAIL: ' || sqlerrm; end if;
  end;
  return msg;
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.founder_audit_checkpoint_preview()', 'public.founder_audit_merkle_verify_range(bigint,bigint)', 'public.founder_audit_merkle_selftest2()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

do $$ begin raise notice 'E107 preview + range verify tayyar'; end $$;

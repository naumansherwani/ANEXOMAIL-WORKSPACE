
-- E183 - Q1b4: THE VERDICT OF EVERY INBOUND MAIL (SPF, DKIM, DMARC, ARC, iprev, TLS) + THE TRUST SCORE + LOOKALIKE DEFENCE + A HASH-CHAINED VERDICT LEDGER  (his 17 Nov 2026 02:10 order: SQL above super advanced, plan docs/claude/Q1B4-MASTER-PLAN-17NOV.md).
-- Until now the intake wrote 'none' (not checked) on every mail. The Rust verifier (fmail_auth.rs, mail-auth 0.9.2, RFC 9989 tree walk) now hands its findings to fmail_auth_record183, which in ONE transaction:
--   * stores one evidence row per mail (who connected, which domains, every verdict, the TLS it came over) and one row per DKIM signature,
--   * decides LOOKALIKE inside the database from what this mailbox has already trusted (edit distance + confusable skeleton + a brand list), so no Rust copy can drift,
--   * computes the TRUST SCORE 0-100 and GRADE A+..F by ONE immutable function (fmail_trust_score183) and returns the REASONS in words, so the screen never says "trust me",
--   * appends the row to a per-mailbox SHA-256 hash chain (append-only, forced RLS, nothing for anon / authenticated) and copies the short verdicts onto fmail_messages.
-- Observe mode: nothing here moves, blocks or deletes a mail. Outgoing mail gets its own facts door (fmail_out_facts183) and fmail_get169 / fmail_list169 now also return sent_ms (the time the receiver said 250, not the compose time: gap G3 of AUDIT-Q1d).
-- Needs E167, E170, E175 (helpers + outbox + DKIM tables), E179 (door audit), E182. Re-run safe (create if not exists / create or replace / do-blocks).

-- ===============================================================================================================================================
-- 0) two short facts on the message row, so a list can sort and show the grade without a join
-- ===============================================================================================================================================
alter table public.fmail_messages add column if not exists trust_score smallint, add column if not exists trust_grade text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'fmail_messages_trust_ck' and conrelid = 'public.fmail_messages'::regclass) then
    alter table public.fmail_messages add constraint fmail_messages_trust_ck
      check ((trust_score is null and trust_grade is null) or (trust_score between 0 and 100 and trust_grade in ('A+', 'A', 'B', 'C', 'D', 'F')));
  end if;
end $$;
create index if not exists fmail_messages_grade_ix on public.fmail_messages (mailbox_id, trust_grade, received_at desc) where trust_grade is not null;

-- ===============================================================================================================================================
-- 1) the brand list: domains that criminals imitate. A sender that looks like one of these but is not it is a lookalike even on the very first mail.
--    (Public, well known names only. The mailbox's own history is added on top of this list at check time.)
-- ===============================================================================================================================================
create table if not exists public.fmail_brand_domains183 (
  domain   text primary key check (domain = lower(domain) and length(domain) between 4 and 253 and domain ~ '^[a-z0-9-]+(\.[a-z0-9-]+)+$'),
  label    text generated always as (split_part(domain, '.', 1)) stored,
  added_at timestamptz not null default now()
);
insert into public.fmail_brand_domains183 (domain) values
  ('google.com'), ('gmail.com'), ('youtube.com'), ('microsoft.com'), ('outlook.com'), ('office.com'), ('live.com'), ('apple.com'), ('icloud.com'), ('amazon.com'),
  ('paypal.com'), ('stripe.com'), ('github.com'), ('gitlab.com'), ('namecheap.com'), ('hetzner.com'), ('linkedin.com'), ('facebook.com'), ('instagram.com'),
  ('whatsapp.com'), ('telegram.org'), ('dropbox.com'), ('docusign.com'), ('zoom.us'), ('slack.com'), ('netflix.com'), ('spotify.com'), ('ebay.com'), ('binance.com'),
  ('coinbase.com'), ('visa.com'), ('mastercard.com'), ('americanexpress.com'), ('wellsfargo.com'), ('chase.com'), ('bankofamerica.com'), ('hsbc.com'),
  ('dhl.com'), ('fedex.com'), ('ups.com'), ('usps.com'), ('irs.gov'), ('adobe.com'), ('yahoo.com'), ('proton.me'), ('protonmail.com'), ('anexomail.com')
on conflict (domain) do nothing;
alter table public.fmail_brand_domains183 enable row level security;
alter table public.fmail_brand_domains183 force row level security;
revoke all on public.fmail_brand_domains183 from public, anon, authenticated, service_role;
grant select on public.fmail_brand_domains183 to service_role;

-- ===============================================================================================================================================
-- 2) pure helpers (immutable, no table access)
-- ===============================================================================================================================================
-- 2a) the one hash formula of this chain (v1): every field length-prefixed (fmail_lp_167), NULL is told apart from an empty string
create or replace function public.fmail_h183(p text[]) returns text
language plpgsql immutable parallel safe set search_path = pg_catalog, public, extensions as $$
declare b bytea := ''::bytea; x text;
begin
  foreach x in array coalesce(p, array[]::text[]) loop
    b := b || public.fmail_lp_167(case when x is null then 'n' else 'v:' || x end);
  end loop;
  return encode(digest(public.fmail_lp_167('fmail-auth-v1') || b, 'sha256'), 'hex');
end $$;

-- 2b) bounded Damerau-Levenshtein (optimal string alignment): counts an insert, a delete, a change AND a swap of two neighbours as ONE step.
--     Stops as soon as the distance must exceed p_max and then answers p_max + 1 (so a comparison against 200 known domains stays cheap).
create or replace function public.fmail_edit_distance183(a text, b text, p_max int default 3) returns int
language plpgsql immutable parallel safe set search_path = pg_catalog as $$
declare la int; lb int; i int; j int; c int; v int; rmin int; pp int[]; pr int[]; cu int[];
begin
  if a is null or b is null then return null; end if;
  if p_max is null or p_max < 0 or p_max > 16 then raise exception 'E183: the bound must be 0..16' using errcode = '22023'; end if;
  if a = b then return 0; end if;
  la := length(a); lb := length(b);
  if abs(la - lb) > p_max then return p_max + 1; end if;
  pr := array(select generate_series(0, lb));
  pp := pr;
  for i in 1..la loop
    cu := array_fill(0, array[lb + 1]);
    cu[1] := i; rmin := i;
    for j in 1..lb loop
      c := case when substr(a, i, 1) = substr(b, j, 1) then 0 else 1 end;
      v := least(pr[j + 1] + 1, cu[j] + 1, pr[j] + c);
      if i > 1 and j > 1 and substr(a, i, 1) = substr(b, j - 1, 1) and substr(a, i - 1, 1) = substr(b, j, 1) then v := least(v, pp[j - 1] + 1); end if;
      cu[j + 1] := v;
      if v < rmin then rmin := v; end if;
    end loop;
    if rmin > p_max then return p_max + 1; end if;
    pp := pr; pr := cu;
  end loop;
  return least(pr[lb + 1], p_max + 1);
end $$;

-- 2c) the confusable SKELETON (the idea of Unicode UTS #39): two strings that LOOK the same have the same skeleton.
--     Cyrillic / Greek / Armenian letters that look Latin become that Latin letter, unicode hyphens become '-', digits that pass for letters (0 1 3 5) become letters,
--     and the sequences rn -> m, vv -> w, cl -> d (the classic typo-squat tricks) are folded. Lower case first. The two translate strings have the SAME length (the selftest checks it).
create or replace function public.fmail_skeleton183(p text) returns text
language sql immutable parallel safe set search_path = pg_catalog as $$
  select replace(replace(replace(
           translate(translate(lower(coalesce(p, '')),
             U&'\0430\0435\043e\0440\0441\0445\0443\0456\0458\0501\051b\0455\04bb\0261\03bf\03bd\03c1\03b1\03b9\03c5\03ba\0131\04cf\0578\0585\2010\2011\2012\2013\2014',
             'aeopcxyijdqshgovpaiukilno-----'),
             '0135', 'oles'),
           'rn', 'm'), 'vv', 'w'), 'cl', 'd')
$$;

-- 2d) a domain that mixes Latin letters with Cyrillic / Greek / Armenian ones (given in its UNICODE form, which the Rust verifier decodes from punycode)
create or replace function public.fmail_script_mix183(p text) returns boolean
language sql immutable parallel safe set search_path = pg_catalog as $$
  select p ~ '[a-z]' and p ~ '[Ͱ-ϿЀ-ԯԱ-֏]'
$$;

-- 2e) one reason line of the trust score
create or replace function public.fmail_reason183(p_code text, p_delta int, p_text text) returns jsonb
language sql immutable parallel safe set search_path = pg_catalog as $$
  select jsonb_build_object('code', p_code, 'delta', p_delta, 'text', p_text)
$$;

-- ===============================================================================================================================================
-- 3) THE TRUST SCORE (one function, one truth). Perfect mail = 100. Each rule adds what it earns; caps and hard fails come after.
--    55 DMARC pass (+5 when the domain asks for p=reject, +3 for quarantine) + 10 aligned DKIM + 5 aligned SPF + 3 DKIM pass + 3 SPF pass + 3 iprev + 8 TLS 1.3 post-quantum (5 plain 1.3, 2 for 1.2) + 8 known sender = 100.
--    Caps: no DMARC 60 (D), DMARC error 55, DMARC fail 40 (quarantine 25, reject 10 and grade F unless a valid ARC chain vouches for the forwarder), no TLS 75,
--    lookalike 55, display-name spoof 55, mixed script 55 (all three = grade D at best), opaque attachment 30, scanner error 50, infected 0 and F.   Grade: A+ >= 97, A >= 90, B >= 80, C >= 65, D >= 45, else F.
--    p_tls null = unknown (no reward, no cap). Every argument is a closed word from the CHECK lists of fmail_auth_evidence.
-- ===============================================================================================================================================
create or replace function public.fmail_trust_score183(
  p_spf text, p_dkim text, p_dmarc text, p_arc text, p_policy text, p_spf_aligned boolean, p_dkim_aligned boolean, p_iprev text, p_tls text,
  p_scan text, p_lookalike boolean, p_spoof boolean, p_mixed boolean, p_known boolean, p_prior int)
returns jsonb language plpgsql immutable parallel safe set search_path = pg_catalog, public as $$
declare
  s int := 0; cap int := 100; hard_f boolean := false; r jsonb := '[]'::jsonb; grade text;
begin
  -- identity: who vouches that this mail is from the domain it shows
  if p_dmarc = 'pass' then
    s := s + 55; r := r || public.fmail_reason183('dmarc_pass', 55, 'DMARC passed: the domain in From vouches for this mail');
    if p_policy = 'reject' then s := s + 5; r := r || public.fmail_reason183('policy_reject', 5, 'That domain tells receivers to reject forgeries (p=reject)');
    elsif p_policy = 'quarantine' then s := s + 3; r := r || public.fmail_reason183('policy_quarantine', 3, 'That domain tells receivers to quarantine forgeries (p=quarantine)'); end if;
    if coalesce(p_dkim_aligned, false) then s := s + 10; r := r || public.fmail_reason183('dkim_aligned', 10, 'A DKIM signature of the From domain itself checks out'); end if;
    if coalesce(p_spf_aligned, false) then s := s + 5; r := r || public.fmail_reason183('spf_aligned', 5, 'The sending server is allowed by the From domain (SPF aligned)'); end if;
  elsif p_dmarc = 'fail' then
    r := r || public.fmail_reason183('dmarc_fail', 0, 'DMARC failed: neither SPF nor DKIM proves the From domain');
    if p_arc = 'pass' then cap := least(cap, 60); r := r || public.fmail_reason183('arc_forwarded', 0, 'A valid ARC chain shows it was forwarded by a server that checked it first');
    elsif p_policy = 'reject' then cap := least(cap, 10); hard_f := true; r := r || public.fmail_reason183('forged', 0, 'The domain asks receivers to reject exactly this: probable forgery');
    elsif p_policy = 'quarantine' then cap := least(cap, 25);
    else cap := least(cap, 40); end if;
  elsif p_dmarc in ('temperror', 'permerror') then
    s := s + 10; cap := least(cap, 55); r := r || public.fmail_reason183('dmarc_error', 10, 'DMARC could not be decided (a DNS or record problem), so the From address is unproven');
  else
    cap := least(cap, 60); r := r || public.fmail_reason183('dmarc_none', 0, 'The sender publishes no DMARC policy, so the From address cannot be proven');
  end if;
  -- forwarded mail: a valid ARC chain is worth something when DMARC itself did not pass
  if p_dmarc is distinct from 'pass' and p_arc = 'pass' then s := s + 12; r := r || public.fmail_reason183('arc_pass', 12, 'ARC chain valid (forwarded mail)'); end if;
  if p_spf = 'pass' then s := s + 3; r := r || public.fmail_reason183('spf_pass', 3, 'SPF passed'); end if;
  if p_dkim = 'pass' then s := s + 3; r := r || public.fmail_reason183('dkim_pass', 3, 'DKIM passed'); end if;
  if p_iprev = 'pass' then s := s + 3; r := r || public.fmail_reason183('iprev_pass', 3, 'The sending server''s name and address agree both ways (reverse DNS)'); end if;
  -- the wire
  if p_tls = 'tls13_pq' then s := s + 8; r := r || public.fmail_reason183('tls_pq', 8, 'Arrived over TLS 1.3 with the post-quantum key exchange');
  elsif p_tls = 'tls13' then s := s + 5; r := r || public.fmail_reason183('tls13', 5, 'Arrived over TLS 1.3');
  elsif p_tls = 'tls12' then s := s + 2; r := r || public.fmail_reason183('tls12', 2, 'Arrived over TLS 1.2');
  elsif p_tls = 'none' then cap := least(cap, 75); r := r || public.fmail_reason183('tls_none', 0, 'The sender''s server did not use TLS: the mail crossed the internet readable'); end if;
  -- history
  if coalesce(p_known, false) then s := s + 8; r := r || public.fmail_reason183('known_sender', 8, 'You have had several mails from this sender that passed DMARC');
  elsif coalesce(p_prior, 0) = 0 then r := r || public.fmail_reason183('first_mail', 0, 'First mail from this sender'); end if;
  -- spoof signs
  if coalesce(p_lookalike, false) then cap := least(cap, 55); r := r || public.fmail_reason183('lookalike', 0, 'The sender''s domain looks like a domain you know or a famous one, but it is not'); end if;
  if coalesce(p_spoof, false) then cap := least(cap, 55); r := r || public.fmail_reason183('display_spoof', 0, 'The display name contains an address that is not the real sender'); end if;
  if coalesce(p_mixed, false) then cap := least(cap, 55); r := r || public.fmail_reason183('mixed_script', 0, 'The domain mixes alphabets (Latin with Cyrillic or Greek), a classic disguise'); end if;
  -- content safety
  if p_scan = 'infected' then cap := 0; hard_f := true; r := r || public.fmail_reason183('infected', 0, 'The virus scanner found malware');
  elsif p_scan = 'opaque' then cap := least(cap, 30); r := r || public.fmail_reason183('opaque', 0, 'An attachment hides its content (encrypted), so it could not be scanned');
  elsif p_scan = 'error' then cap := least(cap, 50); r := r || public.fmail_reason183('scan_error', 0, 'The virus scanner could not finish'); end if;
  s := greatest(0, least(s, cap));
  grade := case when hard_f then 'F' when s >= 97 then 'A+' when s >= 90 then 'A' when s >= 80 then 'B' when s >= 65 then 'C' when s >= 45 then 'D' else 'F' end;
  return jsonb_build_object('score', s, 'grade', grade, 'reasons', r);
end $$;

-- ===============================================================================================================================================
-- 4) THE EVIDENCE: one row per inbound mail + one row per DKIM signature. Closed lists everywhere ('none' = not checked, never a guessed pass), append-only, a per-mailbox hash chain.
-- ===============================================================================================================================================
create table if not exists public.fmail_auth_evidence (
  id                 uuid primary key default gen_random_uuid(),
  mailbox_id         uuid not null references public.fmail_mailboxes (id) on delete restrict,
  message_id         uuid not null,                           -- no foreign key on purpose: a hard-deleted mail must not delete (or block) its evidence; record183 checks the mail exists
  seq                bigint not null check (seq >= 1),
  recorded_ms        bigint not null check (recorded_ms > 1700000000000),
  -- who connected (read from the top Received header our own Postfix wrote; null = could not be read, and then SPF says 'none')
  client_ip          inet,
  helo               text check (helo is null or (length(helo) between 1 and 255 and helo !~ '[[:cntrl:][:space:]]')),
  rdns               text check (rdns is null or (length(rdns) between 1 and 255 and rdns !~ '[[:cntrl:][:space:]]')),
  mail_from_domain   text check (mail_from_domain is null or (mail_from_domain = lower(mail_from_domain) and length(mail_from_domain) <= 253 and mail_from_domain ~ '^[a-z0-9._-]+$')),
  header_from_domain text not null check (header_from_domain = lower(header_from_domain) and length(header_from_domain) between 1 and 253 and header_from_domain ~ '^[a-z0-9._-]+$'),
  from_unicode       text check (from_unicode is null or (length(from_unicode) between 1 and 253 and from_unicode !~ '[[:cntrl:][:space:]]')),
  org_domain         text check (org_domain is null or (org_domain = lower(org_domain) and length(org_domain) <= 253 and org_domain ~ '^[a-z0-9._-]+$')),
  -- the verdicts
  spf_result         text not null default 'none' check (spf_result in ('none', 'pass', 'fail', 'softfail', 'neutral', 'temperror', 'permerror')),
  spf_domain         text check (spf_domain is null or (spf_domain = lower(spf_domain) and length(spf_domain) <= 253 and spf_domain ~ '^[a-z0-9._-]+$')),
  dkim_result        text not null default 'none' check (dkim_result in ('none', 'pass', 'fail', 'neutral', 'temperror', 'permerror')),
  dkim_sigs          smallint not null default 0 check (dkim_sigs between 0 and 16),
  dmarc_result       text not null default 'none' check (dmarc_result in ('none', 'pass', 'fail', 'temperror', 'permerror')),
  dmarc_policy       text check (dmarc_policy is null or dmarc_policy in ('none', 'quarantine', 'reject')),
  dmarc_disposition  text check (dmarc_disposition is null or dmarc_disposition in ('none', 'quarantine', 'reject')),
  dmarc_spf_aligned  boolean not null default false,
  dmarc_dkim_aligned boolean not null default false,
  dmarc_walk         smallint check (dmarc_walk is null or dmarc_walk between 0 and 8),   -- RFC 9989 tree walk: at most 8 DNS queries
  dmarc_record_domain text check (dmarc_record_domain is null or (dmarc_record_domain = lower(dmarc_record_domain) and length(dmarc_record_domain) <= 253 and dmarc_record_domain ~ '^[a-z0-9._-]+$')),
  arc_result         text not null default 'none' check (arc_result in ('none', 'pass', 'fail')),
  arc_instances      smallint not null default 0 check (arc_instances between 0 and 50),
  iprev_result       text not null default 'none' check (iprev_result in ('none', 'pass', 'fail', 'temperror', 'permerror')),
  -- the wire
  tls_class          text check (tls_class is null or tls_class in ('none', 'tls12', 'tls13', 'tls13_pq')),
  tls_version        text check (tls_version is null or (length(tls_version) <= 24 and tls_version !~ '[[:cntrl:]]')),
  tls_cipher         text check (tls_cipher is null or (length(tls_cipher) <= 64 and tls_cipher !~ '[[:cntrl:]]')),
  tls_group          text check (tls_group is null or (length(tls_group) <= 48 and tls_group !~ '[[:cntrl:]]')),
  -- spoof signs and history
  display_spoof      boolean not null default false,
  mixed_script       boolean not null default false,
  lookalike_kind     text check (lookalike_kind is null or lookalike_kind in ('homoglyph', 'hyphen', 'typo', 'tld_swap', 'brand_combo', 'mixed_script')),
  lookalike_of       text check (lookalike_of is null or (length(lookalike_of) <= 253 and lookalike_of ~ '^[a-z0-9._-]+$')),
  sender_known       boolean not null default false,
  sender_prior       int not null default 0 check (sender_prior >= 0),
  scan_cap           text not null check (scan_cap in ('pending', 'clean', 'infected', 'error', 'skipped', 'opaque')),
  -- the answer
  score              smallint not null check (score between 0 and 100),
  grade              text not null check (grade in ('A+', 'A', 'B', 'C', 'D', 'F')),
  reasons            jsonb not null check (jsonb_typeof(reasons) = 'array' and jsonb_array_length(reasons) <= 24),
  authres            text check (authres is null or (length(authres) <= 2000 and authres !~ '[[:cntrl:]]')),   -- our own RFC 8601 Authentication-Results line, one line
  sigs_digest        text not null check (sigs_digest ~ '^[0-9a-f]{64}$'),
  prev_hash          text not null check (prev_hash ~ '^[0-9a-f]{64}$'),
  row_hash           text not null check (row_hash ~ '^[0-9a-f]{64}$'),
  constraint fmail_auth_evidence_seq_uq unique (mailbox_id, seq),
  constraint fmail_auth_evidence_msg_uq unique (message_id),
  constraint fmail_auth_dmarc_aligned_ck check (dmarc_result <> 'pass' or dmarc_spf_aligned or dmarc_dkim_aligned),                -- DMARC pass without any aligned pass is not a pass
  constraint fmail_auth_dmarc_policy_ck check (dmarc_result <> 'none' or (dmarc_policy is null and dmarc_disposition is null)),     -- no record, no policy
  constraint fmail_auth_spf_domain_ck check (spf_result = 'none' or spf_domain is not null),
  constraint fmail_auth_dkim_sigs_ck check (dkim_result <> 'pass' or dkim_sigs >= 1),
  constraint fmail_auth_lookalike_ck check ((lookalike_kind is null and lookalike_of is null) or lookalike_kind = 'mixed_script' or (lookalike_kind is not null and lookalike_of is not null)),
  constraint fmail_auth_infected_ck check (scan_cap <> 'infected' or (score = 0 and grade = 'F'))
);
create index if not exists fmail_auth_evidence_org_ix on public.fmail_auth_evidence (mailbox_id, org_domain, recorded_ms desc);
create index if not exists fmail_auth_evidence_grade_ix on public.fmail_auth_evidence (mailbox_id, grade, recorded_ms desc);

create table if not exists public.fmail_auth_sig (
  id              bigint generated always as identity primary key,
  evidence_id     uuid not null references public.fmail_auth_evidence (id) on delete restrict,
  idx             smallint not null check (idx between 1 and 16),
  domain          text not null check (domain = lower(domain) and length(domain) between 1 and 253 and domain ~ '^[a-z0-9._-]+$'),
  selector        text not null check (selector ~ '^[a-z0-9._-]{1,63}$'),
  algo            text not null check (algo in ('rsa-sha256', 'rsa-sha1', 'ed25519-sha256')),
  result          text not null check (result in ('none', 'pass', 'fail', 'neutral', 'temperror', 'permerror')),
  aligned_relaxed boolean not null default false,
  aligned_strict  boolean not null default false,
  key_bits        int check (key_bits is null or key_bits between 256 and 16384),
  sig_age_s       int check (sig_age_s is null or sig_age_s between -31536000 and 315360000),
  expired         boolean not null default false,
  body_limited    boolean not null default false,                    -- the l= tag: only the first N bytes are signed, a known abuse
  constraint fmail_auth_sig_idx_uq unique (evidence_id, idx),
  constraint fmail_auth_sig_aligned_ck check (not aligned_strict or aligned_relaxed)
);

-- the hash of ONE signature row (the writer and the verifier both call this, so they cannot drift)
create or replace function public.fmail_sig_hash183(p_idx int, p_domain text, p_selector text, p_algo text, p_result text, p_rel boolean, p_strict boolean, p_bits int, p_age int, p_exp boolean, p_body boolean)
returns text language sql immutable parallel safe set search_path = pg_catalog, public, extensions as $$
  select public.fmail_h183(array[p_idx::text, p_domain, p_selector, p_algo, p_result, p_rel::text, p_strict::text, p_bits::text, p_age::text, p_exp::text, p_body::text])
$$;

-- the hash of ONE evidence row: everything that makes the verdict, plus the link to the row before (prev_hash). row_hash itself is not part of it.
create or replace function public.fmail_auth_row_hash183(e public.fmail_auth_evidence) returns text
language sql immutable parallel safe set search_path = pg_catalog, public, extensions as $$
  select public.fmail_h183(array[e.prev_hash, e.mailbox_id::text, e.seq::text, e.message_id::text, e.recorded_ms::text, host(e.client_ip), e.helo, e.rdns, e.mail_from_domain, e.header_from_domain,
    e.from_unicode, e.org_domain, e.spf_result, e.spf_domain, e.dkim_result, e.dkim_sigs::text, e.dmarc_result, e.dmarc_policy, e.dmarc_disposition, e.dmarc_spf_aligned::text,
    e.dmarc_dkim_aligned::text, e.dmarc_walk::text, e.dmarc_record_domain, e.arc_result, e.arc_instances::text, e.iprev_result, e.tls_class, e.tls_version, e.tls_cipher, e.tls_group,
    e.display_spoof::text, e.mixed_script::text, e.lookalike_kind, e.lookalike_of, e.sender_known::text, e.sender_prior::text, e.scan_cap, e.score::text, e.grade, e.reasons::text,
    e.authres, e.sigs_digest])
$$;

-- append-only: no UPDATE, DELETE or TRUNCATE for anybody (not even service_role); the one function that may add rows is fmail_auth_record183
create or replace function public.fmail_auth_immutable183() returns trigger language plpgsql set search_path = pg_catalog as $$
begin raise exception 'E183: % is append-only (% refused)', tg_table_name, tg_op using errcode = '42501'; end $$;
do $$
declare t text;
begin
  foreach t in array array['fmail_auth_evidence', 'fmail_auth_sig'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    execute format('grant select, insert on public.%I to service_role', t);
    execute format('drop trigger if exists %I on public.%I', t || '_row_imm', t);
    execute format('create trigger %I before update or delete on public.%I for each row execute function public.fmail_auth_immutable183()', t || '_row_imm', t);
    execute format('drop trigger if exists %I on public.%I', t || '_trunc_imm', t);
    execute format('create trigger %I before truncate on public.%I for each statement execute function public.fmail_auth_immutable183()', t || '_trunc_imm', t);
  end loop;
end $$;

-- ===============================================================================================================================================
-- 5) WHAT THIS MAILBOX ALREADY KNOWS: sender history and the lookalike check (read only)
-- ===============================================================================================================================================
create or replace function public.fmail_sender_history183(p_mailbox uuid, p_org text) returns jsonb
language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object('prior', t.n, 'passed', t.p, 'known', (t.p >= 3 and t.p * 5 >= t.n * 4), 'first_ms', t.f, 'last_ms', t.l)
    from (select count(*)::int as n, count(*) filter (where dmarc_result = 'pass')::int as p, min(recorded_ms) as f, max(recorded_ms) as l
            from public.fmail_auth_evidence where mailbox_id = p_mailbox and org_domain = lower(p_org)) t
$$;

-- A sender is a LOOKALIKE when its organisational domain imitates a domain this mailbox already trusts (2 or more mails that passed DMARC) or a famous brand, in one of five ways, strongest first:
--   homoglyph (same skeleton: paypa1.com, a Cyrillic а), hyphen (pay-pal.com), typo (one edit or swap: gooogle.com, goolge.com), tld_swap (same name, other ending: paypal.co), brand_combo (paypal-secure.com).
-- A domain that mixes alphabets is a lookalike by itself ('mixed_script'). A domain this mailbox already trusts (3+ passes) or that IS a listed brand is never a lookalike of another.
create or replace function public.fmail_lookalike183(p_mailbox uuid, p_org text, p_unicode text default null) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare
  v_o text := lower(coalesce(p_org, '')); v_u text; k record; v_rank int := 99; v_kind text; v_of text; rk int; v_lab text; v_klab text; v_su text; v_ds text;
begin
  if v_o = '' then return jsonb_build_object('lookalike', false); end if;
  v_u := lower(coalesce(nullif(p_unicode, ''), v_o));
  if exists (select 1 from public.fmail_brand_domains183 b where b.domain = v_o) then return jsonb_build_object('lookalike', false, 'self', 'brand'); end if;
  if (select count(*) from public.fmail_auth_evidence e where e.mailbox_id = p_mailbox and e.org_domain = v_o and e.dmarc_result = 'pass') >= 3 then return jsonb_build_object('lookalike', false, 'self', 'trusted'); end if;
  if public.fmail_script_mix183(v_u) then return jsonb_build_object('lookalike', true, 'kind', 'mixed_script', 'of', null); end if;
  v_su := public.fmail_skeleton183(v_u); v_ds := replace(v_su, '-', ''); v_lab := split_part(v_o, '.', 1);
  for k in
    select c.dom from (
      select b.domain as dom from public.fmail_brand_domains183 b
      union
      select e.org_domain from public.fmail_auth_evidence e where e.mailbox_id = p_mailbox and e.dmarc_result = 'pass' and e.org_domain is not null group by e.org_domain having count(*) >= 2
    ) c where c.dom <> v_o order by c.dom limit 400
  loop
    rk := 99;
    v_klab := split_part(k.dom, '.', 1);
    if v_u <> k.dom and v_su = public.fmail_skeleton183(k.dom) then rk := 1;
    elsif v_ds = replace(public.fmail_skeleton183(k.dom), '-', '') then rk := 2;
    elsif length(v_o) >= 7 and public.fmail_edit_distance183(v_o, k.dom, 1) = 1 then rk := 3;
    elsif length(v_klab) >= 5 and v_lab = v_klab then rk := 4;
    elsif length(v_klab) >= 5 and (v_lab like v_klab || '-%' or v_lab like '%-' || v_klab) then rk := 5; end if;
    if rk < v_rank then v_rank := rk; v_of := k.dom; v_kind := case rk when 1 then 'homoglyph' when 2 then 'hyphen' when 3 then 'typo' when 4 then 'tld_swap' else 'brand_combo' end; end if;
    exit when v_rank = 1;
  end loop;
  if v_rank < 99 then return jsonb_build_object('lookalike', true, 'kind', v_kind, 'of', v_of); end if;
  return jsonb_build_object('lookalike', false);
end $$;

-- ===============================================================================================================================================
-- 6) THE ONE WRITER: fmail_auth_record183 (called by the Rust intake after the scan, once per stored mail; a second call for the same mail answers the first)
-- ===============================================================================================================================================
create or replace function public.fmail_auth_record183(p_mailbox uuid, p_message uuid, p_ev jsonb, p_sigs jsonb default '[]'::jsonb) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  m public.fmail_messages%rowtype; ex public.fmail_auth_evidence%rowtype; v_row public.fmail_auth_evidence; v_seq bigint; v_prev text; v_id uuid := gen_random_uuid();
  v_from text; v_org text; v_uni text; v_look jsonb; v_hist jsonb; v_known boolean; v_mixed boolean; v_spoof boolean; v_score jsonb; v_kind text; v_of text;
  s jsonb; v_i int := 0; v_dig text[] := array[]::text[]; v_digest text; v_n int; v_dm text; v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  q_idx int; q_dom text; q_sel text; q_alg text; q_res text; q_rel boolean; q_str boolean; q_bits int; q_age int; q_exp boolean; q_body boolean;
begin
  if p_ev is null or jsonb_typeof(p_ev) <> 'object' then raise exception 'E183: the evidence must be a json object' using errcode = '22023'; end if;
  if p_sigs is null or jsonb_typeof(p_sigs) <> 'array' or jsonb_array_length(p_sigs) > 16 then raise exception 'E183: signatures must be an array of at most 16' using errcode = '22023'; end if;
  perform 1 from public.fmail_mailboxes where id = p_mailbox for update;                      -- serialises the chain of this mailbox
  if not found then raise exception 'E183: unknown mailbox' using errcode = '23503'; end if;
  select * into m from public.fmail_messages where id = p_message and mailbox_id = p_mailbox;
  if not found then raise exception 'E183: unknown message' using errcode = '23503'; end if;
  if m.direction <> 'in' then raise exception 'E183: only inbound mail has a verdict (outgoing mail has fmail_out_facts183)' using errcode = '22023'; end if;
  select * into ex from public.fmail_auth_evidence where message_id = p_message;
  if found then return jsonb_build_object('recorded', false, 'duplicate', true, 'seq', ex.seq, 'score', ex.score, 'grade', ex.grade); end if;
  v_from := lower(nullif(p_ev ->> 'header_from_domain', ''));
  if v_from is null then raise exception 'E183: header_from_domain is required' using errcode = '22023'; end if;
  v_org := lower(coalesce(nullif(p_ev ->> 'org_domain', ''), v_from));
  v_uni := nullif(p_ev ->> 'from_unicode', '');
  v_hist := public.fmail_sender_history183(p_mailbox, v_org);
  v_look := public.fmail_lookalike183(p_mailbox, v_org, v_uni);
  v_kind := v_look ->> 'kind'; v_of := v_look ->> 'of';
  v_mixed := coalesce((p_ev ->> 'mixed_script')::boolean, false) or coalesce(v_kind = 'mixed_script', false);
  v_spoof := coalesce((p_ev ->> 'display_spoof')::boolean, false);
  if v_mixed and v_kind is null then v_kind := 'mixed_script'; end if;
  v_known := coalesce((v_hist ->> 'known')::boolean, false);
  v_score := public.fmail_trust_score183(coalesce(p_ev ->> 'spf_result', 'none'), coalesce(p_ev ->> 'dkim_result', 'none'), coalesce(p_ev ->> 'dmarc_result', 'none'), coalesce(p_ev ->> 'arc_result', 'none'),
    p_ev ->> 'dmarc_policy', coalesce((p_ev ->> 'dmarc_spf_aligned')::boolean, false), coalesce((p_ev ->> 'dmarc_dkim_aligned')::boolean, false), coalesce(p_ev ->> 'iprev_result', 'none'),
    nullif(p_ev ->> 'tls_class', ''), m.scan_state, v_kind is not null, v_spoof, v_mixed, v_known, coalesce((v_hist ->> 'prior')::int, 0));
  -- the signature rows (typed once here; the digest is over the typed values, exactly what the verifier recomputes)
  for s in select * from jsonb_array_elements(p_sigs) loop
    v_i := v_i + 1;
    q_idx := v_i; q_dom := lower(s ->> 'domain'); q_sel := lower(s ->> 'selector'); q_alg := s ->> 'algo'; q_res := coalesce(s ->> 'result', 'none');
    q_rel := coalesce((s ->> 'aligned_relaxed')::boolean, false); q_str := coalesce((s ->> 'aligned_strict')::boolean, false);
    q_bits := (s ->> 'key_bits')::int; q_age := (s ->> 'sig_age_s')::int; q_exp := coalesce((s ->> 'expired')::boolean, false); q_body := coalesce((s ->> 'body_limited')::boolean, false);
    v_dig := v_dig || public.fmail_sig_hash183(q_idx, q_dom, q_sel, q_alg, q_res, q_rel, q_str, q_bits, q_age, q_exp, q_body);
  end loop;
  v_digest := public.fmail_h183(v_dig);
  select seq, row_hash into v_seq, v_prev from public.fmail_auth_evidence where mailbox_id = p_mailbox order by seq desc limit 1;
  v_seq := coalesce(v_seq, 0) + 1; v_prev := coalesce(v_prev, repeat('0', 64));
  v_row := jsonb_populate_record(null::public.fmail_auth_evidence,
    jsonb_build_object('id', v_id, 'mailbox_id', p_mailbox, 'message_id', p_message, 'seq', v_seq, 'recorded_ms', v_now, 'client_ip', nullif(p_ev ->> 'client_ip', ''), 'helo', nullif(p_ev ->> 'helo', ''),
      'rdns', nullif(p_ev ->> 'rdns', ''), 'mail_from_domain', lower(nullif(p_ev ->> 'mail_from_domain', '')), 'header_from_domain', v_from, 'from_unicode', v_uni, 'org_domain', v_org,
      'spf_result', coalesce(p_ev ->> 'spf_result', 'none'), 'spf_domain', lower(nullif(p_ev ->> 'spf_domain', '')), 'dkim_result', coalesce(p_ev ->> 'dkim_result', 'none'), 'dkim_sigs', v_i,
      'dmarc_result', coalesce(p_ev ->> 'dmarc_result', 'none'), 'dmarc_policy', nullif(p_ev ->> 'dmarc_policy', ''), 'dmarc_disposition', nullif(p_ev ->> 'dmarc_disposition', ''),
      'dmarc_spf_aligned', coalesce((p_ev ->> 'dmarc_spf_aligned')::boolean, false), 'dmarc_dkim_aligned', coalesce((p_ev ->> 'dmarc_dkim_aligned')::boolean, false))
    || jsonb_build_object('dmarc_walk', (p_ev ->> 'dmarc_walk')::int, 'dmarc_record_domain', lower(nullif(p_ev ->> 'dmarc_record_domain', '')), 'arc_result', coalesce(p_ev ->> 'arc_result', 'none'),
      'arc_instances', coalesce((p_ev ->> 'arc_instances')::int, 0), 'iprev_result', coalesce(p_ev ->> 'iprev_result', 'none'), 'tls_class', nullif(p_ev ->> 'tls_class', ''),
      'tls_version', nullif(p_ev ->> 'tls_version', ''), 'tls_cipher', nullif(p_ev ->> 'tls_cipher', ''), 'tls_group', nullif(p_ev ->> 'tls_group', ''), 'display_spoof', v_spoof, 'mixed_script', v_mixed,
      'lookalike_kind', v_kind, 'lookalike_of', v_of, 'sender_known', v_known, 'sender_prior', coalesce((v_hist ->> 'prior')::int, 0), 'scan_cap', m.scan_state,
      'score', (v_score ->> 'score')::int, 'grade', v_score ->> 'grade', 'reasons', v_score -> 'reasons', 'authres', nullif(p_ev ->> 'authres', ''), 'sigs_digest', v_digest, 'prev_hash', v_prev));
  v_row.row_hash := public.fmail_auth_row_hash183(v_row);                                          -- row_hash is empty here and is not part of its own hash
  insert into public.fmail_auth_evidence values (v_row.*);
  v_i := 0;
  for s in select * from jsonb_array_elements(p_sigs) loop
    v_i := v_i + 1;
    insert into public.fmail_auth_sig (evidence_id, idx, domain, selector, algo, result, aligned_relaxed, aligned_strict, key_bits, sig_age_s, expired, body_limited)
    values (v_id, v_i, lower(s ->> 'domain'), lower(s ->> 'selector'), s ->> 'algo', coalesce(s ->> 'result', 'none'), coalesce((s ->> 'aligned_relaxed')::boolean, false),
            coalesce((s ->> 'aligned_strict')::boolean, false), (s ->> 'key_bits')::int, (s ->> 'sig_age_s')::int, coalesce((s ->> 'expired')::boolean, false), coalesce((s ->> 'body_limited')::boolean, false));
  end loop;
  update public.fmail_messages set spf = v_row.spf_result, dkim = v_row.dkim_result, dmarc = v_row.dmarc_result, arc = v_row.arc_result, lookalike = (v_kind is not null),
         tls_in = coalesce(v_row.tls_class, tls_in), trust_score = v_row.score, trust_grade = v_row.grade
   where id = p_message;
  return jsonb_build_object('recorded', true, 'duplicate', false, 'evidence_id', v_id, 'seq', v_seq, 'score', v_row.score, 'grade', v_row.grade, 'reasons', v_row.reasons,
    'lookalike', v_kind is not null, 'lookalike_kind', v_kind, 'lookalike_of', v_of, 'sender_known', v_known);
end $$;

-- ===============================================================================================================================================
-- 7) READ DOORS (stable, no writing): one mail's evidence, the mailbox summary, the chain check, the facts of an OUTGOING mail
-- ===============================================================================================================================================
create or replace function public.fmail_auth_get183(p_mailbox uuid, p_message uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare e public.fmail_auth_evidence; v_prev text; v_sigs jsonb; v_ok boolean;
begin
  select * into e from public.fmail_auth_evidence where mailbox_id = p_mailbox and message_id = p_message;
  if not found then return jsonb_build_object('found', false); end if;
  select row_hash into v_prev from public.fmail_auth_evidence where mailbox_id = p_mailbox and seq = e.seq - 1;
  v_ok := e.row_hash = public.fmail_auth_row_hash183(e) and e.prev_hash = coalesce(v_prev, repeat('0', 64));
  select coalesce(jsonb_agg(jsonb_build_object('idx', s.idx, 'domain', s.domain, 'selector', s.selector, 'algo', s.algo, 'result', s.result, 'aligned', s.aligned_relaxed, 'strict', s.aligned_strict,
           'key_bits', s.key_bits, 'age_s', s.sig_age_s, 'expired', s.expired, 'body_limited', s.body_limited) order by s.idx), '[]'::jsonb) into v_sigs
    from public.fmail_auth_sig s where s.evidence_id = e.id;
  return jsonb_build_object('found', true, 'seq', e.seq, 'recorded_ms', e.recorded_ms, 'score', e.score, 'grade', e.grade, 'reasons', e.reasons, 'chain_ok', v_ok, 'row_hash', e.row_hash, 'prev_hash', e.prev_hash,
    'from', jsonb_build_object('domain', e.header_from_domain, 'unicode', e.from_unicode, 'org', e.org_domain, 'mail_from', e.mail_from_domain),
    'client', jsonb_build_object('ip', host(e.client_ip), 'helo', e.helo, 'rdns', e.rdns),
    'spf', jsonb_build_object('result', e.spf_result, 'domain', e.spf_domain),
    'dkim', jsonb_build_object('result', e.dkim_result, 'count', e.dkim_sigs, 'sigs', v_sigs),
    'dmarc', jsonb_build_object('result', e.dmarc_result, 'policy', e.dmarc_policy, 'disposition', e.dmarc_disposition, 'spf_aligned', e.dmarc_spf_aligned, 'dkim_aligned', e.dmarc_dkim_aligned, 'walk', e.dmarc_walk, 'record_domain', e.dmarc_record_domain),
    'arc', jsonb_build_object('result', e.arc_result, 'instances', e.arc_instances), 'iprev', e.iprev_result,
    'tls', jsonb_build_object('class', e.tls_class, 'version', e.tls_version, 'cipher', e.tls_cipher, 'group', e.tls_group),
    'spoof', jsonb_build_object('display', e.display_spoof, 'mixed_script', e.mixed_script, 'lookalike_kind', e.lookalike_kind, 'lookalike_of', e.lookalike_of),
    'history', jsonb_build_object('known', e.sender_known, 'prior', e.sender_prior), 'scan', e.scan_cap, 'authres', e.authres);
end $$;

create or replace function public.fmail_auth_summary183(p_mailbox uuid, p_days int default 30) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_from bigint := (extract(epoch from now()) * 1000)::bigint - least(greatest(coalesce(p_days, 30), 1), 365) * 86400000::bigint; r jsonb; h record;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox) then raise exception 'E183: unknown mailbox' using errcode = '42704'; end if;
  select jsonb_build_object(
    'days', least(greatest(coalesce(p_days, 30), 1), 365), 'total', count(*), 'avg_score', coalesce(round(avg(score), 1), 0),
    'grades', jsonb_build_object('A+', count(*) filter (where grade = 'A+'), 'A', count(*) filter (where grade = 'A'), 'B', count(*) filter (where grade = 'B'), 'C', count(*) filter (where grade = 'C'),
                                 'D', count(*) filter (where grade = 'D'), 'F', count(*) filter (where grade = 'F')),
    'dmarc', jsonb_build_object('pass', count(*) filter (where dmarc_result = 'pass'), 'fail', count(*) filter (where dmarc_result = 'fail'), 'none', count(*) filter (where dmarc_result = 'none'),
                                'error', count(*) filter (where dmarc_result in ('temperror', 'permerror'))),
    'spf_pass', count(*) filter (where spf_result = 'pass'), 'dkim_pass', count(*) filter (where dkim_result = 'pass'), 'arc_pass', count(*) filter (where arc_result = 'pass'),
    'tls', jsonb_build_object('pq', count(*) filter (where tls_class = 'tls13_pq'), 'tls13', count(*) filter (where tls_class = 'tls13'), 'tls12', count(*) filter (where tls_class = 'tls12'),
                              'none', count(*) filter (where tls_class = 'none'), 'unknown', count(*) filter (where tls_class is null)),
    'lookalike', count(*) filter (where lookalike_kind is not null), 'display_spoof', count(*) filter (where display_spoof)) into r
    from public.fmail_auth_evidence where mailbox_id = p_mailbox and recorded_ms >= v_from;
  select seq, row_hash into h from public.fmail_auth_evidence where mailbox_id = p_mailbox order by seq desc limit 1;
  return r || jsonb_build_object('head_seq', coalesce(h.seq, 0), 'head_hash', h.row_hash,
    'recent_bad', coalesce((select jsonb_agg(x order by (x ->> 'ms')::bigint desc) from (
        select jsonb_build_object('message', e.message_id, 'domain', e.header_from_domain, 'grade', e.grade, 'score', e.score, 'kind', e.lookalike_kind, 'dmarc', e.dmarc_result, 'ms', e.recorded_ms) as x
          from public.fmail_auth_evidence e where e.mailbox_id = p_mailbox and e.grade in ('D', 'F') order by e.recorded_ms desc limit 5) b), '[]'::jsonb));
end $$;

-- the chain of one mailbox (or all): every row's hash recomputed, every link to the row before, every signature digest. Used by the Systems page "Check evidence chains".
create or replace function public.fmail_auth_chain_verify183(p_mailbox uuid default null) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare e public.fmail_auth_evidence; v_n int := 0; v_bad int := 0; v_sig_bad int := 0; v_prev text; v_pm uuid := null; v_dig text; v_actual text;
begin
  for e in select * from public.fmail_auth_evidence where p_mailbox is null or mailbox_id = p_mailbox order by mailbox_id, seq loop
    v_n := v_n + 1;
    if v_pm is distinct from e.mailbox_id then v_pm := e.mailbox_id; v_prev := repeat('0', 64); end if;
    if e.row_hash is distinct from public.fmail_auth_row_hash183(e) or e.prev_hash is distinct from v_prev or (e.seq = 1 and e.prev_hash <> repeat('0', 64)) then v_bad := v_bad + 1; end if;
    select public.fmail_h183(coalesce(array_agg(public.fmail_sig_hash183(s.idx, s.domain, s.selector, s.algo, s.result, s.aligned_relaxed, s.aligned_strict, s.key_bits, s.sig_age_s, s.expired, s.body_limited) order by s.idx), array[]::text[]))
      into v_actual from public.fmail_auth_sig s where s.evidence_id = e.id;
    if v_actual is distinct from e.sigs_digest then v_sig_bad := v_sig_bad + 1; end if;
    v_prev := e.row_hash;
  end loop;
  return jsonb_build_object('checked', v_n, 'broken', v_bad, 'sigs_broken', v_sig_bad);
end $$;

-- FACTS OF AN OUTGOING MAIL (gap G3 of AUDIT-Q1d): outgoing mail has no receive-side verdicts. It has these: when it was queued, when the hold ended, when the receiver said 250 (sent_ms),
-- over which TLS it travelled, whether and how it was DKIM signed (selector, algorithm, over-signed), how many tries it took. Everything is read from rows that already exist.
create or replace function public.fmail_out_facts183(p_mailbox uuid, p_message uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare m public.fmail_messages%rowtype; o public.fmail_outbox%rowtype; v_sigs jsonb;
begin
  select * into m from public.fmail_messages where id = p_message and mailbox_id = p_mailbox;
  if not found then return jsonb_build_object('found', false); end if;
  if m.direction <> 'out' then return jsonb_build_object('found', true, 'direction', m.direction); end if;
  select * into o from public.fmail_outbox where message_id = p_message order by created_at desc limit 1;
  if o.id is null then return jsonb_build_object('found', true, 'direction', 'out', 'state', 'draft'); end if;
  select coalesce(jsonb_agg(jsonb_build_object('selector', s.selector, 'alg', s.alg, 'oversigned', s.oversigned, 'headers', s.h_count, 't', s.t_unix, 'x', s.x_unix) order by s.seq), '[]'::jsonb) into v_sigs
    from public.fmail_dkim_sign_log s where s.outbox_id = o.id;
  return jsonb_build_object('found', true, 'direction', 'out', 'state', o.state, 'queued_ms', (extract(epoch from o.created_at) * 1000)::bigint, 'hold_until_ms', (extract(epoch from o.undo_until) * 1000)::bigint,
    'sent_ms', case when o.state = 'sent' and o.finished_at is not null then (extract(epoch from o.finished_at) * 1000)::bigint else null end,
    'finished_ms', case when o.finished_at is null then null else (extract(epoch from o.finished_at) * 1000)::bigint end,
    'accepted', o.state = 'sent' and coalesce(o.smtp_reply, '') ~ '^2[0-9][0-9]', 'reply', o.smtp_reply, 'tls', o.tls_out, 'dkim_signed', o.dkim_signed, 'signatures', v_sigs,
    'attempts', o.attempts, 'rcpt_count', o.rcpt_count, 'last_error', o.last_error);
end $$;

-- ===============================================================================================================================================
-- 8) fmail_get169 and fmail_list169 re-created WHOLE (their text was taken from the live definition, nothing else changed) with three new keys per mail: sent_ms (the time the receiver
--    said 250; null until then, so the screen no longer shows the compose time as the Sent time), score and grade (the trust score). Privileges of a replaced function are kept.
-- ===============================================================================================================================================
CREATE OR REPLACE FUNCTION public.fmail_get169(p_mailbox uuid, p_message uuid, p_touch_hash text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'extensions'
AS $function$
declare m public.fmail_messages%rowtype; v_kind text; v_vault boolean; v_gated boolean; v_owner uuid; v_led jsonb;
begin
  select * into m from public.fmail_messages where id = p_message and mailbox_id = p_mailbox;
  if not found then return jsonb_build_object('found', false); end if;
  select f.kind into v_kind from public.fmail_folders f where f.id = m.folder_id;
  select t.vault into v_vault from public.fmail_threads t where t.id = m.thread_id;
  v_gated := coalesce(v_vault, false) or v_kind = 'quarantine';
  if v_gated and (p_touch_hash is null or p_touch_hash !~ '^[0-9a-f]{64}$') then
    return jsonb_build_object('found', true, 'gated', true, 'needs_touch', true, 'id', m.id, 'folder', v_kind, 'vault', coalesce(v_vault, false));
  end if;
  if v_gated then
    select owner into v_owner from public.fmail_mailboxes where id = p_mailbox;
    v_led := public.fmail_ledger_append(v_owner, p_mailbox, 'unseal_gated', m.id::text, 'confidential mail opened (passkey touched)', jsonb_build_object('touch', p_touch_hash, 'folder', v_kind, 'vault', coalesce(v_vault, false)), false);
  end if;
  return jsonb_build_object('found', true, 'gated', v_gated, 'needs_touch', false, 'id', m.id, 'thread_id', m.thread_id, 'folder', v_kind, 'vault', coalesce(v_vault, false), 'direction', m.direction,
    'received_ms', (extract(epoch from m.received_at) * 1000)::bigint, 'size', m.size_bytes, 'attach', m.attach_count, 'read', m.is_read, 'starred', m.is_starred,
    'spf', m.spf, 'dkim', m.dkim, 'dmarc', m.dmarc, 'arc', m.arc, 'lookalike', m.lookalike, 'scan', m.scan_state, 'tls', m.tls_in, 'domain', m.sender_domain, 'sent_ms', (select (extract(epoch from ob.finished_at) * 1000)::bigint from public.fmail_outbox ob where ob.message_id = m.id and ob.state = 'sent' order by ob.finished_at desc limit 1), 'score', m.trust_score, 'grade', m.trust_grade, 'seal_mode', m.seal_mode,
    'msgid_blind', encode(m.msgid_blind, 'hex'), 'key_id', m.key_id, 'key_wrap', public.fmail_b64_169(m.key_wrap), 'aad_hash', encode(m.aad_hash, 'hex'),
    'meta', public.fmail_b64_169(m.sealed_meta), 'nonce_meta', public.fmail_b64_169(m.nonce_meta), 'body', public.fmail_b64_169(m.sealed_body), 'nonce_body', public.fmail_b64_169(m.nonce_body),
    'unseal_ledger_seq', case when v_led is null then null else (v_led ->> 'seq')::bigint end);
end $function$;

CREATE OR REPLACE FUNCTION public.fmail_list169(p_mailbox uuid, p_view text, p_after_ts timestamp with time zone DEFAULT NULL::timestamp with time zone, p_after_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare v_lim int := least(greatest(coalesce(p_limit, 50), 1), 100); v_res jsonb;
begin
  if p_view is null or p_view not in ('inbox', 'sent', 'drafts', 'outbox', 'archive', 'snoozed', 'spam', 'quarantine', 'trash', 'vault') then raise exception 'E169: unknown view' using errcode = '22023'; end if;
  if (p_after_ts is null) <> (p_after_id is null) then raise exception 'E169: the cursor needs both ts and id' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox) then raise exception 'E169: unknown mailbox' using errcode = '42704'; end if;
  with page as (
    select m.*, f.kind as fkind, t.vault as tvault, t.msg_count as tcount, row_number() over (order by m.received_at desc, m.id desc) as rn,
           (t.vault or f.kind = 'quarantine') as gated
      from public.fmail_messages m
      join public.fmail_folders f on f.id = m.folder_id
      join public.fmail_threads t on t.id = m.thread_id
     where m.mailbox_id = p_mailbox
       and public.fmail_view_169(f.kind, t.vault, t.snoozed_until) = p_view
       and (p_after_ts is null or (m.received_at, m.id) < (p_after_ts, p_after_id))
     order by m.received_at desc, m.id desc
     limit v_lim + 1),
  cut as (select * from page where rn <= v_lim)
  select jsonb_build_object(
    'rows', coalesce((select jsonb_agg(jsonb_build_object(
        'id', id, 'thread_id', thread_id, 'folder', fkind, 'direction', direction, 'received_ms', (extract(epoch from received_at) * 1000)::bigint,
        'size', size_bytes, 'attach', attach_count, 'read', is_read, 'starred', is_starred, 'draft', is_draft, 'thread_count', tcount,
        'spf', spf, 'dkim', dkim, 'dmarc', dmarc, 'arc', arc, 'lookalike', lookalike, 'scan', scan_state, 'tls', tls_in, 'domain', sender_domain,
        'sent_ms', (select (extract(epoch from ob.finished_at) * 1000)::bigint from public.fmail_outbox ob where ob.message_id = cut.id and ob.state = 'sent' order by ob.finished_at desc limit 1), 'score', trust_score, 'grade', trust_grade,
        'seal_mode', seal_mode, 'gated', gated,
        'msgid_blind', case when gated then null else encode(msgid_blind, 'hex') end,
        'meta', case when gated then null else public.fmail_b64_169(sealed_meta) end,
        'nonce_meta', case when gated then null else public.fmail_b64_169(nonce_meta) end,
        'key_id', case when gated then null else key_id end,
        'key_wrap', case when gated then null else public.fmail_b64_169(key_wrap) end,
        'aad_hash', case when gated then null else encode(aad_hash, 'hex') end) order by rn) from cut), '[]'::jsonb),
    'more', (select count(*) from page) > v_lim,
    'next', (select jsonb_build_object('ts', to_char(received_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'), 'id', id) from cut order by rn desc limit 1))
  into v_res;
  return v_res;
end $function$;

-- ===============================================================================================================================================
-- 9) LOCK IT DOWN: every new function only for service_role (the Rust engine); nothing for anon / authenticated / public
-- ===============================================================================================================================================
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as sig from pg_proc p where p.pronamespace = 'public'::regnamespace
           and p.proname in ('fmail_h183', 'fmail_edit_distance183', 'fmail_skeleton183', 'fmail_script_mix183', 'fmail_reason183', 'fmail_trust_score183', 'fmail_sig_hash183', 'fmail_auth_row_hash183',
                             'fmail_auth_immutable183', 'fmail_sender_history183', 'fmail_lookalike183', 'fmail_auth_record183', 'fmail_auth_get183', 'fmail_auth_summary183',
                             'fmail_auth_chain_verify183', 'fmail_out_facts183') loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
end $$;
revoke all on function public.fmail_get169(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.fmail_get169(uuid, uuid, text) to service_role;
revoke all on function public.fmail_list169(uuid, text, timestamptz, uuid, int) from public, anon, authenticated;
grant execute on function public.fmail_list169(uuid, text, timestamptz, uuid, int) to service_role;

-- ===============================================================================================================================================
-- 10) SELFTEST (rolls itself back): pure functions, the score grid, the writer, the lookalike kinds, the chain, append-only, the outgoing facts
-- ===============================================================================================================================================
create or replace function public.fmail_selftest_msg183(p_box uuid, p_n int, p_sender text) returns uuid
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_r jsonb;
begin
  v_r := public.fmail_deliver_inbound(p_box, 'inbox', 'vault', decode(repeat('ab', 40), 'hex'), decode(repeat('ac', 40), 'hex'), decode(repeat('01', 12), 'hex'), decode(repeat('02', 12), 'hex'),
    'vault-selftest', decode(repeat('02', 64), 'hex'), decode(repeat('03', 32), 'hex'), decode(lpad(to_hex(p_n), 64, '0'), 'hex'), null, null, null, p_sender, 1000, 'none', 'none', 'none', 'none', false, null, null);
  return (v_r ->> 'message_id')::uuid;
end $$;
revoke all on function public.fmail_selftest_msg183(uuid, int, text) from public, anon, authenticated;
grant execute on function public.fmail_selftest_msg183(uuid, int, text) to service_role;

create or replace function public.fmail_selftest183() returns text language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_uid uuid; v_box uuid; v_ok boolean; v_r jsonb; v_m uuid; v_m2 uuid; v_n int; v_pass int := 0; v_fail int := 0; ev jsonb; v_e public.fmail_auth_evidence;
  v_ok_ev jsonb; v_sigs jsonb; v_i int; v_t text; v_pub bytea := decode(repeat('06', 32), 'hex'); v_sealed bytea := decode(repeat('ab', 40), 'hex'); v_nonce bytea := decode(repeat('01', 12), 'hex');
  v_wrap bytea := decode(repeat('02', 64), 'hex'); v_aad bytea := decode(repeat('03', 32), 'hex'); v_mid bytea := decode(repeat('04', 32), 'hex'); v_rc text[] := array[repeat('05', 32)];
  v_tk text := repeat('a', 64); v_sel text; v_k uuid; v_ob uuid; v_now bigint := extract(epoch from now())::bigint; v_dm text; v_tl text; v_sc text; v_lk boolean; v_prev int; v_cur int; v_bad int := 0;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E183 selftest: no founder account to test with'; end if;
  begin
    -- A) pure functions
    res := res || jsonb_build_object('name', 'edit distance: one swap = 1, kitten/sitting = 3, beyond the bound answers bound+1, equal = 0, null stays null',
      'ok', public.fmail_edit_distance183('paypal', 'paypla', 3) = 1 and public.fmail_edit_distance183('kitten', 'sitting', 3) = 3 and public.fmail_edit_distance183('abcdef', 'uvwxyz', 2) = 3
            and public.fmail_edit_distance183('a', 'a') = 0 and public.fmail_edit_distance183(null, 'a') is null and public.fmail_edit_distance183('abc', 'xyzxyzxyz', 2) = 3);
    begin perform public.fmail_edit_distance183('a', 'b', 99); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'an absurd edit-distance bound is refused', 'ok', v_ok);
    res := res || jsonb_build_object('name', 'skeleton: paypa1 = paypal, a Cyrillic a = a, rnicrosoft = microsoft, g00gle = google, google differs from gooogle',
      'ok', public.fmail_skeleton183('paypa1.com') = public.fmail_skeleton183('paypal.com') and public.fmail_skeleton183(U&'\0440aypal.com') = public.fmail_skeleton183('paypal.com')
            and public.fmail_skeleton183('rnicrosoft.com') = public.fmail_skeleton183('microsoft.com') and public.fmail_skeleton183('g00gle.com') = public.fmail_skeleton183('google.com')
            and public.fmail_skeleton183('google.com') <> public.fmail_skeleton183('gooogle.com'));
    res := res || jsonb_build_object('name', 'skeleton map lines up (each translate position checked: o, n, hyphen, d, p)',
      'ok', public.fmail_skeleton183(U&'\03bf') = 'o' and public.fmail_skeleton183(U&'\0578') = 'n' and public.fmail_skeleton183(U&'\2013') = '-' and public.fmail_skeleton183(U&'\0501') = 'd' and public.fmail_skeleton183(U&'\03c1') = 'p');
    res := res || jsonb_build_object('name', 'mixed script: Latin + Cyrillic is true; plain Latin and pure Cyrillic are false', 'ok', public.fmail_script_mix183('p' || U&'\0430' || 'ypal.com')
      and not public.fmail_script_mix183('paypal.com') and not public.fmail_script_mix183(U&'\0430\0431\0432'));
    res := res || jsonb_build_object('name', 'hash helper tells NULL from empty text and is stable', 'ok', public.fmail_h183(array[null]::text[]) <> public.fmail_h183(array['']) and public.fmail_h183(array['a', 'b']) = public.fmail_h183(array['a', 'b'])
      and public.fmail_h183(array['a', 'b']) <> public.fmail_h183(array['ab']));
    -- B) the trust score
    v_r := public.fmail_trust_score183('pass', 'pass', 'pass', 'none', 'reject', true, true, 'pass', 'tls13_pq', 'clean', false, false, false, true, 5);
    res := res || jsonb_build_object('name', 'a perfect mail scores 100 and grade A+ with reasons', 'ok', (v_r ->> 'score') = '100' and (v_r ->> 'grade') = 'A+' and jsonb_array_length(v_r -> 'reasons') >= 8);
    v_r := public.fmail_trust_score183('fail', 'fail', 'fail', 'none', 'reject', false, false, 'none', 'tls13', 'clean', false, false, false, false, 0);
    res := res || jsonb_build_object('name', 'a DMARC fail against p=reject is a hard F', 'ok', (v_r ->> 'grade') = 'F' and (v_r ->> 'score')::int <= 10);
    v_r := public.fmail_trust_score183('fail', 'pass', 'fail', 'pass', 'reject', false, false, 'pass', 'tls13', 'clean', false, false, false, false, 0);
    res := res || jsonb_build_object('name', 'a valid ARC chain lifts a forwarded DMARC fail out of the hard F and says why', 'ok', (v_r ->> 'score')::int >= 12 and exists (select 1 from jsonb_array_elements(v_r -> 'reasons') x where x ->> 'code' = 'arc_forwarded'));
    v_r := public.fmail_trust_score183('pass', 'pass', 'pass', 'none', 'reject', true, true, 'pass', 'tls13_pq', 'clean', true, false, false, true, 5);
    res := res || jsonb_build_object('name', 'a lookalike sender cannot score above 55 (grade D) however clean the rest', 'ok', (v_r ->> 'score') = '55' and (v_r ->> 'grade') = 'D');
    v_r := public.fmail_trust_score183('pass', 'pass', 'pass', 'none', 'reject', true, true, 'pass', 'tls13_pq', 'infected', false, false, false, true, 5);
    res := res || jsonb_build_object('name', 'an infected mail is 0 and F even when every check passed', 'ok', (v_r ->> 'score') = '0' and (v_r ->> 'grade') = 'F');
    v_r := public.fmail_trust_score183('none', 'none', 'none', 'none', null, false, false, 'none', null, 'clean', false, false, false, false, 0);
    res := res || jsonb_build_object('name', 'no checks at all: score 0, grade F, reason says the sender publishes no DMARC', 'ok', (v_r ->> 'score') = '0' and exists (select 1 from jsonb_array_elements(v_r -> 'reasons') x where x ->> 'code' = 'dmarc_none'));
    v_n := 0; v_ok := true; v_prev := -1;
    foreach v_tl in array array['none', 'tls12', 'tls13', 'tls13_pq'] loop
      v_cur := (public.fmail_trust_score183('pass', 'pass', 'pass', 'none', 'none', true, true, 'pass', v_tl, 'clean', false, false, false, false, 0) ->> 'score')::int;
      if v_cur < v_prev then v_ok := false; end if; v_prev := v_cur;
    end loop;
    res := res || jsonb_build_object('name', 'TLS never lowers the score: none <= 1.2 <= 1.3 <= 1.3 post-quantum', 'ok', v_ok);
    v_ok := true; v_n := 0;
    foreach v_dm in array array['none', 'pass', 'fail', 'temperror', 'permerror'] loop
      foreach v_sc in array array['clean', 'infected', 'opaque', 'error', 'pending'] loop
        foreach v_tl in array array['none', 'tls13_pq'] loop
          foreach v_lk in array array[false, true] loop
            v_r := public.fmail_trust_score183('pass', 'pass', v_dm, 'none', 'reject', true, true, 'pass', v_tl, v_sc, v_lk, false, false, true, 9);
            v_n := v_n + 1;
            v_cur := (v_r ->> 'score')::int;
            v_t := case when v_sc = 'infected' or v_dm = 'fail' and v_cur < 45 then 'F' when v_cur >= 97 then 'A+' when v_cur >= 90 then 'A' when v_cur >= 80 then 'B' when v_cur >= 65 then 'C' when v_cur >= 45 then 'D' else 'F' end;
            if v_cur < 0 or v_cur > 100 then v_ok := false; end if;
            if (v_r ->> 'grade') <> v_t and not ((v_r ->> 'grade') = 'F') then v_ok := false; end if;
          end loop;
        end loop;
      end loop;
    end loop;
    res := res || jsonb_build_object('name', 'the score grid (' || v_n || ' combinations) stays inside 0..100 and every grade matches its band', 'ok', v_ok and v_n = 100);
    -- C) the writer
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest183@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    v_ok_ev := jsonb_build_object('header_from_domain', 'trusted-bank.example', 'org_domain', 'trusted-bank.example', 'client_ip', '203.0.113.7', 'helo', 'mx.trusted-bank.example', 'rdns', 'mx.trusted-bank.example',
      'mail_from_domain', 'trusted-bank.example', 'spf_result', 'pass', 'spf_domain', 'trusted-bank.example', 'dkim_result', 'pass', 'dmarc_result', 'pass', 'dmarc_policy', 'reject', 'dmarc_disposition', 'none',
      'dmarc_spf_aligned', true, 'dmarc_dkim_aligned', true, 'dmarc_walk', 1, 'dmarc_record_domain', 'trusted-bank.example', 'arc_result', 'none', 'iprev_result', 'pass', 'tls_class', 'tls13_pq',
      'tls_version', 'TLSv1.3', 'tls_cipher', 'TLS_AES_256_GCM_SHA384', 'tls_group', 'X25519MLKEM768', 'authres', 'anexomail.com; spf=pass smtp.mailfrom=trusted-bank.example; dkim=pass header.d=trusted-bank.example; dmarc=pass header.from=trusted-bank.example');
    v_sigs := jsonb_build_array(
      jsonb_build_object('domain', 'trusted-bank.example', 'selector', 's1', 'algo', 'ed25519-sha256', 'result', 'pass', 'aligned_relaxed', true, 'aligned_strict', true, 'key_bits', 256, 'sig_age_s', 30),
      jsonb_build_object('domain', 'trusted-bank.example', 'selector', 'r1', 'algo', 'rsa-sha256', 'result', 'pass', 'aligned_relaxed', true, 'aligned_strict', true, 'key_bits', 2048, 'sig_age_s', 30, 'body_limited', false));
    v_m := public.fmail_selftest_msg183(v_box, 1, 'trusted-bank.example');
    v_r := public.fmail_auth_record183(v_box, v_m, v_ok_ev, v_sigs);
    res := res || jsonb_build_object('name', 'first mail: recorded, seq 1, score 92, grade A (DMARC pass, aligned, post-quantum TLS, first mail from the sender)', 'ok', (v_r ->> 'recorded')::boolean and (v_r ->> 'seq') = '1' and (v_r ->> 'score') = '92' and (v_r ->> 'grade') = 'A');
    res := res || jsonb_build_object('name', 'the short verdicts are copied onto the message row (spf, dkim, dmarc, tls, score, grade)', 'ok',
      (select spf = 'pass' and dkim = 'pass' and dmarc = 'pass' and arc = 'none' and tls_in = 'tls13_pq' and trust_score = 92 and trust_grade = 'A' and not lookalike from public.fmail_messages where id = v_m));
    v_r := public.fmail_auth_record183(v_box, v_m, v_ok_ev, v_sigs);
    res := res || jsonb_build_object('name', 'recording the same mail twice answers the first record, no second row', 'ok', (v_r ->> 'duplicate')::boolean and (select count(*) from public.fmail_auth_evidence where message_id = v_m) = 1);
    v_r := public.fmail_auth_get183(v_box, v_m);
    res := res || jsonb_build_object('name', 'get door: two signatures, chain_ok, client ip and the RFC 8601 line come back', 'ok', (v_r ->> 'found')::boolean and jsonb_array_length(v_r #> '{dkim,sigs}') = 2 and (v_r ->> 'chain_ok')::boolean
      and (v_r #>> '{client,ip}') = '203.0.113.7' and (v_r ->> 'authres') like 'anexomail.com; spf=pass%' and (v_r #>> '{tls,group}') = 'X25519MLKEM768');
    begin perform public.fmail_auth_record183(v_box, public.fmail_selftest_msg183(v_box, 90, 'x.example'), v_ok_ev || '{"spf_result":"maybe"}'::jsonb); v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a verdict outside the closed list is refused (CHECK)', 'ok', v_ok);
    begin perform public.fmail_auth_record183(v_box, public.fmail_selftest_msg183(v_box, 91, 'x.example'), v_ok_ev || '{"dmarc_spf_aligned":false,"dmarc_dkim_aligned":false}'::jsonb); v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'DMARC pass without any aligned pass is refused', 'ok', v_ok);
    begin perform public.fmail_auth_record183(v_box, public.fmail_selftest_msg183(v_box, 92, 'x.example'), '{"spf_result":"pass"}'::jsonb); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'evidence without a From domain is refused', 'ok', v_ok);
    begin perform public.fmail_auth_record183(v_box, gen_random_uuid(), v_ok_ev); v_ok := false; exception when sqlstate '23503' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'an unknown message is refused', 'ok', v_ok);
    begin perform public.fmail_auth_record183(gen_random_uuid(), v_m, v_ok_ev); v_ok := false; exception when sqlstate '23503' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'an unknown mailbox is refused', 'ok', v_ok);
    begin perform public.fmail_auth_record183(v_box, v_m, '[]'::jsonb); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'evidence that is not a json object is refused', 'ok', v_ok);
    -- the sender becomes known after 3 mails that passed
    v_m2 := public.fmail_selftest_msg183(v_box, 2, 'trusted-bank.example'); perform public.fmail_auth_record183(v_box, v_m2, v_ok_ev, v_sigs);
    v_m2 := public.fmail_selftest_msg183(v_box, 3, 'trusted-bank.example'); perform public.fmail_auth_record183(v_box, v_m2, v_ok_ev, v_sigs);
    v_m2 := public.fmail_selftest_msg183(v_box, 4, 'trusted-bank.example'); v_r := public.fmail_auth_record183(v_box, v_m2, v_ok_ev, v_sigs);
    res := res || jsonb_build_object('name', 'the 4th mail from a sender that passed 3 times is a known sender: 100, A+', 'ok', (v_r ->> 'score') = '100' and (v_r ->> 'grade') = 'A+' and (v_r ->> 'sender_known')::boolean and (v_r ->> 'seq') = '4');
    -- lookalikes
    v_m2 := public.fmail_selftest_msg183(v_box, 10, 'trusted-bnak.example'); v_r := public.fmail_auth_record183(v_box, v_m2, v_ok_ev || '{"header_from_domain":"trusted-bnak.example","org_domain":"trusted-bnak.example","mail_from_domain":"trusted-bnak.example","spf_domain":"trusted-bnak.example"}'::jsonb, v_sigs);
    res := res || jsonb_build_object('name', 'a swapped-letter copy of a trusted domain is a lookalike (typo) of it and is held at grade D', 'ok', (v_r ->> 'lookalike')::boolean and (v_r ->> 'lookalike_kind') = 'typo' and (v_r ->> 'lookalike_of') = 'trusted-bank.example' and (v_r ->> 'score') = '55' and (v_r ->> 'grade') = 'D'
      and (select lookalike from public.fmail_messages where id = v_m2));
    v_m2 := public.fmail_selftest_msg183(v_box, 11, 'trusted-bank.test'); v_r := public.fmail_auth_record183(v_box, v_m2, v_ok_ev || '{"header_from_domain":"trusted-bank.test","org_domain":"trusted-bank.test","mail_from_domain":"trusted-bank.test","spf_domain":"trusted-bank.test"}'::jsonb, v_sigs);
    res := res || jsonb_build_object('name', 'the same name with another ending is a lookalike (tld_swap)', 'ok', (v_r ->> 'lookalike_kind') = 'tld_swap');
    v_m2 := public.fmail_selftest_msg183(v_box, 12, 'trusted-bank-secure.example'); v_r := public.fmail_auth_record183(v_box, v_m2, v_ok_ev || '{"header_from_domain":"trusted-bank-secure.example","org_domain":"trusted-bank-secure.example","mail_from_domain":"trusted-bank-secure.example","spf_domain":"trusted-bank-secure.example"}'::jsonb, v_sigs);
    res := res || jsonb_build_object('name', 'a known name plus a hyphenated word is a lookalike (brand_combo)', 'ok', (v_r ->> 'lookalike_kind') = 'brand_combo');
    v_m2 := public.fmail_selftest_msg183(v_box, 13, 'trustedbank.example'); v_r := public.fmail_auth_record183(v_box, v_m2, v_ok_ev || '{"header_from_domain":"trustedbank.example","org_domain":"trustedbank.example","mail_from_domain":"trustedbank.example","spf_domain":"trustedbank.example"}'::jsonb, v_sigs);
    res := res || jsonb_build_object('name', 'the same name without the hyphen is a lookalike (hyphen)', 'ok', (v_r ->> 'lookalike_kind') = 'hyphen');
    v_m2 := public.fmail_selftest_msg183(v_box, 14, 'paypa1.com'); v_r := public.fmail_auth_record183(v_box, v_m2, v_ok_ev || '{"header_from_domain":"paypa1.com","org_domain":"paypa1.com","mail_from_domain":"paypa1.com","spf_domain":"paypa1.com"}'::jsonb, v_sigs);
    res := res || jsonb_build_object('name', 'paypa1.com is a homoglyph of the famous brand paypal.com on the very first mail', 'ok', (v_r ->> 'lookalike_kind') = 'homoglyph' and (v_r ->> 'lookalike_of') = 'paypal.com');
    v_m2 := public.fmail_selftest_msg183(v_box, 15, 'xn--pypal-4ve.com'); v_r := public.fmail_auth_record183(v_box, v_m2, v_ok_ev || jsonb_build_object('header_from_domain', 'xn--pypal-4ve.com', 'org_domain', 'xn--pypal-4ve.com', 'mail_from_domain', 'xn--pypal-4ve.com', 'spf_domain', 'xn--pypal-4ve.com',
      'from_unicode', 'p' || U&'\0430' || 'ypal.com'), v_sigs);
    res := res || jsonb_build_object('name', 'an internationalised domain that mixes Latin and Cyrillic is flagged mixed_script, grade D at best', 'ok', (v_r ->> 'lookalike_kind') = 'mixed_script' and (v_r ->> 'score')::int <= 55
      and (select mixed_script from public.fmail_auth_evidence where message_id = v_m2));
    v_m2 := public.fmail_selftest_msg183(v_box, 16, 'google.com'); v_r := public.fmail_auth_record183(v_box, v_m2, v_ok_ev || '{"header_from_domain":"google.com","org_domain":"google.com","mail_from_domain":"google.com","spf_domain":"google.com"}'::jsonb, v_sigs);
    res := res || jsonb_build_object('name', 'the real google.com is never a lookalike', 'ok', not (v_r ->> 'lookalike')::boolean);
    v_m2 := public.fmail_selftest_msg183(v_box, 17, 'newcompany-xyz.example'); v_r := public.fmail_auth_record183(v_box, v_m2, v_ok_ev || '{"header_from_domain":"newcompany-xyz.example","org_domain":"newcompany-xyz.example","mail_from_domain":"newcompany-xyz.example","spf_domain":"newcompany-xyz.example"}'::jsonb, v_sigs);
    res := res || jsonb_build_object('name', 'an unrelated new domain is not a lookalike and says "first mail from this sender"', 'ok', not (v_r ->> 'lookalike')::boolean and exists (select 1 from jsonb_array_elements(v_r -> 'reasons') x where x ->> 'code' = 'first_mail'));
    -- the scanner decides too
    v_m2 := public.fmail_selftest_msg183(v_box, 18, 'trusted-bank.example'); update public.fmail_messages set scan_state = 'infected' where id = v_m2;
    v_r := public.fmail_auth_record183(v_box, v_m2, v_ok_ev, v_sigs);
    res := res || jsonb_build_object('name', 'a mail the scanner found infected is 0 and F in the stored verdict too', 'ok', (v_r ->> 'score') = '0' and (v_r ->> 'grade') = 'F' and (select trust_grade = 'F' from public.fmail_messages where id = v_m2));
    -- D) doors
    v_r := public.fmail_auth_summary183(v_box, 30);
    select count(*) into v_n from public.fmail_auth_evidence where mailbox_id = v_box;
    res := res || jsonb_build_object('name', 'summary door: totals add up, the head of the chain is the last row, bad mails are listed', 'ok', (v_r ->> 'total')::int = v_n and (v_r ->> 'head_seq')::int = v_n
      and ((v_r #>> '{grades,A+}')::int + (v_r #>> '{grades,A}')::int + (v_r #>> '{grades,B}')::int + (v_r #>> '{grades,C}')::int + (v_r #>> '{grades,D}')::int + (v_r #>> '{grades,F}')::int) = v_n
      and jsonb_array_length(v_r -> 'recent_bad') >= 3 and (v_r ->> 'lookalike')::int >= 6);
    v_r := public.fmail_auth_chain_verify183(v_box);
    res := res || jsonb_build_object('name', 'the verdict chain verifies: every row hash, every link, every signature digest', 'ok', (v_r ->> 'checked')::int = v_n and (v_r ->> 'broken') = '0' and (v_r ->> 'sigs_broken') = '0');
    select * into v_e from public.fmail_auth_evidence where message_id = v_m;
    res := res || jsonb_build_object('name', 'the row hash changes when any single fact changes (score, a verdict, the client address)', 'ok', public.fmail_auth_row_hash183(v_e) = v_e.row_hash
      and public.fmail_auth_row_hash183(jsonb_populate_record(v_e, '{"score":1}'::jsonb)) <> v_e.row_hash and public.fmail_auth_row_hash183(jsonb_populate_record(v_e, '{"dmarc_result":"fail"}'::jsonb)) <> v_e.row_hash
      and public.fmail_auth_row_hash183(jsonb_populate_record(v_e, '{"client_ip":"203.0.113.8"}'::jsonb)) <> v_e.row_hash);
    begin update public.fmail_auth_evidence set score = 100 where mailbox_id = v_box; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'the evidence refuses an UPDATE', 'ok', v_ok);
    begin delete from public.fmail_auth_evidence where mailbox_id = v_box; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'the evidence refuses a DELETE', 'ok', v_ok);
    begin update public.fmail_auth_sig set result = 'fail' where evidence_id = v_e.id; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'the signature rows refuse an UPDATE', 'ok', v_ok);
    begin truncate public.fmail_auth_sig; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'the signature rows refuse a TRUNCATE', 'ok', v_ok);
    -- E) outgoing facts (G3) + the new keys of the list and get doors
    v_sel := public.fmail_dkim_selector175(v_box, 'ed25519-sha256');
    perform public.fmail_dkim_install170(v_uid, v_box, v_sel, 'ed25519-sha256', v_pub, v_wrap, v_nonce, v_tk);
    select id into v_k from public.fmail_dkim_keys where mailbox_id = v_box and selector = v_sel;
    v_r := public.fmail_compose_send170(v_uid, v_box, v_sealed, v_sealed, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, v_mid, null, null, 100, 0, v_rc, null, v_tk, null);
    v_ob := (v_r ->> 'outbox_id')::uuid;
    select message_id into v_m2 from public.fmail_outbox where id = v_ob;
    v_r := public.fmail_out_facts183(v_box, v_m2);
    res := res || jsonb_build_object('name', 'outgoing facts before the receiver answers: state queued or sending, no sent time yet, not accepted', 'ok', (v_r ->> 'direction') = 'out' and (v_r ->> 'state') in ('queued', 'scheduled', 'sending') and (v_r ->> 'sent_ms') is null and not (v_r ->> 'accepted')::boolean);
    update public.fmail_policy set send_enabled = true where id = 1;
    update public.fmail_outbox set not_before = now() - interval '1 second' where id = v_ob;
    perform 1 from public.fmail_outbox_claim(10) cl where cl = v_ob;
    perform public.fmail_dkim_sign_record175(v_ob, v_k, 'from:to:subject:date:message-id:mime-version', repeat('A', 43) || '=', repeat('c', 64), v_now, v_now + 7 * 86400);
    perform public.fmail_outbox_result(v_uid, v_ob, true, '250 2.0.0 OK selftest', 'tls13_pq', true, null);
    v_r := public.fmail_out_facts183(v_box, v_m2);
    res := res || jsonb_build_object('name', 'outgoing facts after the receiver said 250: accepted, sent_ms set, TLS 1.3 post-quantum, DKIM signed with the selector', 'ok', (v_r ->> 'accepted')::boolean and (v_r ->> 'sent_ms') is not null
      and (v_r ->> 'tls') = 'tls13_pq' and (v_r ->> 'dkim_signed')::boolean and (v_r #>> '{signatures,0,selector}') = v_sel and (v_r ->> 'reply') like '250 %');
    begin perform public.fmail_auth_record183(v_box, v_m2, v_ok_ev); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'an outgoing mail cannot get a receive-side verdict (refused)', 'ok', v_ok);
    v_r := public.fmail_list169(v_box, 'sent');
    res := res || jsonb_build_object('name', 'the Sent list now carries sent_ms (the time of the 250), not only the compose time', 'ok', jsonb_array_length(v_r -> 'rows') >= 1 and (v_r #>> '{rows,0,sent_ms}') is not null);
    v_r := public.fmail_list169(v_box, 'inbox');
    res := res || jsonb_build_object('name', 'the Inbox list carries score and grade per mail', 'ok', jsonb_array_length(v_r -> 'rows') >= 4 and (v_r #>> '{rows,0,grade}') is not null);
    v_r := public.fmail_get169(v_box, v_m);
    res := res || jsonb_build_object('name', 'get door carries score, grade and sent_ms keys', 'ok', (v_r ->> 'score') = '92' and (v_r ->> 'grade') = 'A' and v_r ? 'sent_ms');
    -- F) closed doors
    res := res || jsonb_build_object('name', 'door audit (E179): no stable door of E183 writes', 'ok', not exists (select 1 from public.fmail_door_audit179() where door like '%183%'));
    res := res || jsonb_build_object('name', 'evidence tables: forced row-level security, nothing for anon or authenticated', 'ok',
      (select relforcerowsecurity and relrowsecurity from pg_class where oid = 'public.fmail_auth_evidence'::regclass) and (select relforcerowsecurity and relrowsecurity from pg_class where oid = 'public.fmail_auth_sig'::regclass)
      and not has_table_privilege('anon', 'public.fmail_auth_evidence', 'select') and not has_table_privilege('authenticated', 'public.fmail_auth_sig', 'insert')
      and not has_table_privilege('service_role', 'public.fmail_auth_evidence', 'update') and not has_table_privilege('service_role', 'public.fmail_auth_evidence', 'delete'));
    res := res || jsonb_build_object('name', 'the writer and the readers are open to service_role only', 'ok', has_function_privilege('service_role', 'public.fmail_auth_record183(uuid,uuid,jsonb,jsonb)', 'execute')
      and not has_function_privilege('anon', 'public.fmail_auth_record183(uuid,uuid,jsonb,jsonb)', 'execute') and not has_function_privilege('authenticated', 'public.fmail_auth_get183(uuid,uuid)', 'execute'));
    res := res || jsonb_build_object('name', 'the brand list is seeded (40+ names) and holds this very domain', 'ok', (select count(*) from public.fmail_brand_domains183) >= 40 and exists (select 1 from public.fmail_brand_domains183 where domain = 'anexomail.com'));
    res := res || jsonb_build_object('name', 'main ledger chain still verifies', 'ok', public.fmail_ledger_verify(1) >= 1);
    raise exception 'E183_SELFTEST_ROLLBACK %', res::text;
  exception when others then
    if sqlerrm like 'E183_SELFTEST_ROLLBACK %' then res := substr(sqlerrm, length('E183_SELFTEST_ROLLBACK ') + 1)::jsonb;
    else return 'E183 selftest: ERROR ' || sqlerrm || ' (' || sqlstate || ') after ' || jsonb_array_length(res) || ' checks'; end if;
  end;
  for ev in select * from jsonb_array_elements(res) loop if (ev ->> 'ok')::boolean then v_pass := v_pass + 1; else v_fail := v_fail + 1; end if; end loop;
  if v_fail > 0 then return 'E183 selftest: ' || v_pass || ' ok, ' || v_fail || ' failed: ' || (select string_agg(x ->> 'name', ' | ') from jsonb_array_elements(res) x where (x ->> 'ok')::boolean is not true); end if;
  return 'E183 selftest: ' || v_pass || ' ok, 0 failed';
end $$;
revoke all on function public.fmail_selftest183() from public, anon, authenticated;
grant execute on function public.fmail_selftest183() to service_role;

select public.fmail_selftest183() as e183_selftest;

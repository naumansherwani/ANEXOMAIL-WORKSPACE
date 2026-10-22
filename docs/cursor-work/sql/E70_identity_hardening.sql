-- E70 — IDENTITY HARDENING (22 Oct 2026, founder: "jo banned hai woh banned hai jab tak main us ki nahi suno ga — andar se bahar jane ke baad wapsi ka koi raasta nahi").
-- E66–E69 ek-insaan-ek-account ki neev hain. Yeh file us par chaar nayi dewarein lagati hai — sab hash-only, sab service_role-only, sab idempotent:
--
--   H1  BROWSER FINGERPRINT (3 guroh: fp_hw / fp_gfx / fp_env). Client har guroh ka SHA-256 bhejta hai, server us par HMAC (pepper) lagata hai; asli cheez kabhi nahi.
--       * guroh isliye: browser update se ek guroh badal sakta hai — "kam az kam fp_match_min (2) guroh milen" = fingerprint match (tabdeeli ke saamne mazboot).
--       * fingerprint akela KABHI seedha ban nahi (ek jaise phone/laptop bahut hain): akela match => HOLD (account banta hai, andar jaane ke liye aap ki manzoori).
--       * fingerprint + koi doosra kamzor nishan (network / device_shape) ya mazboot nishan => DENY.
--       * ek hi 3-guroh fingerprint 4+ accounts par => "fingerprint_farm" review (office ke ek jaise laptops ghalat ban na hon, isliye review, ban nahi).
--       * BHEED KA NISHAN: koi guroh 25+ alag accounts par ho (Tor Browser / Firefox resist-fingerprinting sab ko ek jaisa dete hain) => match nahi ginta (fp_crowd_limit).
--   H2  PROBATION: naye account ki had (identity_account_limits) — SQL mein tayyar; asli had lagana Brain/Rust ke hooks ka agla qadam (file ke aakhir mein likha).
--   H3  DISPOSABLE EMAIL: identity_disposable_domains (seed + founder ki apni list); bade provider (gmail/outlook/...) kabhi nahi pakde jate (identity_domain_protected).
--   H4  APPROVAL GATE (identity_vault_policy.signup_gate): open | hold_matches (default) | approval_all (har naya signup pending jab tak founder haan na kahe).
--       * HOLD ka matlab: auth.users.banned_until = 100 saal (GoTrue khud sign-in / refresh rok deta hai — koi route bypass nahi kar sakta) + auth.sessions saaf.
--       * founder: identity_hold_decide(approve | reject | reject+ban). Faisle ke baghair 30 din (hold_expire_days) baad khud 'rejected' (account band hi rehta hai).
--
-- Policy ek jagah (identity_signup_decide) — SQL = Bun (identity-mirror.ts) = Rust (vault_core.rs, Auth Phase A) ka ek hi sach.
-- Rule 38 (advanced), 42 (editor compat), 43 (RLS ON), 44 (server se chalta hai). Idempotent. Koi DROP TABLE/COLUMN nahi.
-- WAPAS LENA (haath se, zaroorat par): update public.identity_vault_policy set signup_gate = 'open' where id = 1;   -- sirf gate band
--   aur hold wale account chhodne ke liye: update auth.users set banned_until = null where id in (select account_id from public.identity_account_state where state = 'pending');
set lock_timeout = '3s';
set statement_timeout = '60s';

-- ---- 1. policy: nayi hadein (ek hi row, DB-checked) ------------------------------------------------------------------------------
alter table public.identity_vault_policy
  add column if not exists fp_match_min     smallint not null default 3   check (fp_match_min between 2 and 5),   -- 5 guroh mein se kitne milen (3 = hardware+gpu+fonts: browser badalne se bhi bachna mushkil)
  add column if not exists fp_min_usable    smallint not null default 3   check (fp_min_usable between 1 and 5),   -- kam se kam itne guroh nikalne chahiyen; warna 'fingerprint chhupaya' ka shak
  add column if not exists fp_evasion       text     not null default 'review' check (fp_evasion in ('allow', 'review', 'hold')),   -- chhupane wale (Tor/RFP/noise/API-bot) ka kya kiya jaye
  add column if not exists fp_farm_limit    smallint not null default 4   check (fp_farm_limit between 2 and 50),
  add column if not exists fp_crowd_limit   smallint not null default 25  check (fp_crowd_limit between 5 and 1000),
  add column if not exists velocity_limit   smallint not null default 8   check (velocity_limit between 3 and 100),
  add column if not exists signup_gate      text     not null default 'hold_matches' check (signup_gate in ('open', 'hold_matches', 'approval_all')),
  add column if not exists probation_days   smallint not null default 7   check (probation_days between 0 and 60),
  add column if not exists disposable_block boolean  not null default true,
  add column if not exists hold_expire_days smallint not null default 30  check (hold_expire_days between 1 and 365),
  add column if not exists gate_changed_by  uuid,
  add column if not exists gate_changed_at  timestamptz;

-- ---- 2. kind: fingerprint ke PANCH guroh "kamzor-darje" ke hain (akele kabhi ban nahi; milkar corroborate) -----------------------------
--   fp_hw   machine (cores, memory, screen, platform, UA-client-hints)      fp_gpu  graphics card (WebGL/WebGPU vendor, renderer, limits, extensions)
--   fp_font installed fonts (OS ki chhap)                                      fp_gfx  is browser ka canvas + audio render      fp_env  time zone, languages, calendar
--   hw+gpu+font MACHINE ke nishan hain: browser badalne (Chrome -> Firefox) par bhi wahi rehte hain; gfx+env browser/setting ke.
create or replace function public.identity_kind_strong(k text)
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select case k when 'device_key' then true when 'email' then true when 'recovery' then true when 'payment' then true
               when 'device_shape' then false when 'network' then false
               when 'fp_hw' then false when 'fp_gpu' then false when 'fp_font' then false when 'fp_gfx' then false when 'fp_env' then false else null end
$$;

create or replace function public.identity_kind_fp(k text)
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select k in ('fp_hw', 'fp_gpu', 'fp_font', 'fp_gfx', 'fp_env')
$$;

-- client ka SHA-256 hex (64) ya kuch nahi. Gandi cheez (lambai, hex nahi) => NULL, kabhi error nahi: ek kharab client baqi nishan nahi rokta.
create or replace function public.identity_fp_canon(p text)
returns text language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select case when lower(btrim(p)) ~ '^[0-9a-f]{64}$' then lower(btrim(p)) else null end
$$;

-- ---- 3. audit ke event ki list barhao ----------------------------------------------------------------------------------------------
do $$
declare c record;
begin
  for c in select conname from pg_constraint
            where conrelid = 'public.identity_vault_audit'::regclass and contype = 'c' and pg_get_constraintdef(oid) ~ '\mevent\M' loop
    execute format('alter table public.identity_vault_audit drop constraint %I', c.conname);
  end loop;
  alter table public.identity_vault_audit add constraint identity_vault_audit_event_ck
    check (event in ('register', 'deny', 'review', 'ban', 'lift', 'purge', 'hold', 'approve', 'reject', 'gate', 'domain', 'expire'));
end $$;

-- ---- 4. account ki halat (hold / manzoori) -----------------------------------------------------------------------------------------
create table if not exists public.identity_account_state (
  account_id      uuid        primary key references auth.users (id) on delete cascade,
  state           text        not null check (state in ('pending', 'approved', 'rejected')),
  hold_kind       text        check (hold_kind in ('match', 'gate', 'manual', 'evasion')),
  reason          text        check (char_length(reason) <= 300),
  held_at         timestamptz not null default now(),
  decided_at      timestamptz,
  decided_by      uuid,
  note            text        check (char_length(note) <= 500),
  probation_until timestamptz,
  constraint identity_account_state_decided_ck check ((state = 'pending') = (decided_at is null))
);
create index if not exists identity_account_state_pending_idx on public.identity_account_state (held_at) where state = 'pending';

-- ---- 5. disposable email domains ---------------------------------------------------------------------------------------------------
create table if not exists public.identity_disposable_domains (
  domain   text        primary key check (domain = lower(domain) and char_length(domain) <= 120
                                           and domain ~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'),
  source   text        not null default 'seed' check (source in ('seed', 'founder')),
  active   boolean     not null default true,
  added_at timestamptz not null default now(),
  added_by uuid
);

-- ---- 6. RLS ON + band (Rule 43) ------------------------------------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['identity_account_state', 'identity_disposable_domains'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
    execute format('grant select, insert, update, delete on table public.%I to service_role', t);
    if not exists (select 1 from pg_policy p where p.polrelid = format('public.%I', t)::regclass and p.polname = 'ax_service_role_only') then
      execute format('create policy ax_service_role_only on public.%I for all to service_role using (true) with check (true)', t);
    end if;
  end loop;
end $$;

-- ---- 7. seed: mashhoor disposable domains (founder apni list panel se barha sakta hai) --------------------------------------------------
insert into public.identity_disposable_domains (domain) values
  ('mailinator.com'), ('guerrillamail.com'), ('guerrillamail.net'), ('guerrillamail.org'), ('guerrillamail.biz'), ('guerrillamail.de'), ('guerrillamail.info'),
  ('guerrillamailblock.com'), ('sharklasers.com'), ('grr.la'), ('pokemail.net'), ('spam4.me'),
  ('10minutemail.com'), ('10minutemail.net'), ('10minemail.com'), ('20minutemail.com'), ('minuteinbox.com'),
  ('temp-mail.org'), ('temp-mail.io'), ('tempmail.com'), ('tempmail.net'), ('tempmail.dev'), ('tempmailo.com'), ('tempail.com'), ('tempinbox.com'),
  ('tempr.email'), ('tempmailaddress.com'), ('tmpmail.org'), ('tmpmail.net'), ('tmail.ws'), ('tmails.net'),
  ('throwawaymail.com'), ('throwaway.email'), ('throwam.com'),
  ('yopmail.com'), ('yopmail.fr'), ('yopmail.net'), ('cool.fr.nf'), ('jetable.fr.nf'), ('nospam.ze.tc'), ('nomail.xl.cx'), ('mega.zik.dj'),
  ('speed.1s.fr'), ('courriel.fr.nf'), ('moncourrier.fr.nf'), ('monemail.fr.nf'), ('monmail.fr.nf'),
  ('trashmail.com'), ('trashmail.net'), ('trashmail.de'), ('trashmail.me'), ('trashmail.io'), ('trash-mail.com'), ('trash-mail.at'), ('mytrashmail.com'),
  ('getnada.com'), ('nada.email'), ('nada.ltd'), ('dispostable.com'), ('maildrop.cc'), ('mailnesia.com'), ('mailcatch.com'), ('mailnull.com'),
  ('mintemail.com'), ('mytemp.email'), ('mohmal.com'), ('mohmal.im'), ('moakt.com'), ('moakt.cc'), ('emailondeck.com'),
  ('fakeinbox.com'), ('fakemail.net'), ('fakemailgenerator.com'), ('emailfake.com'), ('email-fake.com'), ('crazymailing.com'),
  ('discard.email'), ('discardmail.com'), ('discardmail.de'), ('spamgourmet.com'), ('spambox.us'), ('spamfree24.org'), ('spamex.com'),
  ('spamavert.com'), ('spamherelots.com'), ('mailforspam.com'), ('mt2015.com'), ('mailtemp.net'), ('burnermail.io'), ('inboxkitten.com'),
  ('33mail.com'), ('anonbox.net'), ('armyspy.com'), ('cuvox.de'), ('dayrep.com'), ('einrot.com'), ('fleckens.hu'), ('gustr.com'),
  ('jourrapide.com'), ('rhyta.com'), ('superrito.com'), ('teleworm.us'), ('lroid.com'), ('mailsac.com'), ('mail7.io'), ('mailpoof.com'),
  ('linshiyouxiang.net'), ('1secmail.com'), ('1secmail.net'), ('1secmail.org'), ('esiix.com'), ('wwjmp.com'), ('xojxe.com'), ('yoggm.com'),
  ('kzccv.com'), ('qiott.com'), ('icznn.com'), ('vjuum.com'), ('laafd.com'), ('txcct.com'), ('dcctb.com'), ('cevipsa.com'),
  ('harakirimail.com'), ('mailbox.in.ua'), ('emailtemporanea.net'), ('emailtemporal.org'), ('correotemporal.org'), ('mailtemporal.org'),
  ('disbox.net'), ('instantemailaddress.com'), ('dropmail.me'), ('thankyou2010.com'), ('trbvm.com'), ('vomoto.com'), ('drdrb.com'),
  ('mailexpire.com'), ('getairmail.com'), ('mailnator.com'), ('spambog.com'), ('spambog.de'), ('sofimail.com'), ('tafmail.com'),
  ('wegwerfmail.de'), ('wegwerfmail.net'), ('wegwerfmail.org'), ('einmalmail.de'), ('byom.de'), ('objectmail.com'), ('proxymail.eu'),
  ('rcpt.at'), ('safetymail.info'), ('selfdestructingmail.com'), ('sendspamhere.com'), ('shitmail.me'), ('smapfree24.com'), ('snakemail.com'),
  ('sogetthis.com'), ('soodonims.com'), ('spoofmail.de'), ('stuffmail.de'), ('supergreatmail.com'), ('supermailer.jp'), ('suremail.info'),
  ('tempemail.net'), ('tempinbox.co.uk'), ('tempomail.fr'), ('temporaryemail.net'), ('temporaryforwarding.com'), ('thisisnotmyrealemail.com'),
  ('tradermail.info'), ('trashymail.com'), ('trillianpro.com'), ('twinmail.de'), ('tyldd.com'), ('uggsrock.com'), ('upliftnow.com'),
  ('veryrealemail.com'), ('vidchart.com'), ('webemail.me'), ('wh4f.org'), ('whatiaas.com'), ('whyspam.me'), ('willselfdestruct.com'),
  ('wuzup.net'), ('wuzupmail.net'), ('yepmail.net'), ('yuurok.com'), ('zehnminutenmail.de'), ('zoemail.org')
on conflict (domain) do nothing;

-- bade/asli provider kabhi disposable nahi mane jate (founder se galti se bhi nahi)
create or replace function public.identity_domain_protected(p_domain text)
returns boolean language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select lower(btrim(p_domain)) in ('gmail.com', 'googlemail.com', 'outlook.com', 'hotmail.com', 'live.com', 'msn.com', 'yahoo.com', 'ymail.com',
    'icloud.com', 'me.com', 'mac.com', 'aol.com', 'proton.me', 'protonmail.com', 'pm.me', 'zoho.com', 'fastmail.com', 'gmx.com', 'gmx.net', 'mail.com',
    'yandex.com', 'yandex.ru', 'qq.com', '163.com', '126.com', 'anexomail.com')
$$;

-- email ya sirf domain => kya disposable hai? (sub-domain bhi: x.mailinator.com). Protected domain hamesha false.
create or replace function public.identity_email_is_disposable(p_email text)
returns boolean language sql stable set search_path = pg_catalog, public as $$
  with d as (
    select lower(btrim(case when position('@' in coalesce(p_email, '')) > 0 then split_part(p_email, '@', 2) else coalesce(p_email, '') end)) as dom)
  select exists (
    select 1 from d, public.identity_disposable_domains x
     where d.dom <> '' and not public.identity_domain_protected(d.dom) and x.active and (d.dom = x.domain or d.dom like '%.' || x.domain))
$$;

-- ---- 8. ek jagah ka "ban hits": signals ke wo nishan jo abhi active ban mein hain --------------------------------------------------------
-- crowd = us fingerprint guroh ke kitne alag accounts hain (sirf fp kinds ke liye). Tor Browser / Firefox "resist fingerprinting" sab ko ek jaisa
-- fingerprint dete hain: aisa "bheed ka nishan" ek ban wale ki wajah se hazaron bekasoor ko hold na kare — isliye bheed wala guroh match nahi ginta.
create or replace function public.identity_ban_hits(p_signals jsonb)
returns table (kind text, strong boolean, fp boolean, reason text, appealable boolean, banned_at timestamptz, crowd integer)
language sql stable set search_path = pg_catalog, public as $$
  select s.kind, public.identity_kind_strong(s.kind), public.identity_kind_fp(s.kind), b.reason, b.appealable, b.banned_at,
         case when public.identity_kind_fp(s.kind)
              then (select count(distinct x.account_id)::integer from public.identity_signals x where x.kind = s.kind and x.hmac = s.hmac)
              else null end
    from public.identity_parse_signals(p_signals) s
    join public.identity_bans b on b.kind = s.kind and b.hmac = s.hmac and b.lifted_at is null and (b.expires_at is null or b.expires_at > now())
$$;

-- ---- 9. FAISLA: allow | review | hold | deny (siyasat ka ek hi sach) ------------------------------------------------------------------
-- Tarteeb: disposable => deny; mazboot match => deny; fingerprint(>=min) + koi aur => deny; fingerprint(>=min) => hold (gate open ho to review);
--          fingerprint chhupaya (evasion) => review/hold (policy); farm / velocity / shared_device / weak_match => review; gate=approval_all => hold; warna allow.
-- Jawab mein kabhi hash ya "kis account se mila" nahi; matched mein sirf kind ke naam.
create or replace function public.identity_signup_decide(p_signals jsonb, p_domain text default null)
returns jsonb language plpgsql stable set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare
  pol      public.identity_vault_policy;
  v_strong text[];
  v_fp     text[];
  v_weak   text[];
  v_app_s  boolean;
  v_app_a  boolean;
  v_reason text;
  v_net    bytea;
  v_usable integer;
  v_open   integer;
  n        integer;
  v_review text;
begin
  select * into pol from public.identity_vault_policy where id = 1;

  if pol.disposable_block and p_domain is not null and public.identity_email_is_disposable(p_domain) then
    return jsonb_build_object('decision', 'deny', 'matched', jsonb_build_array('disposable_email'), 'appealable', false, 'reason', 'disposable_email');
  end if;

  select coalesce(array_agg(distinct h.kind order by h.kind) filter (where h.strong), '{}'),
         coalesce(array_agg(distinct h.kind order by h.kind) filter (where h.fp and coalesce(h.crowd, 0) < pol.fp_crowd_limit), '{}'),
         coalesce(array_agg(distinct h.kind order by h.kind) filter (where not h.strong and not h.fp), '{}'),
         coalesce(bool_and(h.appealable) filter (where h.strong), true),
         coalesce(bool_and(h.appealable), true),
         (array_agg(h.reason order by h.banned_at desc))[1]
    into v_strong, v_fp, v_weak, v_app_s, v_app_a, v_reason
    from public.identity_ban_hits(p_signals) h;

  if cardinality(v_strong) > 0 then
    return jsonb_build_object('decision', 'deny', 'matched', to_jsonb(v_strong), 'appealable', v_app_s, 'reason', v_reason);
  end if;

  -- fingerprint + koi aur kamzor nishan => deny (do alag nishaniyan ek hi insaan ki taraf ishara karti hain)
  if cardinality(v_fp) >= pol.fp_match_min and cardinality(v_weak) >= 1 then
    return jsonb_build_object('decision', 'deny', 'matched', to_jsonb(v_fp || v_weak), 'appealable', v_app_a, 'reason', v_reason);
  end if;

  -- akela fingerprint match => hold (gate open ho to sirf review)
  if cardinality(v_fp) >= pol.fp_match_min then
    if pol.signup_gate <> 'open' then
      return jsonb_build_object('decision', 'hold', 'matched', '[]'::jsonb, 'appealable', true, 'reason', 'fingerprint_match', 'hold_kind', 'match');
    end if;
    v_review := 'fingerprint_match';
  end if;

  -- fingerprint chhupane ka shak: (a) bahut kam guroh nikle (noise-wala browser, Tor, blocker, ya seedha API bot jisne fingerprint bheja hi nahi)
  -- (b) jitne guroh nikle sab "bheed" ke hain (Tor Browser / RFP sab ko ek jaisa dete hain) => koi pehchan nahi. Policy fp_evasion batati hai kya karna hai.
  select count(distinct s.kind), count(distinct s.kind) filter (where
           (select count(distinct x.account_id) from public.identity_signals x where x.kind = s.kind and x.hmac = s.hmac) < pol.fp_crowd_limit)
    into v_usable, v_open
    from public.identity_parse_signals(p_signals) s where public.identity_kind_fp(s.kind);
  if v_review is null and pol.fp_evasion <> 'allow' and (v_usable < pol.fp_min_usable or v_open = 0) then
    if pol.fp_evasion = 'hold' and pol.signup_gate <> 'open' then
      return jsonb_build_object('decision', 'hold', 'matched', '[]'::jsonb, 'appealable', true, 'reason', 'fingerprint_unavailable', 'hold_kind', 'evasion');
    end if;
    v_review := 'fingerprint_unavailable';
  end if;

  -- farm: kam se kam fp_match_min ek jaise guroh bahut (fp_farm_limit+) alag accounts par => ek mashin par accounts ka karkhana.
  -- (bheed wale guroh ginti mein nahi: Tor ke hazaron bekasoor "farm" na ban jayen)
  if v_review is null then
    select count(*) into n from (
      select x.account_id
        from public.identity_signals x
        join public.identity_parse_signals(p_signals) s on s.kind = x.kind and s.hmac = x.hmac and public.identity_kind_fp(s.kind)
       where (select count(distinct y.account_id) from public.identity_signals y where y.kind = x.kind and y.hmac = x.hmac) < pol.fp_crowd_limit
       group by x.account_id
      having count(distinct x.kind) >= pol.fp_match_min) f;
    if n >= pol.fp_farm_limit then v_review := 'fingerprint_farm'; end if;
  end if;

  -- velocity: ek hi network se ek ghante mein bahut signup
  if v_review is null then
    select s.hmac into v_net from public.identity_parse_signals(p_signals) s where s.kind = 'network' limit 1;
    if v_net is not null then
      select count(distinct x.account_id) into n from public.identity_signals x where x.kind = 'network' and x.hmac = v_net and x.first_seen > now() - interval '1 hour';
      if n >= pol.velocity_limit then v_review := 'signup_velocity'; end if;
    end if;
  end if;

  -- ek device_key 3+ accounts par
  if v_review is null and exists (
       select 1 from public.identity_parse_signals(p_signals) s
        where s.kind = 'device_key'
          and (select count(distinct x.account_id) from public.identity_signals x where x.kind = 'device_key' and x.hmac = s.hmac) >= pol.shared_device_limit) then
    v_review := 'shared_device';
  end if;

  -- kamzor milan (ek fingerprint guroh bhi ek kamzor nishan gina jata hai)
  if v_review is null and cardinality(v_weak) + (case when cardinality(v_fp) >= 1 then 1 else 0 end) >= pol.weak_review_threshold then
    v_review := 'weak_match';
  end if;

  if pol.signup_gate = 'approval_all' then
    return jsonb_build_object('decision', 'hold', 'matched', '[]'::jsonb, 'appealable', true, 'reason', coalesce(v_review, 'approval_required'), 'hold_kind', 'gate');
  end if;
  if v_review is not null then
    return jsonb_build_object('decision', 'review', 'matched', '[]'::jsonb, 'appealable', true, 'reason', v_review);
  end if;
  return jsonb_build_object('decision', 'allow', 'matched', '[]'::jsonb, 'appealable', true, 'reason', null);
end $$;

-- purana naam (E66) ab usi faisle ka patla chhilka: purane callers ko bhi naya sach milta hai
create or replace function public.identity_signup_check(p_signals jsonb)
returns jsonb language sql stable set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select public.identity_signup_decide(p_signals, null)
$$;

-- ---- 10. hold lagana / manzoori ------------------------------------------------------------------------------------------------------------
-- hold: GoTrue ka banned_until (100 saal) — sign-in aur refresh dono GoTrue khud rokta hai; maujooda sessions saaf. Dobara chalana nuksan nahi (pehle se state ho to kuch nahi).
create or replace function public.identity_hold_apply(p_account uuid, p_kind text, p_reason text)
returns boolean language plpgsql volatile security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare n integer;
begin
  if p_account is null or p_kind not in ('match', 'gate', 'manual', 'evasion') then raise exception 'bad_hold' using errcode = '22023'; end if;
  insert into public.identity_account_state (account_id, state, hold_kind, reason)
  values (p_account, 'pending', p_kind, left(coalesce(p_reason, 'hold'), 300))
  on conflict (account_id) do nothing;
  get diagnostics n = row_count;
  if n = 0 then return false; end if;
  update auth.users set banned_until = now() + interval '100 years' where id = p_account;
  if to_regclass('auth.sessions') is not null then delete from auth.sessions where user_id = p_account; end if;
  insert into public.identity_vault_audit (event, account_id, detail) values ('hold', p_account, jsonb_build_object('kind', p_kind, 'reason', left(coalesce(p_reason, ''), 120)));
  return true;
end $$;

create or replace function public.identity_is_founder(p_user uuid)
returns boolean language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  if p_user is null then return false; end if;
  if to_regclass('public.founder_accounts') is not null then
    return exists (select 1 from public.founder_accounts where user_id = p_user);
  end if;
  return false;
end $$;

-- founder ka faisla: approve (probation_days ke saath) | reject (| ban: iske sab nishan blacklist)
create or replace function public.identity_hold_decide(p_actor uuid, p_account uuid, p_decision text, p_note text default null, p_ban boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare pol public.identity_vault_policy; st public.identity_account_state;
begin
  if not public.safety_can_review(p_actor) then return jsonb_build_object('allowed', false); end if;
  if p_decision not in ('approve', 'reject') then raise exception 'bad_decision' using errcode = '22023'; end if;
  select * into st from public.identity_account_state where account_id = p_account for update;
  if not found or st.state <> 'pending' then return jsonb_build_object('allowed', true, 'ok', false, 'error', 'not_pending'); end if;
  select * into pol from public.identity_vault_policy where id = 1;
  if p_decision = 'approve' then
    update public.identity_account_state
       set state = 'approved', decided_at = now(), decided_by = p_actor, note = left(p_note, 500),
           probation_until = case when pol.probation_days > 0 then now() + make_interval(days => pol.probation_days) else null end
     where account_id = p_account;
    update auth.users set banned_until = null where id = p_account;
    insert into public.identity_vault_audit (event, account_id, detail) values ('approve', p_account, jsonb_build_object('by_human', true, 'probation_days', pol.probation_days));
    return jsonb_build_object('allowed', true, 'ok', true, 'state', 'approved');
  end if;
  update public.identity_account_state
     set state = 'rejected', decided_at = now(), decided_by = p_actor, note = left(p_note, 500)
   where account_id = p_account;
  if coalesce(p_ban, false) then perform public.identity_ban_account(p_account, 'policy_violation', false, p_actor); end if;
  insert into public.identity_vault_audit (event, account_id, detail) values ('reject', p_account, jsonb_build_object('by_human', true, 'ban', coalesce(p_ban, false)));
  return jsonb_build_object('allowed', true, 'ok', true, 'state', 'rejected', 'banned', coalesce(p_ban, false));
end $$;

-- koi faisla na aaye to hold_expire_days baad 'rejected' (account band hi rehta hai; ban nahi)
create or replace function public.identity_hold_sweep()
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public set statement_timeout = '30s' as $$
declare pol public.identity_vault_policy; n integer;
begin
  select * into pol from public.identity_vault_policy where id = 1;
  with x as (
    update public.identity_account_state
       set state = 'rejected', decided_at = now(), note = 'expired without a decision'
     where state = 'pending' and held_at < now() - make_interval(days => pol.hold_expire_days)
    returning account_id)
  insert into public.identity_vault_audit (event, account_id, detail) select 'expire', account_id, jsonb_build_object('days', pol.hold_expire_days) from x;
  get diagnostics n = row_count;
  return jsonb_build_object('expired', n);
end $$;

-- ---- 11. register: nishan likho + hold lagao (E66 ka same signature, ab fingerprint aur hold ke saath) ---------------------------------------
create or replace function public.identity_register(p_account uuid, p_signals jsonb)
returns jsonb language plpgsql volatile set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare
  pol public.identity_vault_policy;
  chk jsonb;
  n   integer := 0;
  held boolean := false;
begin
  if p_account is null then raise exception 'account_required' using errcode = '22023'; end if;
  chk := public.identity_signup_decide(p_signals, null);
  if chk ->> 'decision' = 'deny' then
    insert into public.identity_vault_audit (event, account_id, detail) values ('deny', p_account, jsonb_build_object('matched', chk -> 'matched'));
    return chk;
  end if;
  select * into pol from public.identity_vault_policy where id = 1;
  insert into public.identity_signals (account_id, kind, hmac, key_id, retain_until)
  select p_account, s.kind, s.hmac, pol.key_id,
         case when s.kind in ('device_key', 'device_shape') or public.identity_kind_fp(s.kind) then now() + make_interval(days => pol.signal_retain_days)
              when s.kind = 'network' then now() + make_interval(days => pol.network_retain_days)
              else null end
    from public.identity_parse_signals(p_signals) s
  on conflict (account_id, kind, hmac) do update
     set last_seen = now(), seen_count = public.identity_signals.seen_count + 1,
         retain_until = case when public.identity_signals.retain_until is null then null else excluded.retain_until end;
  get diagnostics n = row_count;
  if chk ->> 'decision' = 'hold' then
    held := public.identity_hold_apply(p_account, coalesce(chk ->> 'hold_kind', 'match'), coalesce(chk ->> 'reason', 'hold'));
  end if;
  insert into public.identity_vault_audit (event, account_id, detail)
  values (case when chk ->> 'decision' = 'review' then 'review' else 'register' end, p_account, jsonb_build_object('signals', n, 'reason', chk -> 'reason', 'held', held));
  -- 'held' = is call ne hold lagaya; 'pending' = account abhi bhi manzoori ka muntazir hai (retry/outbox par bhi sach): route isi par 202 deta hai
  return chk || jsonb_build_object('registered', n, 'held', held,
    'pending', exists (select 1 from public.identity_account_state s where s.account_id = p_account and s.state = 'pending'));
end $$;

-- ---- 12. suspicious flag ka ek helper + payment (naye/chhote account par hold, purane par sirf flag) ------------------------------------------
create or replace function public.identity_flag_suspicious(p_account uuid, p_why text)
returns void language plpgsql volatile set search_path = pg_catalog, public as $$
begin
  if to_regclass('public.account_integrity') is null or p_account is null then return; end if;
  insert into public.account_integrity (user_id, state, reason, evidence)
  values (p_account, 'suspicious', 'identity vault: ' || left(p_why, 200), jsonb_build_object('source', 'identity_vault', 'reason', left(p_why, 200)))
  on conflict (user_id) do update
    set state = case when public.account_integrity.state = 'clean' then 'suspicious' else public.account_integrity.state end,
        reason = case when public.account_integrity.state = 'clean' then excluded.reason else public.account_integrity.reason end,
        updated_at = now();
end $$;

create or replace function public.identity_register_payment(p_account uuid, p_ref text, p_key text)
returns jsonb language plpgsql volatile set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare
  h text := public.identity_hmac_hex('payment', lower(btrim(p_ref)), p_key);
  pol public.identity_vault_policy;
  v_blocked boolean;
  v_young boolean;
  v_held boolean := false;
begin
  if p_account is null or h is null then return jsonb_build_object('registered', 0); end if;
  select * into pol from public.identity_vault_policy where id = 1;
  insert into public.identity_signals (account_id, kind, hmac, key_id, retain_until) values (p_account, 'payment', decode(h, 'hex'), pol.key_id, null)
  on conflict (account_id, kind, hmac) do update set last_seen = now(), seen_count = public.identity_signals.seen_count + 1;
  -- kisi aur (ban hue) account ka payment nishan? => founder ki queue; 30 din se chhote account par gate chalu ho to hold bhi
  select exists (select 1 from public.identity_bans b
                  where b.kind = 'payment' and b.hmac = decode(h, 'hex') and b.lifted_at is null and (b.expires_at is null or b.expires_at > now())
                    and b.source_ref is distinct from p_account) into v_blocked;
  if v_blocked then
    perform public.identity_flag_suspicious(p_account, 'payment method matches a blocked identity');
    select coalesce((select u.created_at > now() - interval '30 days' from auth.users u where u.id = p_account), false) into v_young;
    if v_young and pol.signup_gate <> 'open' then
      v_held := public.identity_hold_apply(p_account, 'match', 'payment method matches a blocked identity');
    end if;
    insert into public.identity_vault_audit (event, account_id, detail) values ('review', p_account, jsonb_build_object('reason', 'payment_match', 'held', v_held));
  end if;
  return jsonb_build_object('registered', 1, 'blocked_match', v_blocked, 'held', v_held);
end $$;

-- ---- 13. raw (HMAC server-side) wrappers: sirf parity-saboot / Rust Phase A ke liye; Bun apna HMAC khud karta hai ---------------------------------
create or replace function public.identity_signals_full_raw(p_email text, p_recovery text, p_device_key text, p_shape text, p_network text,
                                                              p_fp_hw text, p_fp_gpu text, p_fp_font text, p_fp_gfx text, p_fp_env text, p_key text)
returns jsonb language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select public.identity_signals_raw(p_email, p_recovery, p_device_key, p_shape, p_network, p_key)
      || coalesce((select jsonb_agg(jsonb_build_object('kind', k, 'hmac', h)) from (
           values ('fp_hw',   public.identity_hmac_hex('fp_hw',   public.identity_fp_canon(p_fp_hw),   p_key)),
                  ('fp_gpu',  public.identity_hmac_hex('fp_gpu',  public.identity_fp_canon(p_fp_gpu),  p_key)),
                  ('fp_font', public.identity_hmac_hex('fp_font', public.identity_fp_canon(p_fp_font), p_key)),
                  ('fp_gfx',  public.identity_hmac_hex('fp_gfx',  public.identity_fp_canon(p_fp_gfx),  p_key)),
                  ('fp_env',  public.identity_hmac_hex('fp_env',  public.identity_fp_canon(p_fp_env),  p_key))) v (k, h) where h is not null), '[]'::jsonb)
$$;

create or replace function public.identity_signup_decide_raw(p_email text, p_recovery text, p_device_key text, p_shape text, p_network text,
                                                               p_fp_hw text, p_fp_gpu text, p_fp_font text, p_fp_gfx text, p_fp_env text, p_key text)
returns jsonb language plpgsql stable set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare s jsonb := public.identity_signals_full_raw(p_email, p_recovery, p_device_key, p_shape, p_network, p_fp_hw, p_fp_gpu, p_fp_font, p_fp_gfx, p_fp_env, p_key);
begin
  if jsonb_array_length(s) = 0 then
    return public.identity_signup_decide('[{"kind":"network","hmac":"0000000000000000000000000000000000000000000000000000000000000000"}]'::jsonb, split_part(p_email, '@', 2));
  end if;
  return public.identity_signup_decide(s, split_part(coalesce(p_email, ''), '@', 2));
end $$;

-- ---- 14. H2: naye account ki had (probation) — SQL ka sach; lagana Brain/Rust ke hooks ka kaam ---------------------------------------------------
-- Probation: account ki umar < probation_days (ya founder ne manzoori ke saath probation_until di) aur account paid-trusted nahi.
-- Ek saaf jawab: Brain/Rust is se poochte hain, apne andar tadbeer nahi karte.
create or replace function public.identity_account_limits(p_account uuid)
returns jsonb language plpgsql stable set search_path = pg_catalog, public set statement_timeout = '5s' as $$
declare pol public.identity_vault_policy; created timestamptz; until_ts timestamptz; st_until timestamptz; active boolean; paid boolean := false;
begin
  select * into pol from public.identity_vault_policy where id = 1;
  select u.created_at into created from auth.users u where u.id = p_account;
  if created is null then return jsonb_build_object('probation', false); end if;
  select s.probation_until into st_until from public.identity_account_state s where s.account_id = p_account;
  until_ts := greatest(created + make_interval(days => pol.probation_days), coalesce(st_until, created));
  if to_regclass('public.polar_subscriptions') is not null then
    execute 'select exists (select 1 from public.polar_subscriptions where user_id = $1)' into paid using p_account;
  end if;
  active := pol.probation_days > 0 and until_ts > now() and not paid and not public.identity_is_founder(p_account);
  return jsonb_build_object(
    'probation', active, 'until', case when active then until_ts else null end,
    'rules', case when active then jsonb_build_object('max_recipients_per_message', 20, 'max_messages_per_day', 50, 'invites', false, 'public_links', false, 'bulk', false)
                  else '{}'::jsonb end);
end $$;

-- ---- 15. founder ke switch: gate + disposable list ------------------------------------------------------------------------------------------------
create or replace function public.identity_gate_set(p_actor uuid, p_mode text)
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare old text;
begin
  if not public.identity_is_founder(p_actor) then return jsonb_build_object('allowed', false); end if;
  if p_mode not in ('open', 'hold_matches', 'approval_all') then raise exception 'bad_mode' using errcode = '22023'; end if;
  select signup_gate into old from public.identity_vault_policy where id = 1;
  update public.identity_vault_policy set signup_gate = p_mode, gate_changed_by = p_actor, gate_changed_at = now(), updated_at = now() where id = 1;
  insert into public.identity_vault_audit (event, detail) values ('gate', jsonb_build_object('from', old, 'to', p_mode, 'by_human', true));
  return jsonb_build_object('allowed', true, 'ok', true, 'gate', p_mode, 'was', old);
end $$;

-- chhupane walon (fingerprint nikla hi nahi / sab bheed ka) ke saath kya ho: allow | review (default) | hold. Sirf founder.
create or replace function public.identity_evasion_set(p_actor uuid, p_mode text)
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare old text;
begin
  if not public.identity_is_founder(p_actor) then return jsonb_build_object('allowed', false); end if;
  if p_mode not in ('allow', 'review', 'hold') then raise exception 'bad_mode' using errcode = '22023'; end if;
  select fp_evasion into old from public.identity_vault_policy where id = 1;
  update public.identity_vault_policy set fp_evasion = p_mode, gate_changed_by = p_actor, gate_changed_at = now(), updated_at = now() where id = 1;
  insert into public.identity_vault_audit (event, detail) values ('gate', jsonb_build_object('evasion_from', old, 'evasion_to', p_mode, 'by_human', true));
  return jsonb_build_object('allowed', true, 'ok', true, 'evasion', p_mode, 'was', old);
end $$;

create or replace function public.identity_disposable_set(p_actor uuid, p_domain text, p_on boolean)
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare d text := lower(btrim(p_domain));
begin
  if not public.identity_is_founder(p_actor) then return jsonb_build_object('allowed', false); end if;
  if d is null or d !~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$' or char_length(d) > 120 then
    return jsonb_build_object('allowed', true, 'ok', false, 'error', 'bad_domain');
  end if;
  if public.identity_domain_protected(d) then return jsonb_build_object('allowed', true, 'ok', false, 'error', 'protected_domain'); end if;
  insert into public.identity_disposable_domains (domain, source, active, added_by) values (d, 'founder', coalesce(p_on, true), p_actor)
  on conflict (domain) do update set active = coalesce(p_on, true), added_by = p_actor;
  insert into public.identity_vault_audit (event, detail) values ('domain', jsonb_build_object('on', coalesce(p_on, true), 'by_human', true));
  return jsonb_build_object('allowed', true, 'ok', true);
end $$;

-- ---- 16. overview: E69 ki har cheez + gate + hold queue + disposable ------------------------------------------------------------------------------
create or replace function public.identity_admin_overview(p_actor uuid)
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '10s' as $$
declare h jsonb; alert boolean; pol public.identity_vault_policy;
begin
  if not public.safety_can_review(p_actor) then return jsonb_build_object('allowed', false); end if;
  select * into pol from public.identity_vault_policy where id = 1;
  select coalesce(jsonb_agg(jsonb_build_object('source', source, 'age_s', extract(epoch from now() - reported_at)::int, 'outbox_pending', outbox_pending,
                  'check_failures_1h', check_failures_1h, 'mirror_size', mirror_size, 'mirror_age_s', mirror_age_s, 'mode', mode)), '[]'::jsonb),
         coalesce(bool_or(outbox_pending > 0 or check_failures_1h >= 5 or mode <> 'mirror' or mirror_age_s > 900 or reported_at < now() - interval '30 minutes'), false)
    into h, alert from public.identity_health;
  return jsonb_build_object(
    'allowed', true,
    'bans_active', (select count(*) from public.identity_bans where lifted_at is null and (expires_at is null or expires_at > now())),
    'bans_by_reason', coalesce((select jsonb_object_agg(reason, c) from (select reason, count(*) c from public.identity_bans where lifted_at is null and (expires_at is null or expires_at > now()) group by reason) x), '{}'::jsonb),
    'bans_permanent', (select count(*) from public.identity_bans where lifted_at is null and expires_at is null),
    'bans_expiring_30d', (select count(*) from public.identity_bans where lifted_at is null and expires_at between now() and now() + interval '30 days'),
    'signups_denied_30d', (select count(*) from public.identity_vault_audit where event = 'deny' and at > now() - interval '30 days' and detail ? 'matched'),
    'signups_review_30d', (select count(*) from public.identity_vault_audit where event = 'review' and at > now() - interval '30 days'),
    'signals_total', (select count(*) from public.identity_signals),
    'health', h, 'health_alert', alert,
    'appeals', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'created_at', a.created_at, 'contact', a.contact, 'statement', a.statement) order by a.created_at)
                           from public.identity_signup_appeals a where a.state = 'new'), '[]'::jsonb),
    'appeals_open', (select count(*) from public.identity_signup_appeals where state = 'new'),
    'gate', jsonb_build_object('mode', pol.signup_gate, 'changed_at', pol.gate_changed_at, 'disposable_block', pol.disposable_block,
                               'probation_days', pol.probation_days, 'hold_expire_days', pol.hold_expire_days, 'fp_match_min', pol.fp_match_min,
                               'evasion', pol.fp_evasion, 'fp_min_usable', pol.fp_min_usable),
    'holds_pending', (select count(*) from public.identity_account_state where state = 'pending'),
    'holds', coalesce((select jsonb_agg(jsonb_build_object('account_id', s.account_id, 'email', u.email, 'kind', s.hold_kind, 'reason', s.reason, 'held_at', s.held_at,
                                                           'expires_at', s.held_at + make_interval(days => pol.hold_expire_days)) order by s.held_at)
                          from (select * from public.identity_account_state where state = 'pending' order by held_at limit 50) s
                          left join auth.users u on u.id = s.account_id), '[]'::jsonb),
    'disposable_domains', (select count(*) from public.identity_disposable_domains where active),
    'holds_30d', (select count(*) from public.identity_vault_audit where event = 'hold' and at > now() - interval '30 days'));
end $$;

-- ---- 17. purge: hold sweep bhi saath ------------------------------------------------------------------------------------------------------------------
create or replace function public.identity_vault_purge()
returns jsonb language plpgsql volatile set search_path = pg_catalog, public set statement_timeout = '30s' as $$
declare a integer; b integer; c integer; d jsonb;
begin
  delete from public.identity_signals where retain_until is not null and retain_until < now();
  get diagnostics a = row_count;
  delete from public.identity_bans where (expires_at is not null and expires_at < now() - interval '30 days') or (lifted_at is not null and lifted_at < now() - interval '30 days');
  get diagnostics b = row_count;
  delete from public.identity_vault_audit where at < now() - interval '2 years';
  get diagnostics c = row_count;
  d := public.identity_hold_sweep();
  insert into public.identity_vault_audit (event, detail) values ('purge', jsonb_build_object('signals', a, 'bans', b, 'audit', c, 'holds_expired', d -> 'expired'));
  return jsonb_build_object('signals', a, 'bans', b, 'audit', c, 'holds_expired', d -> 'expired');
end $$;

-- ---- 18. privileges (Rule 43): sirf service_role ---------------------------------------------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array[
    'public.identity_kind_fp(text)', 'public.identity_fp_canon(text)', 'public.identity_domain_protected(text)', 'public.identity_email_is_disposable(text)',
    'public.identity_ban_hits(jsonb)', 'public.identity_signup_decide(jsonb,text)', 'public.identity_signup_check(jsonb)', 'public.identity_register(uuid,jsonb)',
    'public.identity_hold_apply(uuid,text,text)', 'public.identity_is_founder(uuid)', 'public.identity_hold_decide(uuid,uuid,text,text,boolean)',
    'public.identity_hold_sweep()', 'public.identity_flag_suspicious(uuid,text)', 'public.identity_register_payment(uuid,text,text)',
    'public.identity_signals_full_raw(text,text,text,text,text,text,text,text,text,text,text)', 'public.identity_signup_decide_raw(text,text,text,text,text,text,text,text,text,text,text)',
    'public.identity_evasion_set(uuid,text)',
    'public.identity_account_limits(uuid)', 'public.identity_gate_set(uuid,text)', 'public.identity_disposable_set(uuid,text,boolean)',
    'public.identity_admin_overview(uuid)', 'public.identity_vault_purge()', 'public.identity_kind_strong(text)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

comment on table public.identity_account_state is 'Hold / approval state per account (E70). pending => auth.users.banned_until is set by identity_hold_apply; only a human decision (identity_hold_decide) lifts it.';
comment on table public.identity_disposable_domains is 'Disposable-email domains (E70): seed + founder additions. Protected providers can never be added.';
comment on function public.identity_signup_decide(jsonb, text) is 'The single sign-up policy (E70): allow | review | hold | deny. SQL = Bun identity-mirror.ts = Rust vault_core.rs. Never returns hashes or source accounts.';

-- ---- 19. POST-CONDITION ---------------------------------------------------------------------------------------------------------------------------------
do $$
declare cnt integer;
begin
  select count(*) into cnt from pg_class c where c.oid in ('public.identity_account_state'::regclass, 'public.identity_disposable_domains'::regclass) and c.relrowsecurity;
  if cnt <> 2 then raise exception 'E70 POST-CONDITION: RLS ON nahi' using errcode = 'AX070'; end if;
  if has_function_privilege('authenticated', 'public.identity_hold_decide(uuid,uuid,text,text,boolean)', 'execute')
     or has_function_privilege('anon', 'public.identity_signup_decide(jsonb,text)', 'execute') then
    raise exception 'E70 POST-CONDITION: anon/authenticated ko execute mil gaya' using errcode = 'AX070';
  end if;
  if not public.identity_kind_fp('fp_hw') or public.identity_kind_strong('fp_gfx') is distinct from false or public.identity_kind_strong('email') is distinct from true then
    raise exception 'E70 POST-CONDITION: kind ki definition galat' using errcode = 'AX070';
  end if;
  if public.identity_email_is_disposable('someone@gmail.com') or not public.identity_email_is_disposable('x@sub.mailinator.com') then
    raise exception 'E70 POST-CONDITION: disposable jaanch galat' using errcode = 'AX070';
  end if;
end $$;

notify pgrst, 'reload schema';

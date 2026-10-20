-- E45 — blocked account: 72 ghante export ke baad ASLI delete — Blueprint G36 — 20 Oct 2026
--
-- Sach jo audit mein mila: `account_integrity_purge_due()` sirf chat data mitati thi (mail/auth/baqi sab reh jata) aur use koi
-- chalata hi nahi tha. Ab:
--   * purge_due: export window (purge_after) guzarne ke baad `account_purge(user, false, true, false)` — poora account (E24 ka mukammal engine)
--   * delete se pehle ek TOMBSTONE (sirf email ka sha256 + wajah + tareekhen + integrity timeline; koi mail/naam/content nahi) — appeal/audit ke liye
--     (account_integrity_log append-only hai aur user ke saath mit-ta hai; purge ke dauran uska trigger usi transaction mein band hota hai)
--   * device ban rehta hai (device_bans user se bandha nahi — appealable)
--   * purge na ho sake (active subscription, multi-member org ka owner, Storage files) => account blocked hi rehta hai, log mein 'purge_blocked'
--     + wajah, 24 ghante baad dobara koshish; founder blockers khud hal kare (account_deletion_blockers(user)).
--   * timer: docs/cursor-work/server/integrity-purge/ (har ghante). Ya haath se: select public.account_integrity_purge_due();
-- PEHLE chalna chahiye: phase24a (account_integrity), E24 (account_purge). Dobara chalana safe.
set search_path = public, extensions;

create table if not exists public.account_integrity_tombstones (
  id            bigserial primary key,
  user_id       uuid not null,                 -- FK nahi: user mit chuka hota hai
  email_sha256  text,                          -- purana naam; ab ismein HMAC-SHA256 (HASHING.md) hota hai, key na ho to NULL
  state_before  text,
  reason        text,
  warned_at     timestamptz,
  blocked_at    timestamptz,
  export_until  timestamptz,
  purged_at     timestamptz not null default now(),
  purge_report  jsonb not null default '{}'::jsonb,
  timeline      jsonb not null default '[]'::jsonb   -- log ki events (event, at, actor, reason): log khud user ke saath mit-ti hai
);
alter table public.account_integrity_tombstones add column if not exists timeline jsonb not null default '[]'::jsonb;
alter table public.account_integrity_tombstones enable row level security;
revoke all on public.account_integrity_tombstones from public, anon, authenticated;
grant all on public.account_integrity_tombstones to service_role;
grant usage, select on sequence public.account_integrity_tombstones_id_seq to service_role;

-- log mein naya event: purge_blocked
do $$
declare c text;
begin
  for c in
    select con.conname from pg_constraint con
     where con.conrelid = 'public.account_integrity_log'::regclass and con.contype = 'c'
       and pg_get_constraintdef(con.oid) ilike '%event%in%'
  loop
    execute format('alter table public.account_integrity_log drop constraint %I', c);
  end loop;
  alter table public.account_integrity_log add constraint account_integrity_log_event_check
    check (event in ('evaluated','suspicious','warned','blocked','export_window_opened','exported','released','purged','appeal_linked','purge_blocked'));
end $$;

-- HASHING.md: email jaisi andaza-yogya personal cheez ka hash HMAC-SHA256 (subkey = HMAC(key,'anexomail/email-hash/v1')). Key server env se aati hai.
create or replace function public.email_hmac_v1(_email text, _key text)
returns text language sql immutable set search_path = public, extensions as $$
  select case when coalesce(_key, '') = '' or coalesce(_email, '') = '' then null
    else encode(hmac(convert_to(lower(btrim(_email)), 'UTF8'),
           hmac(convert_to('anexomail/email-hash/v1', 'UTF8'), convert_to(_key, 'UTF8'), 'sha256'), 'sha256'), 'hex') end
$$;
revoke all on function public.email_hmac_v1(text, text) from public, anon, authenticated;
grant execute on function public.email_hmac_v1(text, text) to service_role;

-- purani bina-argument wali (phase24a) hatao; nayi `_key default null` ke saath (dono rehte to `purge_due()` call ambiguous hoti)
drop function if exists public.account_integrity_purge_due();
create or replace function public.account_integrity_purge_due(_key text default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare
  r        public.account_integrity;
  v_email  text;
  v_rep    jsonb;
  v_tl     jsonb;
  v_done   int := 0;
  v_stuck  int := 0;
begin
  for r in
    select * from public.account_integrity
     where state = 'blocked' and purge_after is not null
       and purge_after < now() and purged_at is null
     order by purge_after
     limit 25                      -- ek chakkar mein had; baqi agle ghante
  loop
    select lower(u.email) into v_email from auth.users u where u.id = r.user_id;
    if v_email is null then
      -- auth user pehle hi nahi: sirf record band karo
      update public.account_integrity set state = 'purged', purged_at = now(), updated_at = now() where user_id = r.user_id;
      continue;
    end if;

    -- chat ke woh columns jo account_purge ke user_id/owner_id/owner_user_id scan mein nahi aate
    if to_regclass('public.chat_messages') is not null then delete from public.chat_messages where sender_user_id = r.user_id; end if;
    if to_regclass('public.chat_work_items') is not null then delete from public.chat_work_items where owner_user_id = r.user_id or created_by = r.user_id; end if;

    -- log append-only hai (trigger update/delete rokta hai) aur user ke saath cascade se mit-ta hai: pehle timeline tombstone ke liye
    -- utha lo, phir sirf isi transaction mein trigger band karo (rollback ho to apne aap wapas laga rehta hai)
    select coalesce(jsonb_agg(jsonb_build_object('event', l.event, 'at', l.at, 'actor', l.actor, 'reason', l.reason) order by l.id), '[]'::jsonb)
      into v_tl from public.account_integrity_log l where l.user_id = r.user_id;
    begin
      alter table public.account_integrity_log disable trigger account_integrity_log_no_change;
      v_rep := public.account_purge(r.user_id, false, true, false);   -- 72h hi grace thi
      alter table public.account_integrity_log enable trigger account_integrity_log_no_change;
    exception when others then   -- ek kharab account poori batch ko na roke
      v_rep := jsonb_build_object('ok', false, 'error', 'purge_exception', 'detail', sqlerrm);
    end;
    if coalesce((v_rep->>'ok')::boolean, false) then
      insert into public.account_integrity_tombstones
        (user_id, email_sha256, state_before, reason, warned_at, blocked_at, export_until, purge_report, timeline)
      values (r.user_id, public.email_hmac_v1(v_email, _key), r.state, r.reason, r.warned_at, r.blocked_at, r.export_until,
              jsonb_build_object('anonymised_rows', v_rep->'anonymised_rows', 'ledgers_unlocked', v_rep->'ledgers_unlocked'), v_tl);
      v_done := v_done + 1;
    else
      update public.account_integrity set purge_after = now() + interval '24 hours', updated_at = now() where user_id = r.user_id;
      insert into public.account_integrity_log (user_id, event, actor, detail)
      values (r.user_id, 'purge_blocked', 'engine',
              jsonb_build_object('error', v_rep->>'error', 'blockers', v_rep->'blockers', 'count', v_rep->'count', 'detail', v_rep->>'detail',
                                 'retry_after', now() + interval '24 hours'));
      v_stuck := v_stuck + 1;
    end if;
  end loop;
  return jsonb_build_object('ok', true, 'purged', v_done, 'blocked', v_stuck);
end $$;
revoke all on function public.account_integrity_purge_due(text) from public, anon, authenticated;
grant execute on function public.account_integrity_purge_due(text) to service_role;

notify pgrst, 'reload schema';

-- Verify (read-only):
-- select user_id, state, export_until, purge_after from public.account_integrity where state = 'blocked' order by purge_after;
-- select * from public.account_integrity_tombstones order by id desc limit 5;
-- select user_id, at, detail from public.account_integrity_log where event = 'purge_blocked' order by id desc limit 5;

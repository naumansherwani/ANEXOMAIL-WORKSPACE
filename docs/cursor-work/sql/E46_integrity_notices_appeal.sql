
-- E46 — warn/block par EMAIL + 24 ghante pehle yaad-dihani + purge ka notice + in-app APPEAL — Blueprint G36/G37 — 20 Oct 2026
--
-- Loophole jo audit mein mila: warn/block ki khabar user ko sirf screen par milti thi (email nahi), aur appeal ke liye user se "device hash" maanga
-- jata tha jo use pata hi nahi hota. Ab:
--   * account_integrity_notices   — outbox (sirf service_role). Trigger: state warned/blocked hote hi notice banta hai (phase24a ke functions ko haath nahi lagaya).
--   * account_integrity_notice_claim(_limit)  — worker ke liye pending notices (+ 24h reminder khud banata hai); notice_done(_id,_ok,_err)
--   * account_integrity_appeal(_user,_statement) — user ke apne banned devices par appeal (device_appeal_open se), hash user ko nahi chahiye
--   * account_deletions_email_hmac_migrate(_key) — E24 ka purana SHA-256 email_hash -> HMAC (HASHING.md section 4)
--   * purge_due ab purge se pehle "deleted" notice bhi queue karta hai (E45 ka naya version isi file mein)
-- Bhejne ka kaam: docs/cursor-work/server/integrity-purge/anexomail-integrity-notify.py (har 5 minute, local Postfix 127.0.0.1:25, DKIM).
-- PEHLE: phase24a, phase23 (device_appeal_open), E24, E45. Dobara chalana safe.
set search_path = public, extensions;

create table if not exists public.account_integrity_notices (
  id           bigserial primary key,
  subject_user uuid not null,                 -- NAAM JAAN-BOOJH kar user_id nahi: account_purge user_id wali rows mita deta hai, "purged" notice bachna chahiye
  kind         text not null check (kind in ('warned','blocked','reminder_24h','purged')),
  to_addrs     text[] not null default '{}',
  subject      text not null,
  body         text not null,
  created_at   timestamptz not null default now(),
  claimed_at   timestamptz,
  sent_at      timestamptz,
  attempts     int not null default 0,
  last_error   text
);
create index if not exists account_integrity_notices_pending on public.account_integrity_notices (created_at) where sent_at is null;
alter table public.account_integrity_notices enable row level security;
revoke all on public.account_integrity_notices from public, anon, authenticated;
grant all on public.account_integrity_notices to service_role;
grant usage, select on sequence public.account_integrity_notices_id_seq to service_role;

-- user ke pate: login email + (agar hai) recovery_email
create or replace function public._ai_notice_addrs(_user uuid)
returns text[] language plpgsql stable security definer set search_path = public, extensions as $$
declare a text[] := '{}'; v text;
begin
  select lower(u.email) into v from auth.users u where u.id = _user;
  if v is not null then a := a || v; end if;
  if to_regclass('public.trial_accounts') is not null and public._ae_has_col('trial_accounts', 'recovery_email') then
    execute 'select lower(btrim(t.recovery_email)) from public.trial_accounts t where t.user_id = $1' into v using _user;
    if v is not null and v <> '' and position('@' in v) > 1 and not (v = any(a)) then a := a || v; end if;
  end if;
  return a;
end $$;

create or replace function public._ai_notice_enqueue(_user uuid, _kind text, _reason text, _export_until timestamptz)
returns bigint language plpgsql security definer set search_path = public, extensions as $$
declare
  addrs text[] := public._ai_notice_addrs(_user);
  subj  text; body text; nid bigint;
  why   text := coalesce(nullif(btrim(_reason), ''), 'Repeated account-integrity violations.');
  until_txt text := case when _export_until is null then '' else to_char(_export_until at time zone 'UTC', 'YYYY-MM-DD HH24:MI') || ' UTC' end;
begin
  if cardinality(addrs) = 0 then return null; end if;
  if _kind = 'warned' then
    subj := 'ANEXOMAIL — final warning on your account';
    body := 'This is the one written final warning on your ANEXOMAIL account.' || E'\n\n' ||
            'Reason: ' || why || E'\n\n' ||
            'If this happens again, the account will be blocked. A block is placed on the device record only — never on your address or network — and it can be appealed.' || E'\n\n' ||
            'If you think this is a mistake, reply to resolved@anexomail.com.';
  elsif _kind = 'blocked' then
    subj := 'ANEXOMAIL — your account is blocked: download your data';
    body := 'Your ANEXOMAIL account has been blocked after a final warning.' || E'\n\n' ||
            'Reason: ' || why || E'\n\n' ||
            'You can download everything — mail, attachments, contacts and calendar — until ' || until_txt || '. Sign in and choose "Download all my data".' || E'\n' ||
            'After that, the account and its data are permanently deleted, as our Privacy policy says.' || E'\n\n' ||
            'To appeal, sign in and use the appeal form on the blocked screen, or reply to resolved@anexomail.com before the window ends.';
  elsif _kind = 'reminder_24h' then
    subj := 'ANEXOMAIL — 24 hours left to download your data';
    body := 'Your blocked ANEXOMAIL account will be permanently deleted at ' || until_txt || '.' || E'\n\n' ||
            'Sign in and choose "Download all my data" now if you still need your mail, attachments, contacts or calendar. After deletion nothing can be recovered.' || E'\n\n' ||
            'To appeal, reply to resolved@anexomail.com before the window ends.';
  else
    subj := 'ANEXOMAIL — your account and data have been deleted';
    body := 'The 72-hour export window on your blocked ANEXOMAIL account has ended and the account and its data have been permanently deleted.' || E'\n\n' ||
            'The block stays on the device record only and can still be appealed: write to resolved@anexomail.com.';
  end if;
  insert into public.account_integrity_notices (subject_user, kind, to_addrs, subject, body)
  values (_user, _kind, addrs, subj, body) returning id into nid;
  return nid;
end $$;

-- state badalte hi notice (phase24a ke warn/block functions jaise hain waise)
create or replace function public._ai_notice_trigger()
returns trigger language plpgsql security definer set search_path = public, extensions as $$
begin
  begin
    if new.state = 'warned' and old.state is distinct from 'warned' then
      perform public._ai_notice_enqueue(new.user_id, 'warned', new.reason, null);
    elsif new.state = 'blocked' and old.state is distinct from 'blocked' then
      perform public._ai_notice_enqueue(new.user_id, 'blocked', new.reason, new.export_until);
    end if;
  exception when others then null;   -- notice ki galti block/warn ko kabhi na roke
  end;
  return new;
end $$;
drop trigger if exists account_integrity_notice_trg on public.account_integrity;
create trigger account_integrity_notice_trg after update of state on public.account_integrity
  for each row execute function public._ai_notice_trigger();

create or replace function public.account_integrity_notice_claim(_limit int default 20)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare r record; out jsonb := '[]'::jsonb; ids bigint[] := '{}';
begin
  -- 24 ghante bache hain: ek hi baar reminder
  for r in
    select i.user_id, i.reason, i.export_until from public.account_integrity i
     where i.state = 'blocked' and i.purged_at is null and i.export_until is not null
       and i.export_until > now() and i.export_until <= now() + interval '24 hours'
       and not exists (select 1 from public.account_integrity_notices n where n.subject_user = i.user_id and n.kind = 'reminder_24h')
  loop
    perform public._ai_notice_enqueue(r.user_id, 'reminder_24h', r.reason, r.export_until);
  end loop;

  for r in
    select n.id from public.account_integrity_notices n
     where n.sent_at is null and n.attempts < 5 and (n.claimed_at is null or n.claimed_at < now() - interval '10 minutes')
     order by n.id limit least(greatest(coalesce(_limit, 20), 1), 100)
     for update skip locked
  loop
    update public.account_integrity_notices set claimed_at = now(), attempts = attempts + 1 where id = r.id;
    ids := ids || r.id;
  end loop;
  select coalesce(jsonb_agg(jsonb_build_object('id', n.id, 'to', to_jsonb(n.to_addrs), 'subject', n.subject, 'body', n.body) order by n.id), '[]'::jsonb)
    into out from public.account_integrity_notices n
   where n.id = any(ids);   -- sirf is call mein claim hue (dobara chalne par double-send nahi)
  return jsonb_build_object('ok', true, 'notices', out);
end $$;

create or replace function public.account_integrity_notice_done(_id bigint, _ok boolean, _err text default null)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
begin
  if _ok then
    -- bhejne ke baad pate mita do (PII nahi rakhni); matn mein sirf wajah hai
    update public.account_integrity_notices set sent_at = now(), to_addrs = '{}', last_error = null where id = _id;
  else
    update public.account_integrity_notices set last_error = left(coalesce(_err, 'unknown'), 300) where id = _id;
  end if;
  return jsonb_build_object('ok', true);
end $$;

-- user ka apna appeal: us ke banned devices par (device hash user ko dikhana nahi padta)
create or replace function public.account_integrity_appeal(_user uuid, _statement text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare h text; res jsonb; opened int := 0; last_err text; first_id uuid;
begin
  if _user is null then raise exception 'user_required'; end if;
  if not exists (select 1 from public.account_integrity where user_id = _user and state in ('blocked','warned','purged')) then
    return jsonb_build_object('ok', false, 'error', 'nothing_to_appeal');
  end if;
  for h in select distinct v.device_hash from public.device_vault v
             join public.device_bans b on b.device_hash = v.device_hash and b.appealable
            where v.user_id = _user
  loop
    res := public.device_appeal_open(_user, h, _statement);
    if coalesce((res->>'ok')::boolean, false) then
      opened := opened + 1; first_id := coalesce(first_id, (res->>'appeal_id')::uuid);
    else last_err := res->>'error'; if last_err = 'statement_required' then return res; end if;
    end if;
  end loop;
  if opened = 0 then
    return jsonb_build_object('ok', false, 'error', coalesce(last_err, 'no_appealable_ban'),
      'message', case when last_err = 'appeal_already_open' then 'Your appeal is already with a reviewer.' else 'No appealable device block found on this account.' end);
  end if;
  return jsonb_build_object('ok', true, 'appeal_id', first_id, 'devices', opened);
end $$;

-- E24 ka purana email_hash (SHA-256) -> HMAC (HASHING.md 4)
alter table public.account_deletions add column if not exists email_hmac text;
create or replace function public.account_deletions_email_hmac_migrate(_key text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare n bigint;
begin
  if coalesce(_key, '') = '' then raise exception 'key_required'; end if;
  update public.account_deletions d set email_hmac = public.email_hmac_v1(d.email, _key)
   where d.email_hmac is null and d.email is not null;
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'migrated', n);
end $$;

-- E45 ka purge_due: ab purge se pehle "deleted" notice bhi (rollback ho to notice bhi wapas)
create or replace function public.account_integrity_purge_due(_key text default null)
returns jsonb language plpgsql security definer
set search_path = public, extensions as $$
declare
  r public.account_integrity; v_email text; v_rep jsonb; v_tl jsonb; v_done int := 0; v_stuck int := 0;
begin
  for r in
    select * from public.account_integrity
     where state = 'blocked' and purge_after is not null and purge_after < now() and purged_at is null
     order by purge_after limit 25
  loop
    select lower(u.email) into v_email from auth.users u where u.id = r.user_id;
    if v_email is null then
      update public.account_integrity set state = 'purged', purged_at = now(), updated_at = now() where user_id = r.user_id;
      continue;
    end if;
    if to_regclass('public.chat_messages') is not null then delete from public.chat_messages where sender_user_id = r.user_id; end if;
    if to_regclass('public.chat_work_items') is not null then delete from public.chat_work_items where owner_user_id = r.user_id or created_by = r.user_id; end if;

    select coalesce(jsonb_agg(jsonb_build_object('event', l.event, 'at', l.at, 'actor', l.actor, 'reason', l.reason) order by l.id), '[]'::jsonb)
      into v_tl from public.account_integrity_log l where l.user_id = r.user_id;
    begin
      perform public._ai_notice_enqueue(r.user_id, 'purged', r.reason, r.export_until);   -- pate user mitne se pehle utha liye
      alter table public.account_integrity_log disable trigger account_integrity_log_no_change;
      v_rep := public.account_purge(r.user_id, false, true, false);
      alter table public.account_integrity_log enable trigger account_integrity_log_no_change;
      if not coalesce((v_rep->>'ok')::boolean, false) then
        raise exception 'purge_not_ok' using detail = v_rep::text;   -- notice + trigger wapas (rollback)
      end if;
    exception when others then
      if sqlerrm = 'purge_not_ok' then null;
      else v_rep := jsonb_build_object('ok', false, 'error', 'purge_exception', 'detail', sqlerrm); end if;
      if v_rep is null or coalesce((v_rep->>'ok')::boolean, false) then v_rep := jsonb_build_object('ok', false, 'error', 'purge_not_ok'); end if;
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

do $$
declare f text;
begin
  foreach f in array array[
    'public._ai_notice_addrs(uuid)', 'public._ai_notice_enqueue(uuid,text,text,timestamptz)',
    'public.account_integrity_notice_claim(int)', 'public.account_integrity_notice_done(bigint,boolean,text)',
    'public.account_integrity_appeal(uuid,text)', 'public.account_deletions_email_hmac_migrate(text)',
    'public.account_integrity_purge_due(text)']
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

notify pgrst, 'reload schema';
-- Verify: select kind, subject, sent_at, attempts, last_error from public.account_integrity_notices order by id desc limit 10;

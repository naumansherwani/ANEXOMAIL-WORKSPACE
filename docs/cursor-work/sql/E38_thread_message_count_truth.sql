
-- E38 — thread ki "kitni mails" ginti hamesha sach — 20 Oct 2026 (Basic live login: ek mail wale thread par "2" likha tha)
--
-- Kyun: live database mein naya mail_threads row khud message_count = 1 se shuru hota hai, phir `mail_ingest` +1 karta hai => 2.
-- Website se bheji mail (Bun `/send`) aur queue worker `message_count = 1` LIKH dete hain — reply par bhi (2, 3, 4 ... kabhi nahi).
-- Har raasta apna hisaab rakhta tha; is liye list mein ginti galat.
--
-- Hal (ek jagah, har raasta khud theek): mail_messages par AFTER INSERT/DELETE/UPDATE OF thread_id trigger — jis thread ki
-- mail aaye/jaye us ki ginti `count(*)` se dobara (statement-level, transition tables: ek statement mein 1000 mails bhi ho to
-- har thread ek hi dafa). Purane saare threads ki ginti bhi ek dafa theek. Kisi mail, kisi org ka data nahi badalta — sirf ginti.
-- Supabase SQL Editor-safe (koi psql \-command, koi temp table nahi). Dobara chalana safe. Fail => poora rollback.
-- Server se: . /etc/anexomail/sync.env && psql "$WORKING_URL" -v ON_ERROR_STOP=1 -f E38_thread_message_count_truth.sql
begin;
select pg_advisory_xact_lock(hashtext('E38_thread_message_count_truth'));

do $$
begin
  if to_regclass('public.mail_messages') is null or to_regclass('public.mail_threads') is null then
    raise exception 'E38: mail_messages / mail_threads nahi';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'mail_threads' and column_name = 'message_count') then
    raise exception 'E38: mail_threads.message_count nahi';
  end if;
end $$;

create index if not exists mail_messages_thread_id_idx on public.mail_messages (thread_id);

create or replace function public.mail_thread_recount_ins() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.mail_threads t
     set message_count = (select count(*) from public.mail_messages m where m.thread_id = t.id)
   where t.id in (select distinct thread_id from new_rows where thread_id is not null);
  return null;
end $$;

create or replace function public.mail_thread_recount_del() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.mail_threads t
     set message_count = (select count(*) from public.mail_messages m where m.thread_id = t.id)
   where t.id in (select distinct thread_id from old_rows where thread_id is not null);
  return null;
end $$;

create or replace function public.mail_thread_recount_upd() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.mail_threads t
     set message_count = (select count(*) from public.mail_messages m where m.thread_id = t.id)
   where t.id in (select thread_id from new_rows where thread_id is not null
                  union select thread_id from old_rows where thread_id is not null);
  return null;
end $$;

drop trigger if exists mail_thread_recount_ins on public.mail_messages;
create trigger mail_thread_recount_ins after insert on public.mail_messages
  referencing new table as new_rows for each statement execute function public.mail_thread_recount_ins();
drop trigger if exists mail_thread_recount_del on public.mail_messages;
create trigger mail_thread_recount_del after delete on public.mail_messages
  referencing old table as old_rows for each statement execute function public.mail_thread_recount_del();
drop trigger if exists mail_thread_recount_upd on public.mail_messages;
create trigger mail_thread_recount_upd after update on public.mail_messages
  referencing old table as old_rows new table as new_rows for each statement execute function public.mail_thread_recount_upd();

-- Postgres: transition tables wale trigger ke baad koi aur statement-trigger thread ki ginti phir likhe (Bun `message_count: 1`)
-- to bhi woh "update mail_threads" hai — us ke liye mail_threads par chhota BEFORE UPDATE guard: message_count ko
-- haath se likhna ho to bhi asli ginti hi rehti hai (sirf jab koi message_count badalne ki koshish kare).
create or replace function public.mail_thread_count_guard() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.message_count is distinct from old.message_count then
    new.message_count := (select count(*) from public.mail_messages m where m.thread_id = new.id);
  end if;
  return new;
end $$;
drop trigger if exists mail_thread_count_guard on public.mail_threads;
create trigger mail_thread_count_guard before update of message_count on public.mail_threads
  for each row execute function public.mail_thread_count_guard();

-- self-test (sab wapas): naya thread + 1 mail => 1; doosri mail => 2; Bun jaisa "message_count = 1" likhna => 2 hi rahe; 1 delete => 1
do $$
declare
  v_org uuid;
  v_t   uuid;
  v_n   integer;
begin
  begin
    select org_id into v_org from public.mail_threads where org_id is not null limit 1;
    if v_org is null then raise exception 'E38_SELFTEST_OK'; end if;
    insert into public.mail_threads (org_id, mailbox_address, subject, folder, message_count, last_message_at)
      values (v_org, 'e38-selftest@invalid.anexomail.com', 'E38 selftest', 'inbox', 0, now()) returning id into v_t;
    insert into public.mail_messages (org_id, thread_id, direction, from_address, subject, body_text, sent_at)
      values (v_org, v_t, 'in', 'a@x.com', 'E38', 'x', now());
    select message_count into v_n from public.mail_threads where id = v_t;
    if v_n <> 1 then raise exception 'E38 SELFTEST FAIL: 1 mail par ginti % (1 honi chahiye)', v_n; end if;
    insert into public.mail_messages (org_id, thread_id, direction, from_address, subject, body_text, sent_at)
      values (v_org, v_t, 'out', 'b@x.com', 'E38', 'y', now());
    update public.mail_threads set message_count = 1 where id = v_t;   -- Bun /send jaisa
    select message_count into v_n from public.mail_threads where id = v_t;
    if v_n <> 2 then raise exception 'E38 SELFTEST FAIL: 2 mail par ginti % (2 honi chahiye)', v_n; end if;
    delete from public.mail_messages where id = (select id from public.mail_messages where thread_id = v_t limit 1);
    select message_count into v_n from public.mail_threads where id = v_t;
    if v_n <> 1 then raise exception 'E38 SELFTEST FAIL: delete ke baad ginti % (1 honi chahiye)', v_n; end if;
    raise exception 'E38_SELFTEST_OK';
  exception when others then
    if sqlerrm <> 'E38_SELFTEST_OK' then raise; end if;
  end;
end $$;

-- purane saare threads ki ginti ek dafa sach + natija (EK statement)
with fixed as (
  update public.mail_threads t
     set message_count = c.n
    from (select t2.id, (select count(*) from public.mail_messages m where m.thread_id = t2.id) as n from public.mail_threads t2) c
   where c.id = t.id and t.message_count is distinct from c.n
  returning 1
)
select 'triggers' as cheez, (select count(*) from pg_trigger where tgname in ('mail_thread_recount_ins', 'mail_thread_recount_del', 'mail_thread_recount_upd', 'mail_thread_count_guard') and not tgisinternal)::text || ' / 4' as haal
union all select 'self-test', 'PASSED (sab rollback)'
union all select 'galat ginti wale threads theek hue', (select count(*) from fixed)::text;

commit;

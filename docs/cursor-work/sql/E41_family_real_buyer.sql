
-- E41 — family account (Humza, Raana, Masood) ko ASAL BUYER wale raaste par laana — G39 — 20 Oct 2026
--
-- Founder: "family account aur test account main farq hai ... family account special hai lekin in ko treatment same real buyer
-- wali daini hai ... humza ka business pro ko latest technology pe transfer kero".
-- Real buyer / test account (E36) ke har layer ki row yahan family accounts ke liye "ensure" hoti hai.
-- Farq SIRF yeh rehta hai: umar bhar muft (entitlement 10 saal, support_active) aur Billing par "Lifetime access" label (E40).
--
-- KYA NAHI CHHEDTA: auth.users (password/login bilkul nahi), polar-rust-payment, family_accounts ki plan column, kisi aur ki row.
-- Dobara chalana safe (idempotent). Har step apna subtransaction: ek table ki galti baqi ko nahi rokti.
-- Chalane ka tareeqa: Supabase SQL editor mein poori file paste karo, Run. Natija: email | step | result.
-- Sirf ek account: aakhri select mein  ax_family_real_buyer('humzasherwani@anexomail.com')  likho.
-- (psql ka `\set ON_ERROR_STOP` yahan se hata diya: Supabase SQL editor psql nahi hai, 20 Oct 2026 founder ne line 12 mein yehi error dekha)
set search_path = public, extensions;

begin;

create or replace function pg_temp.ax_family_real_buyer(_only text default null)
returns table(email text, step text, result text)
language plpgsql
set search_path = public, extensions, pg_temp
as $f$
declare
  r        record;
  uid      uuid;
  em       text;
  h        text;
  nm       text;
  pl       text;
  kind     text;
  th       text;
  ts       text;
  tp       text;
  oid_     uuid;
  mo       uuid;
  j        jsonb;
  n        int;
  fails    int;
  ent_plan text;
  ent_until timestamptz;
  ws_plan  text;
begin
  if to_regclass('public.family_accounts') is null then
    email := '-'; step := 'RESULT'; result := 'family_accounts table hi nahi hai'; return next; return;
  end if;

  for r in
    select f.email as fe, f.plan::text as fp, u.id as fuid
      from public.family_accounts f
      join auth.users u on lower(u.email) = lower(f.email)
     where _only is null or lower(f.email) = lower(_only)
     order by f.email
  loop
    uid := r.fuid; em := lower(r.fe); h := split_part(em, '@', 1); pl := r.fp; fails := 0;
    email := em;

    -- ───── PEHLE: abhi kya hai (sirf dikhane ke liye) ─────
    begin
      select t.anexomail_handle, t.status::text, t.plan::text into th, ts, tp from public.trial_accounts t where t.user_id = uid;
      select m.org_id into oid_ from public.org_members m where m.user_id = uid limit 1;
      select a.org_id into mo from public.mail_accounts a where lower(a.address) = em limit 1;
      select e.plan::text, e.active_until into ent_plan, ent_until from public.entitlement_state e where e.user_id = uid;
      step := 'BEFORE';
      result := 'family plan=' || pl
        || ' | profile=' || (case when exists (select 1 from public.account_profiles p where p.user_id = uid) then 'ha' else 'NAHI' end)
        || ' | trial row=' || (case when ts is null then 'NAHI' else ts || '/' || coalesce(tp,'-') end)
        || ' | handle=' || coalesce(th, 'NAHI')
        || ' | org=' || (case when oid_ is null then 'NAHI' else 'ha' end)
        || ' | mailbox=' || (case when mo is null then 'NAHI' else 'ha' end)
        || ' | entitlement=' || coalesce(ent_plan, 'NAHI') || ' till ' || coalesce(ent_until::date::text, '-');
      return next;
    exception when others then
      step := 'BEFORE'; result := 'padh nahi saka: ' || sqlerrm; return next;
    end;

    -- ───── 2) profile + role + trial row (asli signup jaisa) ─────
    begin
      select coalesce(nullif(p.legal_name,''), nullif(p.display_name,''), h) into nm from public.account_profiles p where p.user_id = uid;
      nm := coalesce(nm, h);
      kind := case when pl in ('business','business_pro') then 'business' else null end;
      insert into public.account_profiles (user_id, email, legal_name, display_name, preferences, onboarded)
      values (uid, em, nm, nm, case when kind is null then '{}'::jsonb else jsonb_build_object('workspace_kind', kind) end, true)
      on conflict (user_id) do update
        set preferences = case when kind is null then coalesce(account_profiles.preferences, '{}'::jsonb)
                               else jsonb_build_object('workspace_kind', kind) || coalesce(account_profiles.preferences, '{}'::jsonb) end,
            onboarded = true, updated_at = now();
      insert into public.user_roles (user_id, role) values (uid, 'user') on conflict do nothing;
      perform public.ensure_trial_account_row(uid, em, 'email');
      step := '2 profile/role/trial row'; result := 'theek'; return next;
    exception when others then
      fails := fails + 1; step := '2 profile/role/trial row'; result := 'FAIL: ' || sqlerrm; return next;
    end;

    -- ───── 3) address (handle) — asli claim se ─────
    begin
      select t.anexomail_handle into th from public.trial_accounts t where t.user_id = uid;
      if th is not null then
        step := '3 address'; result := coalesce(th,'') || ' pehle se is account ka hai'; return next;
      else
        j := public.trial_claim_address(uid, h);
        if (j->>'ok') = 'true' then
          step := '3 address'; result := h || '@anexomail.com asli claim se mila'; return next;
        else
          fails := fails + 1; step := '3 address'; result := 'FAIL: claim = ' || j::text; return next;
        end if;
      end if;
    exception when others then
      fails := fails + 1; step := '3 address'; result := 'FAIL: ' || sqlerrm; return next;
    end;

    -- ───── 4) organisation + mailbox (family ka domain khali rehta hai: organisations_domain_key global unique) ─────
    begin
      select m.org_id into oid_ from public.org_members m where m.user_id = uid
       order by (coalesce(m.status::text, 'active') = 'active') desc, m.org_id limit 1;
      if oid_ is null then
        perform public.family_workspaces_apply();
        select m.org_id into oid_ from public.org_members m where m.user_id = uid limit 1;
        step := '4 organisation';
        result := case when oid_ is null then 'FAIL: family_workspaces_apply ne org nahi banaya' else 'family_workspaces_apply se banaya' end;
        if oid_ is null then fails := fails + 1; end if;
        return next;
      else
        update public.org_members m set status = 'active'
         where m.org_id = oid_ and m.user_id = uid and coalesce(m.status::text, 'active') <> 'active';
        get diagnostics n = row_count;
        step := '4 organisation'; result := 'pehle se hai' || case when n > 0 then ' (member status dobara active kiya)' else '' end; return next;
      end if;

      if oid_ is not null then
        select a.org_id into mo from public.mail_accounts a where lower(a.address) = em limit 1;
        if mo is null then
          insert into public.mail_accounts (org_id, address) values (oid_, em);
          step := '4 mailbox'; result := em || ' banaya'; return next;
        elsif mo <> oid_ then
          fails := fails + 1; step := '4 mailbox'; result := 'FAIL: ' || em || ' kisi aur organisation ka hai — kuch nahi badla'; return next;
        else
          step := '4 mailbox'; result := em || ' theek'; return next;
        end if;
      end if;
    exception when others then
      fails := fails + 1; step := '4 organisation/mailbox'; result := 'FAIL: ' || sqlerrm; return next;
    end;

    -- ───── 5) plan: asli buyer ki tarah trial_subscribe, phir umar bhar muft (family_grants_apply: 10 saal) ─────
    begin
      select t.status::text, t.plan::text into ts, tp from public.trial_accounts t where t.user_id = uid;
      if ts is distinct from 'active' or tp is distinct from pl then
        perform public.trial_subscribe(uid, pl, 'e41-family-real-buyer');
        step := '5 plan'; result := 'trial_subscribe se ' || pl || ' active kiya (pehle: ' || coalesce(ts,'?') || '/' || coalesce(tp,'-') || ')'; return next;
      else
        step := '5 plan'; result := pl || ' pehle se active'; return next;
      end if;
      perform public.family_grants_apply();
      step := '5 lifetime'; result := 'entitlement 10 saal + support_active (family_grants_apply)'; return next;
      if to_regclass('public.workspace_subscriptions') is not null then
        execute format('update public.workspace_subscriptions set plan = %L, state = ''active'', updated_at = now() where user_id = %L and plan is distinct from %L', pl, uid, pl);
        get diagnostics n = row_count;
        if n > 0 then step := '5 workspace_subscriptions'; result := 'purani galat-plan row theek ki'; return next; end if;
      end if;
    exception when others then
      fails := fails + 1; step := '5 plan'; result := 'FAIL: ' || sqlerrm; return next;
    end;

    -- ───── BAAD MEIN ─────
    select t.status::text, t.plan::text, t.anexomail_handle into ts, tp, th from public.trial_accounts t where t.user_id = uid;
    select e.plan::text, e.active_until into ent_plan, ent_until from public.entitlement_state e where e.user_id = uid;
    step := 'RESULT';
    result := case when fails = 0 then 'OK' else 'KUCH ADHURA (' || fails || ' step)' end
      || ' | trial=' || coalesce(ts,'?') || '/' || coalesce(tp,'-')
      || ' | handle=' || coalesce(th,'-')
      || ' | entitlement=' || coalesce(ent_plan,'-') || ' till ' || coalesce(ent_until::date::text,'-');
    return next;
  end loop;

  if not found then
    email := '-'; step := 'RESULT'; result := 'koi family account (auth.users ke saath) nahi mila'; return next;
  end if;
end
$f$;

select * from pg_temp.ax_family_real_buyer();

commit;

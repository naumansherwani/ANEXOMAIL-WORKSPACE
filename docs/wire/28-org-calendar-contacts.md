# WIRE 28 — org identity + calendar + contacts SQL

Status: **READY** (repo mein hai). **DONE** tab likho jab live paste ke baad dashboard org dikhe, calendar empty-state aaye (NotWired nahi), `/app/people` 500 na de.

Pehle `git pull`, phir **isi tarteeb** se teen files SQL editor mein paste (ya server `sql/run.sh`). Mix nahi, duplicate table nahi — pehle se maujood tables skip ho jati hain.

## STEP 0 — repo latest

```bash
cd /opt/anexomail-web && git pull
```

## STEP 1 — Phase 60 org identity (login ke baad workspace)

Supabase #4 SQL Editor: `sql/phase60_org_identity_repair.sql` poori file paste → Run.

Ya server:

```bash
cd /opt/anexomail-web && bash sql/run.sh sql/phase60_org_identity_repair.sql
```

Verify row: `orgs_rows` / `org_members_rows` numbers aane chahiye, error nahi.

## STEP 2 — Phase 61 calendar + work

```bash
cd /opt/anexomail-web && bash sql/run.sh sql/phase61_calendar_work.sql
```

Verify: `calendar_events_ready` · `work_tasks_ready` · `mail_thread_events_ready` = true.

## STEP 3 — Phase 62 contacts

```bash
cd /opt/anexomail-web && bash sql/run.sh sql/phase62_contacts_intelligence.sql
```

Verify: `contacts_ready` · `rpc_ready` = true.

## STEP 4 — frontend (SQL ke baad; landing/logo touch nahi)

```bash
cd /opt/anexomail-web && bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save
```

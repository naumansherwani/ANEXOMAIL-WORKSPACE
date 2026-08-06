# ANEXOMAIL — Working Agreement + Memory Book Setup (Phase 0)

## Locked rules (memory book)
- Owner: Nauman, founder of Nexatect. This is his 3rd Lovable-built project.
- Stack lock: **Bun · Rust · tRPC · WebTransport · Caddy (HTTP/3)**. No other backend stack unless Nauman changes it.
- Hosting: Nauman's own **Hetzner** server. Domain bought on **Namecheap**, already pointed to Caddy.
- Every project is **100% Supabase-backed**, one dedicated Supabase project per app.
- Role split: I am **only the builder**. All power stays with Nauman.
  - I write frontend + backend code.
  - I hand over **SQL to copy-paste** — I never run migrations myself.
  - I hand over **copy-paste server commands** — Nauman runs them on Hetzner.
  - After each phase: check logs green → `git pull` on server → `pm2 restart`.
- Project size: **30 phases**. GitHub pull after every phase.
- Memory book is the source of truth: before building anything, I read the memory book first.

## Memory book structure (created in Phase 0)
```text
mem://index.md                  Core rules, always applied
mem://~user                     Nauman's working style + communication
mem://project/anexomail-stack   Bun/Rust/tRPC/WebTransport/Caddy + Hetzner + Namecheap
mem://project/workflow          SQL copy-paste, server commands, logs green, git pull, pm2 restart
mem://project/phases            30-phase roadmap + status of each phase
mem://project/blueprint         ANEXOMAIL blueprint + the 2 days of backend work already done
```
Every phase completion updates `mem://project/phases` so nothing is ever re-asked.

## Per-phase delivery format (fixed, every phase)
1. **Scope** — what this phase builds, in plain words.
2. **Frontend** — built in this Lovable project (TanStack Start + React).
3. **Backend** — Rust/Bun code + files, written out for the repo.
4. **SQL block** — one copy-paste block for Supabase SQL editor.
5. **Server commands** — one copy-paste block for Hetzner (git pull, build, pm2, Caddy reload).
6. **Verify** — exact logs/endpoints to check for green.
7. **Memory update** — phase marked done in the memory book.

## What I need from you before Phase 1
- The **ANEXOMAIL blueprint** (or its key pages/features list).
- The **2-day backend report** — what's already deployed on Hetzner (services, ports, Caddy config, pm2 process names, repo URL/branch).
- The **domain** name and the Supabase project for this app (Supabase can be enabled here so I can see tables/policies).

## Technical notes
- The Lovable-hosted frontend runs on TanStack Start; the Rust/Bun/tRPC/WebTransport services run on your Hetzner box behind Caddy HTTP/3. Frontend talks to them over your domain endpoints — I will keep all endpoint config in one env-driven place.
- Supabase stays the single database. Row Level Security on every table, with GRANTs included in every SQL block I give you.
- Nothing is executed by me: SQL and shell always come to you as copy-paste blocks.

## Phase 0 output (after you approve)
- Memory book files written and locked.
- Repo/service map recorded from your 2-day report.
- Phase list (1–30) drafted from the blueprint for your confirmation.

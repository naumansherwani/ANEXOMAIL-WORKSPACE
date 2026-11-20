# QCONNECT: the database next to the server (his word 20 Nov 2026 21:02 PKT: "Qconnect shuru kero")

## Measured (his pastes 20:58 and 21:02, real clock)
- Journal: every database rpc 306-546 ms, including the 5 s background ticks.
- db-latency-check: network to the database front 1-6 ms, FIRST BYTE 318-375 ms on a reused connection => about 320 ms per REST call.
- db-direct-probe: the database host has NO IPv4 address, only IPv6 (2406:da18:...), and a plain TCP connect from his server takes 215-225 ms on 5432 and 6543. That is the real distance (the range looks like AWS Asia Pacific / Singapore). A direct Postgres connection from his server therefore costs at least one 220 ms round trip PER query and more for TLS and login: NOT faster than REST. Direct connection from here is dropped.

## Research (web, 20 Nov 2026)
- Supabase's own note on slow clients: PostgREST itself adds only a few ms; the time is distance + the front. The standing advice for latency is to run the app and the database in the same region. Supabase has no multi-region primary on managed plans (community threads, Supabase regions page).
- Sources: https://supabase.com/docs/guides/troubleshooting/high-latency-with-supabase-client-z0pZzR , https://supabase.com/docs/guides/platform/regions , https://www.github.com/supabase/supabase/discussions/4236
- So only two ways reach 50 ms: (a) the database on his Hetzner server (1 ms), (b) cache and fewer calls so the 320 ms is paid rarely.

## Plan (law: Hetzner, own Rust, Caddy, Namecheap only; no other vendor)
1. This plan + his word: start given 21:02, and at 20 Nov 2026 21:05 PKT his "shuru kero" (21:05) counts as the haan to go on, on ONE condition he set: I check ports and Caddy FIRST (PORT RED LINE). Step 2 below is that check; the installer is written only after his paste.
2. PORT RED LINE: his fresh `ss` paste first; PostgreSQL listens on a UNIX SOCKET only (no TCP port opened).
3. Install PostgreSQL 16 from the OS packages on his server, empty database, roles as in E167 (service_role only doors). sql-run.sh runs the whole E-line on it, strictly by number, every CHECK green.
4. Copy data: pg_dump of the founder tables, then compare row counts + hash chains (ledger verify functions) before any switch.
5. Rust `data.rs`: a second backend behind the same `Sb` interface (pooled tokio-postgres, prepared statements, same RPC names), chosen by an env flag; REST stays as rollback.
6. Cut-over: flag on, journal watched, rollback = flag off (data written after the switch must be copied back first: no switch without a one-way freeze window).
7. Re-measure with db-latency-check.sh (his paste). Target: login under 50 ms server time.
8. Backup law: nightly dump to the Hetzner Storage Box with SHA-256, restore proven once.
## Until step 6: QSPEED code-only wins (login finish as ONE SQL door, writes after the answer, Rust cache) keep running, they pay off on both backends.
## Auth note: the password check still goes to the managed auth service until the Rust signin owns passwords; passkey login does not need it.

## Step 2 DONE 21:06 PKT: his ss + services + disk + ram paste. No port needed (socket only). Ubuntu offers PostgreSQL 18 (newer than 16, so latest-only law holds; the E-line was tested on 16 here, every CHECK on his server proves 18). 22 GB disk free, 12.9 GB RAM available.
## Step 3 WRITTEN 21:10 PKT: docs/cursor-work/server/pg-local-install.sh (cluster NOT auto-created, listen_addresses empty, root peer role, database anexo_founder, compat layer docs/cursor-work/sql/QCONNECT_bootstrap.sql proven idempotent on scratch PG16). It does not touch Caddy, the founder service or its env. Next after his paste: sql-run with ENV_FILE=/etc/anexomail/local-pg.env LEDGER=/var/lib/anexomail/sql-applied-local.tsv (the whole E-line on the new database), then CHECKs.
## AUTH FACT: the founder password sign-in and the session minting still call the managed auth service (gotrue). The local database holds auth stubs only; accounts and password hashes move in step 4 and the Rust signin takes over password + sessions (passkey sign-in needs no password check) before the switch.

## STATUS 22:0x PKT 20 Nov 2026 (written for any Claude after compaction; the order is: rules-read.py, WORKING-NOW.md, this file)
WHERE WE STAND: QCONNECT = the database moves next to the server. NOTHING IS SWITCHED YET: the live site still uses the managed database over REST (about 320 ms per call). All steps below touch only a NEW socket-only PostgreSQL 18 on his server.
- DONE + PROVEN on his server: step 1 plan; step 2 ports (no new listener); step 3 install: PostgreSQL 18.6, unix socket only, listen [], "no postgres TCP listener: OK" (his paste 21:5x); backup full-20261120-164159 (132M, RESTORE.sh inside); step 4 dump+restore: pg-local-copy.sh run 22:0x: dump 12 MB took 661 s (that is the 215-225 ms distance, one more reason to move), restore into anexo_copy: 675 of 677 tables, fmail_messages 34=34, fmail_outbox 13=13, auth.users 16=16.
- FOUND: the E-line alone cannot build a fresh database (E37 needs the phase58 base schema), so the copy is the route. The 2 missing tables are public.leo_memory_vectors + public.ai_memory_vectors (pgvector missing), plus 1 harmless "schema public already exists".
- WRITTEN, waits his run (4b): docs/cursor-work/server/pg-local-vector.sh (installs postgresql-18-pgvector, restores those 2 tables only).
- NEXT (not written yet): 5 hash-chain compare on anexo_copy (the ledger verify functions) + a final delta copy at switch time; 6 Rust data.rs Postgres backend (pooled tokio-postgres, same Sb interface, env flag, REST stays as rollback); 7 Rust signin owns passwords + sessions (accounts/password hashes are in the copy, the gotrue call goes away); 8 switch with a freeze window and rollback; 9 re-measure with db-latency-check.sh (target login under 50 ms); 10 nightly dump to the Hetzner Storage Box with SHA-256, restore proven once.
- QSPEED code-only wins that run meanwhile: E197 login finish as ONE SQL door (read E153/E167/passkey schema first, SQL SCHEMA-FIRST law), writes after the answer, network-only retry, Rust cache.
- NOT green: QCONNECT as a phase (nothing is wired into the running service). QC7 reminder + sealed draft = GREEN (earlier).
- Auto checkpoint: ckpt-loop.sh runs every 2 minutes in the sandbox (restart it with: nohup bash docs/cursor-work/server/ckpt-loop.sh &); the PreCompact hook also checkpoints.

## STEP 4b DONE 22:0x PKT 20 Nov 2026 (his pg-local-vector paste): pgvector 0.8.1, restore exit 0 with 0 errors, tables local 677 = managed 677, leo_memory_vectors 0 rows, ai_memory_vectors 2 rows, functions local 1520. The copy anexo_copy is now table-complete.
## HIS WORD 22:06 ON THE STORAGE BOX: "yeh mere storage box pe wazan nahi aye" = NO nightly database dump to the Hetzner Storage Box (it must not carry weight). Step 10 CHANGED: the nightly dump stays on his server only, compressed, last 7 kept (rotation), SHA-256 beside each; the Storage Box stays for attachments only (Q3). Nothing is ever pushed to the Storage Box for QCONNECT.
## Step 5 WRITTEN 22:1x PKT: docs/cursor-work/server/pg-local-compare.sh (read-only on both sides: per table row count + one md5 over sorted row hashes, differing tables only; then the zero-argument verify functions on the local copy). Rows written by the live site after the dump will differ: expected, closed by the delta copy at switch time.

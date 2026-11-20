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
1. This plan + his word (given 21:02 for the start; install needs his explicit haan, step 3).
2. PORT RED LINE: his fresh `ss` paste first; PostgreSQL listens on a UNIX SOCKET only (no TCP port opened).
3. Install PostgreSQL 16 from the OS packages on his server, empty database, roles as in E167 (service_role only doors). sql-run.sh runs the whole E-line on it, strictly by number, every CHECK green.
4. Copy data: pg_dump of the founder tables, then compare row counts + hash chains (ledger verify functions) before any switch.
5. Rust `data.rs`: a second backend behind the same `Sb` interface (pooled tokio-postgres, prepared statements, same RPC names), chosen by an env flag; REST stays as rollback.
6. Cut-over: flag on, journal watched, rollback = flag off (data written after the switch must be copied back first: no switch without a one-way freeze window).
7. Re-measure with db-latency-check.sh (his paste). Target: login under 50 ms server time.
8. Backup law: nightly dump to the Hetzner Storage Box with SHA-256, restore proven once.
## Until step 6: QSPEED code-only wins (login finish as ONE SQL door, writes after the answer, Rust cache) keep running, they pay off on both backends.
## Auth note: the password check still goes to the managed auth service until the Rust signin owns passwords; passkey login does not need it.

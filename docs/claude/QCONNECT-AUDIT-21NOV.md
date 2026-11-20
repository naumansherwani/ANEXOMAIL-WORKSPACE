# QCONNECT DEEP AUDIT, 21 Nov 2026 00:55 PKT (his order 00:44: "deep audit, report, auto-fix loopholes, laws not broken")
Sources: his live Chrome tab (read-only Performance API + screenshot, 00:42), his server pastes (pg-local-run198, founder-install, qconnect-switch-prep), the repo code. Nothing guessed; unknown = said unknown.

## A. What technology RUNS right now on his live site (proof)
- HTTP/3 (QUIC): 14 of 18 page resources arrived on h3 (JS chunks, three.webgpu/core/tsl, gsap, kernel.worker, icons). Dashboard line: "Answers verified, HTTP/3 QUIC, Browser key, ML-DSA-65", 11 of 11 endpoints, 2/2 checks.
- Rust WASM kernel: kernel.worker JS loaded over h3 (a separate .wasm entry was not seen: "running" NOT claimed beyond the worker load).
- Three.js WebGPU + GSAP + React 19 UI: loaded. WebAssembly and WebTransport exist in the browser (availability only, not proof of a session).
- Founder service (Rust axum/tokio): alive, healthz 200, me/bridge without token 401 (his founder-install paste).
- Database: managed Supabase over REST (about 320 ms per call). NOT local. FOUNDER_DB flag is OFF.
## B. What QCONNECT built and where it stands (7 of 10 proven on his server, phase OPEN)
- Installed on his server, switched OFF: PostgreSQL 18 (unix socket only, 0770, group anexopg, 0 TCP listeners), full copy 677/677 tables, Rust engine pg.rs (tokio-postgres + deadpool, catalog-driven rpc, 139 us per rpc in the sandbox), identity engine localid.rs (bcrypt on a blocking thread, decoy hash for absent accounts, ES256 kid lid1, refresh rotation with reuse kill, hash-chained founder_localid_events), LOCAL_E198 doors 7/7 selftest 10/10.
- Step 8a prep done on his server (role anexomail-founder, key file, service_role grants, smoke test as the service user, drift list). Step 8b switch NOT run (on hold until his explicit go).
## C. LOOPHOLES FOUND (this audit) and what was done
1. FIXED (code): data.rs with_local defaulted FOUNDER_PG_URL to the EMPTY compat database anexo_founder; a missing URL would have served empty answers. Now no URL (or not a unix-socket url) = stay on REST.
2. FIXED (switch script): a killed ssh while the founder service is stopped would leave his site down; an EXIT trap now restarts it on REST. Cleared only after the proof passes.
3. FIXED (switch script): an env file without a final newline would glue FOUNDER_DB=local onto the last old line; a newline is added first.
4. FIXED earlier tonight: copy had no grants (service_role only now), socket group (postgres + service user), QCONNECT_bootstrap guard against managed Supabase.
5. ACCEPTED, written down: auth.refresh_tokens keeps the token in clear text because the legacy gotrue shape is kept for rollback (gotrue does the same); mitigated: anon/authenticated have no grants on anexo_copy, only root and the service via the 0770 socket group reach it. Revisit with a hashed-token column in a later SQL.
6. OPEN, needs a read-only check first (law 3): 4 Inter woff2 fonts came over HTTP/1.1, not h3. Cause NOT known (could be the first connection before the browser learns h3, or the font path). Not fixed by guess.
7. OPEN: after the switch, founder writes go to the local database only; REST rollback loses them (reverse copy = his decision). Tables the awam site writes can be stale locally (the switch lists them as WARN).
8. OPEN: AES-256 and X25519MLKEM768 are written on the dashboard but not proven by me; the proof is Chrome's security panel or an openssl s_client paste from his server.
9. OPEN: dashboard shows "4 requests blocked in the last 24 h" in red; not yet looked at.
10. After the switch he must sign in once again (the local JWKS verifies only kid lid1).
## D. Laws checked: port red line (no new listener, socket only), vendor ban (none), no Storage Box dump, SQL schema-first (E198 written on the read auth schema), Aap only, no mock data, REST fallback kept for ever.

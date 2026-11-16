# SYS-LIVE: the LIVE heartbeat on Systems (his order 16 Nov 2026 07:09 PKT: "heartbeat purana hai, auto update, live chale, duniya ka advance system, research detail, phir codes, subphase mein, time date ke saath")

## The problem (found, not guessed)
The Systems "Heartbeat" card is written by brain.py at BUILD time ("Written 16 Nov 06:54 from the repo"). It is a photograph of the repo, so it is old the moment it is built and it can never say what the SERVER is doing now. A page that shows an old time as if it were the state is the exact thing the industry calls a frozen exporter: HTTP 200, data frozen.

## Research (what the field does; sources read 16 Nov 07:10)
- Heartbeat / dead-man's-switch monitors (checkly, rootly, oneuptime, wizstatus guides, "failure detection" notes): the thing being watched must SEND a beat with its own timestamp; the watcher alerts on SILENCE, not on an error. Absence is a signal.
- Prometheus staleness + "healthy zero vs missing/frozen" (robustperception staleness note, oneuptime freshness posts): a number without its own timestamp cannot tell fresh from frozen; the payload must carry its own clock and the viewer must compute the age.
- Google SRE golden signals (latency, traffic, errors, saturation): a health view shows signals, not a green dot.
- Kubernetes style split: liveness (process alive) vs readiness (can do its job: database answers, sender can send). Two different words on the screen.
- Failure detectors in distributed systems (phi-accrual idea): decide "late" and "lost" from the observed gap between beats, not from one fixed second count.
## Design (advance, honest, every layer)
1. **Rust (Tokio, axum)** `heartbeat.rs`: GET /founder/v1/system/heartbeat, kernel-signed answer (same signed-door technology as every founder door), carries the SERVER clock: server_ms, monotonic seq, process uptime, the build running NOW (commit + install time from a stamp the installer writes), the newest repo commit this server has seen (read from the local git refs, no network), live-tick health (ok, age, version), database answer time, sender switch (E182). Nothing guessed: a missing source is `null`, shown as "unknown".
2. **PostgreSQL**: no new table for the beat itself (it is a read). The build stamp is a file written by the installer (founder-install.sh) so "what runs" is proven by the server, not by the page.
3. **WASM kernel / WebTransport**: the page reads it through the existing kernel RPC session (same path as every founder API call); a bad signature is dropped and counted, never shown.
4. **React 19 TS** `LiveHeartbeat.tsx`: polls every 5 s while the tab is visible (pauses when hidden), computes age from the SERVER clock offset (not the laptop clock), ticks a local second counter, and shows THREE honest states: LIVE (beat younger than 2 x interval), LATE (younger than 6 x), LOST (silence: red, "no signed beat for 31 s"). Shows date+time with seconds in PKT, and "running commit X, installed 07:31" next to "newest repo commit seen Y": equal = "matches the repo", different = "repo is ahead: run founder-install".
5. **Installer**: founder-install.sh writes /opt/anexomail-founder/build-stamp.json (commit = origin/main it installed, installed_ms, bundle name). Optional step 2 (his word first): a 60 s git-fetch timer so "newest repo commit seen" is fresh without his command.
## Order inside the sub-phase (one command at a time for him)
- SYS-LIVE-1 (me, repo): Rust door + tests, installer stamp, UI component, contract, ledger. cargo + tsc + sandbox look.
- SYS-LIVE-2 (him): founder-install (one line). Then my live Chrome look: age counts up 0..5 s and resets; stop the proof by blocking? (no: LOST is proven by a unit test + a Chrome look with the door answer withheld in the page test hook, never by breaking his server).
- SYS-LIVE-3 (optional, his word): git-fetch timer.
GREEN only with: his install paste + my Chrome look at 1536 + the age visibly resetting + 390/820 sandbox measurement. TECH-LAW CHECKED.


## BUILT 16 Nov 07:20 (what is in the repo; one plan, merged)
### As built
1. Rust `pulse.rs` + route GET /founder/v1/system/pulse (authed, Ed25519-signed envelope, the WASM kernel verifies): server now_ms, started_ms, uptime_s, build commit + build time (build.rs + founder-install exports ANX_BUILD / ANX_BUILD_TIME), Tokio workers / alive tasks / queue depth, DB round trip ms (real call), outgoing-mail switch state. Unreadable value = null, never 0.
2. React `PulseCard.tsx`: asks every 5 s (paused while the tab is hidden), server clock offset from the signed body so the clock ticks per second by itself, badge Live / Stale after 12 s / Waiting. Mounted on Systems above the (renamed) Repo heartbeat, which now says it is written at build time.
3. Tests: cargo (pure body, honest nulls, no-DB read), bun (badge state, uptime words), tsc.
## Later (not now, own steps)
- pushed pulse frame over flive@1 (no polling), SLO burn card from QPERF, tokio_unstable metrics (mean poll duration) when his server build flags allow, build vs repo-newest drift line (install writes origin/main head).
## Proof needed for GREEN
his sql-less install (founder-install only, no SQL), then my live Chrome: Live badge, ticking server clock, build = the installed commit, DB ms, Stale seen when the door is blocked.

### Extra research read for the build
- SSE vs WebTransport 2026 (laramateo.com): one-way = SSE, but OUR LAW is HTTP/3 + WebTransport only, so the page uses the signed kernel RPC door every 5 s now; a pushed flive@1 frame is the later upgrade.
- Tokio runtime health (oneuptime.com / tokio-metrics): stable RuntimeMetrics num_workers, num_alive_tasks, global_queue_depth are used; unstable ones need --cfg tokio_unstable (not used).
- Kept from the plan above: the beat carries the SERVER clock + a monotonic seq (added), the badge is computed by the viewer from the age (Live / Stale after 12 s), liveness (process answered) is shown apart from readiness (database answered, sending switch).

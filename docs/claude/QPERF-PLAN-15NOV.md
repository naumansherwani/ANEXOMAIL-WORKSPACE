# QPERF PLAN (written 15 Nov 2026 22:3x PKT, BEFORE any code; his order: "phase plan do, SQL ~400 lines, advance technology, research karke"; STATE: WAITS HIS HAAN)
GOAL: the founder sees how fast his mail really is (p50, p90, p95, p99, p99.9 per stage) and whether the speed promise is being kept (SLO burn), measured on his own server, nothing invented.
WHAT IS MEASURED (Rust, `fmail_in.rs`, `Instant` already used at line ~187): accept (RCPT to end of DATA), scan (clam_scan), seal (AES-256-GCM + ML-KEM wrap), commit (the SQL deliver door), total. Only durations, outcome class and size bucket are stored: NO address, NO subject, NO mail id (privacy by design).
RESEARCH (sources): Google SRE workbook multi-window multi-burn-rate alerting, as laid out at https://grafana.com/blog/2025/02/28/how-to-implement-multi-window-multi-burn-rate-alerts-with-grafana-cloud/ : burn 14.4 on 1h AND 5m, burn 6 on 6h AND 30m (for a 99.9% SLO); the third tier (burn 1, 3d AND 6h) is from the same book and was NOT re-fetched here. HDR Histogram idea (log-linear buckets, bounded relative error, mergeable) for long windows; exact `percentile_cont` over raw samples for short windows.
ADVANCE TECHNOLOGY: PostgreSQL 16 declarative range partitions (one per day) + BRIN on ts, append-only triggers, daily SEAL rows (count + SHA-256 over the ordered samples + previous seal = tamper-evident without one hash per sample), per-minute HDR-style histogram rollup (2 significant digits = at most 1 percent error), exact percentiles via percentile_cont for the last 24 h, multi-window multi-burn-rate SLO function, security-definer doors (service_role only, fixed search_path), forced RLS. Rust Tokio: bounded mpsc channel, a batch writer every 2 s (max 500 samples per rpc), the mail path NEVER waits for it, overflow is counted and shown (honest). Bridge: ONE additive card "Mail speed" (new file + one-line mount, existing UI untouched), signed door over the kernel WebTransport RPC (HTTP/3).
SQL E174 (about 400 lines, one file + CHECK_E174.sql, both tamper-tested in the sandbox PG before they leave):
 1. preflight (E167 ledger present, E102)                                            ~15 lines
 2. closed lists: stage (accept, scan, seal, commit, total), outcome (ok, quarantine, reject, error), size bucket (xs s m l xl)   ~25
 3. `fmail_perf_sample` partitioned by day, BRIN(ts), forced RLS, append-only trigger, CHECK ranges (dur_us 0..3600000000)         ~60
 4. partition manager `fmail_perf_partitions174()` (creates today+2 days, detaches > 35 days, never deletes rows silently)         ~45
 5. ingest door `fmail_perf_ingest174(jsonb)`: validates every element against the closed lists, max 500, one insert, returns counts ~50
 6. daily seal `fmail_perf_seal174(day)`: count + SHA-256 over ordered (ts,stage,dur) + prev seal, append-only chain                ~55
 7. per-minute histogram rollup `fmail_perf_hist` + `fmail_perf_rollup174()` (HDR-style log-linear bucket index, mergeable)          ~60
 8. percentile functions: exact (raw, <= 24 h) and from merged histogram (> 24 h), p50 p90 p95 p99 p99.9                              ~50
 9. SLO table (closed objectives, e.g. 99 percent of mails committed within 5 s) + `fmail_perf_burn174()` 3 tiers, returns ok / ticket / page ~40
10. the read door `fmail_perf_door174(p_window)` jsonb for the Bridge card, service_role only, stable                                 ~25
11. selftest function (rolls back): 12 cases incl. percentile of a known set, burn tiers, tamper of a sample rejected, seal chain    ~60
CHECK_E174: 6 checks (lists closed, append-only holds, seal chain verifies, percentiles of a known synthetic day equal the hand value, burn states, service_role only).
STEPS (each closes with proof, one at a time):
 Q1. E174 + CHECK_E174, sandbox PG proof incl. tamper                                     (his line 1: sql-run AUTO)
 Q2. Rust: `fmail_perf.rs` (channel + batch writer + timing points in fmail_in.rs) + tests (his line 2: founder-install)
 Q3. Rust door `/founder/v1/mail/perf` (closed query: window = 1h 6h 24h 7d) + kernel RPC; React 19 TS additive card "Mail speed" (one new file, one-line mount)
 Q4. my Chrome look at 1200+ and his phone; real mail through the intake (a Postfix selftest mail) so real samples exist; then done.
HONEST LIMITS: p99.9 needs thousands of samples to mean anything; with a handful of mails the card says "too few samples" and shows counts, never a fake number. The SLO targets are proposals: he picks them.

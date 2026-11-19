# QC1c / Qtls: LOOPHOLE LIST + PLAN (19 Nov 2026 11:5x PKT, his order 11:49: "ek bhi loophole nahi chodna")

Status words: DONE = in repo + proven; WRITTEN = in repo, waits his sql-run / install; HIS HANDS = needs him; HAAN = needs his word (UI Law).

## A. F8-3 TLS-RPT (RFC 8460) really sent
| # | Point | State |
|---|---|---|
| A1 | E191 counters per UTC day, result types = the RFC list, domain + MX host sealed | WRITTEN (sandbox selftest 28/28) |
| A2 | counter only grows, identity immutable, 5000 distinct rows per mailbox per day cap (flood), count 1..1000 per call | WRITTEN |
| A3 | the DATABASE picks the day (UTC), the sender can not write into a closed day | WRITTEN |
| A4 | report only after its UTC day ended; one report per (mailbox, day, domain) claimed atomically (advisory lock, claim 10 min) = exactly once | WRITTEN |
| A5 | retry 1 h, 6 h, 24 h, 24 h, then final (5 attempts); outcome sent / no_rua / empty / failed | WRITTEN |
| A6 | hash-chained append-only log (verify door), no names in the log | WRITTEN |
| A7 | counters of finished days purged after 14 days, ledger keeps totals | WRITTEN |
| A8 | Rust: record every delivery attempt result (success or the RFC type) in run_domain | TODO now |
| A9 | Rust: daily worker: due, claim, open sealed rows, build JSON (build_tls_rpt_report), gzip, MIME application/tlsrpt+gzip, subject + file name per RFC 8460 s4, DKIM sign, send through our own strict TLS path, finish | TODO now |
| A10 | Rust: rua = mailto (our send path) ; https rua = POST of the gzip (reqwest, TLS only, 10 s) ; rua list from the _smtp._tls TXT (rpt_rua) ; no rua = state no_rua | TODO now |
| A11 | loophole: a report must never leak mail content or recipient addresses: only domain, MX host, IP, counts | design rule, test in Rust |
| A12 | loophole: report to a domain we never sent to is impossible (counters only come from our own attempts) | by design |
| A13 | loophole: rua address on a DIFFERENT domain than the policy domain = external reporting, RFC 8460 s3 allows it but spam risk: send only mailto/https with TLS-required and max 2 targets per report | TODO in A10 |
| A14 | loophole: a loop (our report triggers their report about our report) : reports are sent with the TLS-RPT sender envelope and are never counted | TODO in A8 |
| A15 | his live proof: needs a domain with a real _smtp._tls record (Gmail publishes one) after a real day ends | HIS DAY 20 NOV |

## B. F8-4 "send only if TLS"
| # | Point | State |
|---|---|---|
| B1 | enforcement today: every hop require_tls = true, no clear-text path at all | DONE (live) |
| B2 | E191 policy: strict by default, loosened_until expires by itself | WRITTEN |
| B3 | loosen needs a CONSUMED passkey grant for mail.tls.loosen (2 min old at most), single use, 1..24 h, reason 8..200, max 3 per 24 h | WRITTEN |
| B4 | tighten any time, no touch | WRITTEN |
| B5 | Rust sender reads the policy; even loosened, MTA-STS enforce and DANE domains stay TLS-only | TODO now |
| B6 | Rust signed door that consumes the passkey grant and calls loosen | HAAN (a UI button; no UI before his haan) |
| B7 | React switch in Settings | HAAN |

## C. Proofs that need something outside the repo
| # | Point | Why open |
|---|---|---|
| C1 | none / refused live | needs a server that offers no STARTTLS / breaks the handshake; no such public test host found yet |
| C2 | DANE on a DNSSEC-signed TLSA domain | needs a real signed domain |
| C3 | received-hint | needs a real arriving mail with a Postfix Received line |
| C4 | phone 390 / tablet 820 screenshots (QC1c, QC3a) | HIS HANDS |

## D. Process loopholes (compaction)
| # | Point | State |
|---|---|---|
| D1 | features/QC1c.json honest: F8-3 todo, F8-4 needs-haan | DONE |
| D2 | ledger / RESUME-POINT / CLAUDE.md top / WORKING-NOW.md after every step | every step via rec.sh + ckpt.sh |
| D3 | every ~2 min match the gates (rules-gate --staged, features.py, manifest-verify) before commit | every commit |

Pull commands for him after E191 is pushed: Founder SQL (E191 runs in AUTO order), then Founder install only after the Rust part is pushed.

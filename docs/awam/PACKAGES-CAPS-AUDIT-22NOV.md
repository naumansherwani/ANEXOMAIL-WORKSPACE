# PACKAGES + CAPS DEEP AUDIT (22 Nov 2026 03:32 PKT, his order 03:32: "maine caps sab kuch add kerwaya tha")
DECIDED (his word, 7 Nov 22:12, AWAM-PACKAGES-PROPOSAL-07NOV.md section 6 + G4; PENDING-AWAM.md A): Premium 21,000 pounds, 7,000 users, 70 TB, 100 MB, 4 GB chat file, 350 TB pool. Max 125,000 pounds, card unlimited, STRICT 125,000-user cap in backend + SQL, alerts 90/95, no block, 250 TB*, 250 MB*, 10 GB*, 500 TB*. Business Pro attachment 60 MB. His 03:29 pasted note shows Max 105,000: older draft, G4 (125,000) is later; confirm.
RECORDED IN DOCS: yes (proposal, PENDING-AWAM, CLAUDE.md, awam blueprint line, Desk PLAN-PREMIUM-MAX-21NOV).
NOT YET IN CODE / OLD VALUES STILL LIVE (gaps, awam lane, awam files frozen until founder-complete so NOT touched):
1. anexochat/sql/phase61_file_limits_quota.sql line 7, 31, 238: Premium = 21,000 users cap x 400 GB (old). Must become 7,000 users; Max row missing.
2. docs/cursor-work/founder/packages-pricing-v6-2026-10-25.md lines 27, 61, 67: Premium UNLIMITED users, 15 TB (old, superseded; header update exists only for price).
3. docs/packages/README.md line 13: Premium unlimited (old).
4. server/rust/main.rs ~2106: max_file_bytes 4 GB only, no Max 10 GB tier.
5. Max cap 125,000 + 90/95 alert: no SQL, no Rust check, no founder dashboard card (written nowhere as code).
6. Pool alerts 70/85, 100% throttle: no code.
7. Desk: plan rows (R3p) read these values only after his Max price word.

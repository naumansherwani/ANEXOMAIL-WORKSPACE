# GREEN LEDGER — in par DOBARA code NAHI likhna (founder: "yeh codes nahi likhna hai, yeh green hai") — 26 Oct 2026 07:45 PKT
Har line: cheez | kahan | test. Naya Claude: pehle yeh padho, phir docs/packages/<pkg>/NOT-BUILT.md.

## GREEN (server-side asli + test ya SQL self-test)
- Basic limits: 5 users / 3 mailboxes / 15GB pool / 25MB / 1 domain -> E87 (+CHECK_E87), local PG PASS
- Pro limits: 20 users / 10 mailboxes / 300GB pool / 35MB / 3 domains -> E88 (+CHECK_E88), local PG PASS
- Booking links 1/3/20/unlimited -> E88 trigger + Rust book_glue (page_id/new/delete) + UI BookingPage; Rust 57 tests PASS
- Device vault 2/4/10/50 -> chat_phase_entitlements `device_vault` (pehle se)
- Billing card: £40/£105, user cap, pooled storage, seats_used asli -> get_billing_subscription (E87/E88)
- Mail Pro+ (Rust `pro_gate`): snooze, assign (collision guard), templates; + `pro_only_proc`: pre-send scan, follow-ups, snippets, handoff (unit test) ; schedule send (Bun mail-compose `proOnly`); per-thread analytics (Rust main.rs)
- Calendar: Overlap Matrix Pro+ (Rust 403 + UI), meeting cost meter Pro+ (UI), Find-a-time + 1 booking link har package
- Analytics ROUTE gates (plan-surface + `plan-surface.test.ts`)
- CRM base Pro+ (`showCrm`)
- Domains cap 1/3 -> `org_domain_cap` (E15)
## READY (repo + local tests; "green" live test deploy ke baad — Rule 29) — 26 Oct 08:50
- Analytics backend (E89 + Rust + Bun fallback + package gate); meeting cost server gate (Rust cal_glue); flat partner/revenue model; MFA TOTP + magic-link verify; `billing.revenueTruth` (E90); Business price £360 flat (plans.ts, plans.tsx)
- WASM KERNEL 0.2.0 (Rust async Tokio WebTransport; sha256+hmac+sniff+rank+live+rpc) + `/wt/rpc` + kernel-first rpc.ts/live.ts + attachment sniff + chat sha256; KERNEL CONSTITUTION E90 (+CHECK_E90)
- `python3 scripts/wire-audit.py`: 0 REAL GAP (HELD = AI billing/knowledge, COMING SOON)
## NOT GREEN -> docs/packages/*/NOT-BUILT.md
- Personal (HOLD), Business/Business Pro/Enterprise features (agle phases), live tests (deploy ke baad), Caddy udp/3443 /wt/rpc check

## LIVE GREEN (Basic, 26 Oct 09:15, Rule 29: browser mein tested)
- Analytics gates server par (responseDebt 200; threadEconomics/deepWork/leaks/promise/forecast/team 403) — HTTP + WebTransport
- Kernel 0.2.0: wasm hash pin, QUIC /wt/rpc, kernel.ticket/report, constitution policy (ok/upgrade/block)
- Meeting cost Basic = null; founder-only procs 403
## LIVE NOT GREEN
- MFA UI (Brain mein routes nahi: brain-kernel-install.sh), Pro-side positive tests (Pro account chahiye), kernel in-app rpcUp (anexoKernel Web pull ke baad dekhunga)

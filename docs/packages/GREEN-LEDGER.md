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
## NOT GREEN -> docs/packages/*/NOT-BUILT.md
- Analytics data backend (formula blocker), meeting-cost server gate, partner/revenue per-seat model, Personal (HOLD), Business/Business Pro/Enterprise packages (agle phases)

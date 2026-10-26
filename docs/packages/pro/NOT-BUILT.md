# PRO — jo bana nahi (26 Oct 2026 07:40). Qaida: naya gate SERVER par (Rust :3200 + Postgres), UI akela nahi. WebTransport live, WASM kernel builtin.
Founder 07:10: 4 faisle "sab kuch kero" -> HAAN. Ho gaye: pre-send/follow-up/snippets/handoff Pro+ (Rust), Overlap Matrix/Focus Ring/meeting cost Pro+, analytics route gate, CRM card par. Detail GATES-AND-TECH.md (GREEN).

## Abhi bhi NAHI BANA (green nahi) — latest-technology spec
| # | Cheez | Haalat | Spec (latest technology) |
|---|---|---|---|
| 1 | **Analytics Center ka DATA backend** (Response debt, Thread economics, Deep work, Leaks, Promise SLA, Forecast, Team) | UI + tables (phase24) hain; `/api/analytics/*` aur `analytics.*` RPC server mein HAIN HI NAHI -> pages "not wired" dikhate hain. Card par claim NAHI (jhoota dawa nahi). | E89 SQL: `analytics_response_debt/_thread_economics/_deep_work(_org,_user)` SECURITY DEFINER, service_role only (mail_threads + mail_messages latest-direction lateral join, percentile_cont median, calendar_events se meeting minutes). Rust `analytics_core.rs` (pure gate fn + tests) + `analytics_glue.rs`: `analytics.responseDebt` = SAB packages; `threadEconomics`/`deepWork` = Pro+; `attentionLeaks/promiseSla/forecast/team` = Business+. Raat ka tokio job `analytics_debt_daily` snapshot. WebTransport topic `analytics` se live invalidate. **BLOCKER (founder faisla chahiye):** "cost of delay" ka formula (kitne £ per waiting-hour?) -- bina formula ke paisay ke number nahi banayenge (NO VANITY / NO MOCK). |
| 2 | Meeting cost server-side gate | Bun `calendar.ts` cost ungated; Rust cal_glue cost = null | jab Rust cost field aaye to `plan != basic` check wahin |
| 3 | Support 48h | process | -- |
| 4 | `revenue.ts` / `server/routes/revenue.ts` / partners page: per-seat PLAN_PRICE (basic 23, pro 46, business 97) | PURANA per-user model Rule 51 se takrata hai | partner/commission model founder ki alag meeting (kis qeemat par commission, flat plans par) |
| 5 | Personal Pro (£46) | HOLD | founder ki alag meeting |


## 26 Oct 08:50 — UPDATE (E89/E90 ke baad)
- #1 Analytics data backend: **READY (repo mein, tested local; deploy ke baad live test)** — E89 SQL + `analytics_glue.rs` (Rust primary) + Bun fallback. Formulas `docs/cursor-work/PACKAGE-FEATURE-FORMULA.md` "ANALYTICS" mein.
- Meeting cost server gate: **READY** — Rust `cal_glue` ab cost bhejta hai (attendee hourly_rate), Basic ke liye `dispatch` null kar deta hai (cal_core `meeting_cost`/`cost_allowed`, 47 tests).
- Partner/revenue per-seat: **READY** — flat price, client companies (Gold 10 / Platinum 30).

# 01 — Green hain (server par), bas Chrome click-test baqi

21 Oct 2026, asli ghadi ~06:50 PKT · repo HEAD b18c4b9+ · source: MASTER-BUILD-PLAN.md, MASTER-GAP-LEDGER.md, loophole-ledger.md, blueprint G-table, DONE-DO-NOT-REPEAT.md, PROMISES.md, TECH-MAP.md + repo grep (src/, server/).

Founder rule se yeh GREEN hain. Yahan sirf wo list jo live dekhna hai (Pro/Business/Business Pro ke saath).

| Item | Kaam | Agla qadam |
|---|---|---|
| Plan P1 | Inline error states, no generic message | founder login par error screens ek dafa dekhna |
| Plan P1 | Password strength indicator (signup) | live signup par dekhna |
| Plan P1 | Forgot password flow (real email) | live reset email test |
| Plan P1 | Email confirmation state UI | live signup test |
| Plan P2 | Activity feed (last 10) | live check |
| Plan P2 | Quick Actions bar | live check |
| Plan P2 | Upcoming panel (today's events) | live check |
| Plan P2 | AI usage panel (AI plan users) | AI plan account se check |
| Plan P2 | Founder version: Founder View stats | founder login par check |
| Plan P3 | Email snooze | snooze ke baad wapas aana live test |
| Plan P4 | Attachment drag-drop | Chrome: attach bhej kar test (founder 'haan' mail bhejne ke liye) |
| Plan P4 | CC/BCC toggle | live check |
| Plan P4 | Draft auto-save every 30 s | live test |
| Plan P4 | LEO compose assist (grammar/professional/translate) | AI account se test |
| Plan P5 | Inline reply | live test |
| Plan P5 | Quote original toggle | live test |
| Plan P5 | Discuss in ANEXOChat button | AnexoChat audit (D10) ke saath |
| Plan P5 | Email → Task | live test |
| Plan P6 | Contact list with search | Basic/Pro live click-through |
| Plan P6 | Contact profile (history/stats/last contact) | live check |
| Plan P6 | Company profile (domain ke sab contacts) | live check |
| Plan P6 | Contact timeline | live check |
| Plan P6 | Import vCard/CSV | live import test |
| Plan P7 | Timezone support | live check |
| Plan P7 | Focus windows (deep work block) | live check |
| Plan P8 | Live system health (Rust/Bun/Postfix/Caddy) | founder Chrome |
| Plan P8 | All workspaces founder view | founder Chrome |
| Plan P8 | Revenue dashboard (MRR/ARR/churn) | founder Chrome (Polar NO-TOUCH) |
| Plan P8 | Safety queue (privacy-preserving) | founder Chrome |
| Plan P8 | AI usage across users | founder Chrome |
| Plan P8 | Launch checklist (real checks) | founder Chrome |
| Plan P8 | SiteLock control | founder Chrome |
| Plan P8 | Move-in manager | founder Chrome |
| Plan P8 | Founder single inbox (phase55) | founder Chrome |
| Plan P8 | Founder routes Rust-only (Rule 22, G18/G40) | server pull |
| Plan P9 | LEO chat always-visible sidebar | AI account |
| Plan P9 | AI Studio | AI account |
| Plan P9 | Knowledge base (upload docs, ask) | AI account |
| Plan P9 | AI Automation (workflow builder) | AI account |
| Plan P9 | Credit wallet (balance visible) | AI account |
| Plan P9 | Usage history + receipts | AI account |

| G | Kaam | Baqi |
|---|---|---|
| G36 | 72 h export → delete (countdown + email) | E44/E45/E46 live; UI/email countdown ka live dekhna (C7) |
| G37 | 24h me 3 account suspicious/review + warn→block→ban | review queue UI live dekhna (C7) |
| G40 | Rust RPC work/crm/org/integrations/settings (19 Bun-only) | B5: 19 mein se 15 Rust (4 public + 11 founder/auth), mail.thread pehle se Rust, mail.send B3; AI chat B8 |

| Tech | Baqi |
|---|---|
| B5 G40 19 Bun-only routes -> Rust | repo + sandbox PASS (~80 checks, asli Bun vs Rust); server par rust-engine-install.sh baqi |

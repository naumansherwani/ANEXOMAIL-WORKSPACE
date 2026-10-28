# What a founder needs — in build order (CEO-agent advice, 28 Oct 2026 10:15 PKT)

Founder's words (10:06): live data "like live TV"; ONE button for "something is wrong / a user needs permission"; works on laptop, desktop, tablet, mobile; Polar is his billing; docs/sheets question; list in order. Rules: FC26 (authentic data only), FC27 (SQL 10/10), Rule 34 (390 / 820 / 1440).

## 0. Today's honest status
- Strip says "Nothing measured yet" for MRR because MRR is read from `revenue_accounts` (manual table). Polar is the real billing source: **F3 reads Polar read-only** (needs his "haan" + a read-only Polar token; Polar :3400 webhook/WAL stays NO-TOUCH). Until then the number is not Polar's and says so.
- The old preview artifacts are previews only; no new previews will be published. The real thing is `founderworkspace.anexomail.com` once `founder-install.sh` is green.

## 1. The ONE button — "Decide" (F2)
One button in the top bar with a count: **Decide (N)**. It opens a single queue, newest-risk first. Each row shows: what happened (real evidence), the CEO-agent's recommended action, and one tap to approve (second tap + reason, gate G2/G3). Row types:
- **Something went wrong:** failing checks, failed sends/queue stuck, failed payment, abuse-score spike, deploy/health failure.
- **Someone needs permission:** new founder device (the CODE screen), account appeal, signup on HOLD, trial-extension / comp-plan request, refund or plan-change request.
- Nothing in the queue = button reads "All clear" (never a fake zero). Every decision = `founder_audit` chain entry.

## 2. Live Pulse — "live TV" for real users (F2)
Source: Supabase auth + sessions + mail/calendar activity counters, read by the Rust binary, pushed over WebTransport (SSE fallback) — no refresh button.
- Signed in now / today / this week; new sign-ups; failed logins; by plan; by device class (phone/tablet/laptop), metadata only — never content, never IP/network (privacy lock).
- **Real vs test accounts are separated** (account-class wall, E76): his test accounts are shown as "Test", never mixed into real-user counts.
- Every tile that cannot be measured says "Not measured".

## 3. Devices — every screen (Rule 34)
Same app, three layouts: laptop/desktop (sidebar + content), tablet 820 (collapsed rail), phone 390 (top menu, one column, Decide button always reachable). Each phase is proved at 390 / 820 / 1440 before it counts as done.

## 4. Order to build (one at a time, each proved live before the next — FC8)
1. F1a-1 device approval (built; install in progress) → F1a-2 awam hosts refuse founder login.
2. F2a/b/c signing, WASM kernel verify, audit chain → trustworthy numbers.
3. **Decide queue + Live Pulse** (needs SQL `founder_pulse` / `founder_decisions`, 10/10 per FC27).
4. F3 Finance: Polar read-only (MRR/ARR, failed payments, churn, mismatch vs manual) + Release.
5. F4 People (user/org 360, suspend/restore, force sign-out) → F5 Mail Desk (company inbox, deliverability).
6. F6 Systems (real probes, backups, DNS/cert expiry) → F8 Control (kill switches, flags, audit viewer) → F9 cutover.
7. Founder's own office: Docs + Sheets (below), then HR/Accounting later.

## 5. Real Docs / Sheets — how, and how he gets it
Already planned (docs/claude/OFFICE-HR-ACCOUNTING-MIGRATION-28OCT.md): a real open-source office engine (Collabora or OnlyOffice) in its own sandboxed service, opened through WOPI from our Rust server, files stored in Supabase storage as .docx/.xlsx/.ods/.csv, shown inside the app (docs.anexomail.com origin). Sheets = real formulas, charts, import/export Excel. It is an awam-side feature for ALL plans; the founder gets the same editor inside the Command Center ("Founder desk"), so nothing is built twice (FC18/FC22). Not built yet; still waiting on his engine choice (licence limits differ: OnlyOffice Community has a connection cap, Collabora's free build has no production support). My recommendation when he asks: decide after a licence/capacity read; until then the founder uses attachments and Edit online later.

## 6. A founder's own system — what he should have (priority order)
1. Decide queue + Live Pulse (above)  2. Money truth (Polar) + runway/target  3. Customers: 360 view, appeals, support inbox
4. Systems health + backups/DNS/cert  5. Release & rollback  6. Control (kill switches)  7. Audit viewer (tamper-evident)
8. Founder desk: docs, sheets, calendar, tasks  9. Incident replay  10. Ask-the-copilot (metadata only)

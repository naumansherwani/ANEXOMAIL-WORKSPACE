# 02 ENDPOINTS — founder ke raaste (code se nikale, 28 Oct)
## NAYA (Rust, 127.0.0.1:3210) — rakhna hai
GET /healthz · POST /founder/v1/login · GET /founder/v1/me · /bridge · /actions · /audit · POST /founder/v1/action
## PURANA (Bun) — `app.use("/api/founder", founderGate)` ke peeche (server/index.ts:127)
| File | Route |
|---|---|
| routes/founder.ts | GET mailboxes, overview, ai-agents, ai-mail (+6 handlers: provision, ai-mail/approve) |
| integrations.ts:337 | GET /integrations/overview |
| settings.ts:517 | GET /settings/overview |
| analytics.ts:93,108 | GET /analytics/overview, /billing/revenue |
| admin.ts:748 | GET /admin/overview |
| security.ts:685 | GET /security/overview |
| perf.ts:548 | GET /perf/overview |
| revenue.ts:160 | GET /revenue/overview |
| ai-credits.ts:398 | GET /ai/credits/overview |
| release.ts | POST /release/run · GET checks, overview, checklist, deployments, lock, roadmap, revenue/pipeline · POST checklist/item, lock, roadmap |
| billing-support.ts:52,75 | GET /support/replies · POST /support/replies/:id/replied |
| movein.ts:167-396 | GET cockpit, deal/:id · POST transition, schedule, arm, mailbox, dns, runbook, exception, rollback, invoice |
| glitch.ts:314 | GET /glitch/health |
| storage.ts:218,250 | GET /storage/volumes · POST /storage/volume |
## PURANA — gate ke BAGHAIR mount (alag path, alag guard)
| org.ts:494-551 | GET /founder/org/state, /list · POST /founder/org/kill-switch, /impersonate (founderGuard, email+founder_accounts) |
| crm.ts:1367,1395 | GET /founder/crm/state · POST /founder/crm/toggle (founderOnly) |
Note: org/crm app.use("/api") se mount hain; index.order.test.ts guard karta hai ki founderGate unse PEHLE mount ho.

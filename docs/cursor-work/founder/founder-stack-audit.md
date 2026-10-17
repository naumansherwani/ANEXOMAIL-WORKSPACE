# Founder stack audit (Rule 22) — static scan

Founder workspace ka maqsad: **sirf Rust** (tRPC `/rpc/*`, WebTransport/QUIC). Yeh scan repo ke code se batata hai ke founder pages ki kaun si calls abhi **Bun REST** par ja sakti hain. *Yeh static scan hai: Rust mein proc sach mein hai ya nahi — `server/rust-procs-check.sh` se milao (Rule 15).*

- Founder routes: **36**, unki libs: **27**
- **rust-first (Bun fallback maujood): 181** · **rust-only: 0** · **bun-only (Rust road hi nahi): 19**

## `admin-center` — founder pages: app.founder_.admin

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `admin.heal` | `/api/admin/health/heal` |  |
| rust-first | `admin.generateReport` | `/api/admin/reports/generate` |  |
| rust-first | `admin.runDiagnostics` | `/api/admin/diagnostics/run` |  |
| rust-first | `admin.health` | `/api/admin/health` |  |
| rust-first | `admin.storage` | `/api/admin/storage` |  |
| rust-first | `admin.incidents` | `/api/admin/incidents` |  |
| rust-first | `admin.monitoring` | `/api/admin/monitoring` |  |
| rust-first | `admin.logs` | `/api/admin/logs?level=${encodeURIComponent(level)}&q=${encodeURIComponent(q)}` |  |
| rust-first | `admin.reports` | `/api/admin/reports` |  |
| rust-first | `admin.diagnostics` | `/api/admin/diagnostics` |  |
| rust-first | `founderAdmin.overview` | `/api/founder/admin/overview` |  |

## `ai-automation` — founder pages: app.founder_.ai.automation

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `ai.toggleWorkflow` | `/api/ai/automation/workflows/${body.id}/toggle` |  |
| rust-first | `ai.runWorkflow` | `/api/ai/automation/workflows/${body.id}/run` |  |
| rust-first | `ai.dryRunWorkflow` | `/api/ai/automation/workflows/${body.id}/dry-run` |  |
| rust-first | `ai.toggleRule` | `/api/ai/automation/rules/${body.id}/toggle` |  |
| rust-first | `ai.saveVariable` | `/api/ai/automation/variables` |  |
| rust-first | `ai.deleteVariable` | `/api/ai/automation/variables/${body.id}` |  |
| rust-first | `ai.decideSuggestion` | `/api/ai/automation/suggestions/${body.id}/decide` |  |
| rust-first | `ai.toggleEmailAutomation` | `/api/ai/automation/email/${body.id}` |  |

## `ai-billing` — founder pages: app.founder_.ai.billing

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `aiBilling.checkout` | `/api/ai/billing/checkout` |  |
| rust-first | `aiBilling.setCap` | `/api/ai/billing/cap` |  |
| rust-first | `aiBilling.wallet` | `/api/ai/billing/wallet` |  |
| rust-first | `aiBilling.history` | `/api/ai/billing/history` |  |
| rust-first | `aiBilling.usage` | `/api/ai/billing/usage?days=${days}` |  |
| rust-first | `aiBilling.packs` | `/api/ai/billing/packs` |  |

## `ai-studio` — founder pages: app.founder_.ai.studio

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `ai.studioRuns` | `/api/ai/studio/runs?tool=${tool}` |  |
| rust-first | `ai.studioRecipes` | `/api/ai/studio/recipes` |  |
| rust-first | `ai.studioBatches` | `/api/ai/studio/batches` |  |
| rust-first | `ai.studioTargets` | `/api/ai/studio/targets` |  |
| rust-first | `ai.studioRun` | `/api/ai/studio/run` |  |
| rust-first | `ai.studioApply` | `/api/ai/studio/runs/${body.id}/apply` |  |
| rust-first | `ai.studioBatch` | `/api/ai/studio/batch` |  |
| rust-first | `ai.studioSaveRecipe` | `/api/ai/studio/recipes` |  |
| rust-first | `ai.studioRunRecipe` | `/api/ai/studio/recipes/${body.recipe_id}/run` |  |

## `ai-workspace` — founder pages: app.founder_.ai.arena, app.founder_.ai.index, app.founder_.ai.memory, app.founder_.ai.prompts, app.founder_.ai.receipts

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `ai.createSession` | `/api/ai/sessions` |  |
| rust-first | `ai.forgetMemory` | `/api/ai/memory/${body.id}` |  |
| rust-first | `ai.runArena` | `/api/ai/arena` |  |
| rust-first | `ai.forkPrompt` | `/api/ai/prompts/${body.prompt_id}/fork` |  |
| rust-first | `ai.savePromptVersion` | `/api/ai/prompts/${input.prompt_id}/versions` |  |
| rust-first | `ai.decideGuardrail` | `/api/ai/guardrail/${body.id}` |  |
| rust-first | `ai.sessions` | `/api/ai/sessions` |  |
| rust-first | `ai.session` | `/api/ai/sessions/${sessionId}` |  |
| rust-first | `ai.credits` | `/api/ai/credits` |  |
| rust-first | `ai.receipts` | `/api/ai/receipts` |  |
| rust-first | `ai.memory` | `/api/ai/memory` |  |
| rust-first | `ai.prompts` | `/api/ai/prompts` |  |
| rust-first | `ai.promptVersions` | `/api/ai/prompts/${promptId}/versions` |  |
| rust-first | `ai.arenaRuns` | `/api/ai/arena` |  |
| rust-first | `ai.guardrail` | `/api/ai/guardrail` |  |
| bun-only |  | `${BASE}/api/ai/chat` |  |

## `analytics` — founder pages: app.founder_.analytics

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `analytics.responseDebt` | `/api/analytics/response-debt` |  |
| rust-first | `analytics.threadEconomics` | `/api/analytics/thread-economics` |  |
| rust-first | `analytics.deepWork` | `/api/analytics/deep-work` |  |
| rust-first | `analytics.attentionLeaks` | `/api/analytics/attention-leaks` |  |
| rust-first | `analytics.promiseSla` | `/api/analytics/promise-sla` |  |
| rust-first | `analytics.forecast` | `/api/analytics/forecast` |  |
| rust-first | `analytics.team` | `/api/analytics/team` |  |
| rust-first | `founderAnalytics.overview` | `/api/founder/analytics/overview` |  |

## `billing-platform` — founder pages: app.founder_.billing

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `billing.saveTax` | `/api/billing/tax` |  |
| rust-first | `billing.previewChange` | `/api/billing/preview` |  |
| rust-first | `billing.changePlan` | `/api/billing/change` |  |
| rust-first | `billing.markFounderReplySent` | `/api/founder/support/replies/${id}/replied` |  |
| rust-first | `billing.subscription` | `/api/billing/subscription` |  |
| rust-first | `billing.invoices` | `/api/billing/invoices` |  |
| rust-first | `billing.tax` | `/api/billing/tax` |  |
| rust-first | `billing.methods` | `/api/billing/methods` |  |
| rust-first | `billing.revenueTruth` | `/api/founder/billing/revenue` |  |
| rust-first | `billing.founderReplyQueue` | `/api/founder/support/replies` |  |

## `crm` — founder pages: app.founder_.crm

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `crm.overview` | `/api/crm/overview` |  |
| rust-first | `crm.live` | `/api/crm/live` |  |
| rust-first | `crm.memory` | `/api/crm/memory?email=${encodeURIComponent(clean)}` |  |
| rust-first | `crm.leads` | `/api/crm/leads?state=${state}` |  |
| rust-first | `crm.leads.suggest` | `/api/crm/leads/suggest` |  |
| rust-first | `crm.deals` | `/api/crm/deals` |  |
| rust-first | `crm.activities` | `/api/crm/activities${dealId ? ` |  |
| rust-first | `crm.insights` | `/api/crm/insights${dealId ? ` |  |
| rust-first | `crm.shared` | `/api/crm/shared?kind=${kind}` |  |
| rust-first | `crm.mentions` | `/api/crm/mentions` |  |
| rust-first | `crm.approvals` | `/api/crm/approvals` |  |
| rust-first | `crm.audit` | `/api/crm/audit` |  |
| rust-first | `crm.permissions` | `/api/crm/permissions` |  |
| rust-first | `crm.founderState` | `/api/founder/crm/state` |  |
| rust-first | `crm.evidence` | `/api/crm/evidence` |  |
| rust-first | `crm.moveDeal` | `/api/crm/deals/stage` |  |
| rust-first | `crm.createLead` | `/api/crm/leads` |  |
| rust-first | `crm.createDeal` | `/api/crm/deals` |  |
| rust-first | `crm.dealWork` | `/api/crm/deals/work` |  |
| rust-first | `crm.dealThread` | `/api/crm/deals/thread` |  |
| rust-first | `crm.convertLead` | `/api/crm/leads/convert` |  |
| rust-first | `crm.assignShared` | `/api/crm/shared/assign` |  |
| rust-first | `crm.decideApproval` | `/api/crm/approvals/decide` |  |
| rust-first | `crm.founderToggle` | `/api/founder/crm/toggle` |  |

## `founder` — founder pages: app.founder

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `founder.overview` | `/api/founder/overview` |  |
| rust-first | `founder.mailboxes` | `/api/founder/mailboxes` |  |
| rust-first | `founder.agents` | `/api/founder/ai-agents` |  |
| rust-first | `founder.aiMail` | `/api/founder/ai-mail?state=${state}` |  |
| rust-first | `founder.provisionMailboxes` | `/api/founder/mailboxes/provision` |  |
| rust-first | `founder.approveAiDraft` | `/api/founder/ai-mail/approve` |  |

## `integrations` — founder pages: app.founder_.integrations

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `integrations.providers` | `/api/integrations/providers` |  |
| rust-first | `integrations.connections` | `/api/integrations/connections` |  |
| rust-first | `integrations.migrations` | `/api/integrations/migrations` |  |
| rust-first | `integrations.delivery` | `/api/integrations/delivery/health` |  |
| rust-first | `integrations.exports` | `/api/integrations/exports` |  |
| rust-first | `integrations.leoActions` | `/api/integrations/leo-actions` |  |
| rust-first | `founderIntegrations.overview` | `/api/founder/integrations/overview` |  |
| rust-first | `integrations.connect` | `/api/integrations/connect` |  |
| rust-first | `integrations.disconnect` | `/api/integrations/disconnect` |  |
| rust-first | `integrations.startMigration` | `/api/integrations/migrations` |  |
| rust-first | `integrations.controlMigration` | `/api/integrations/migrations/control` |  |
| rust-first | `integrations.export` | `/api/integrations/exports` |  |
| rust-first | `integrations.toggleLeoAction` | `/api/integrations/leo-actions/toggle` |  |

## `knowledge` — founder pages: app.founder_.ai.knowledge

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `knowledge.addDocument` | `/api/knowledge/documents` |  |
| rust-first | `knowledge.deleteDocument` | `/api/knowledge/documents/${body.id}` |  |
| rust-first | `knowledge.pinDocument` | `/api/knowledge/documents/${body.id}/pin` |  |
| rust-first | `knowledge.ask` | `/api/knowledge/ask` |  |
| rust-first | `knowledge.ingestThread` | `/api/knowledge/ingest/thread` |  |
| rust-first | `knowledge.spaces` | `/api/knowledge/spaces` |  |
| rust-first | `knowledge.search` | `/api/knowledge/search?q=${encodeURIComponent(query)}` |  |

## `mail` — founder pages: app.founder_.ai.arena, app.founder_.ai.automation, app.founder_.ai.billing, app.founder_.ai.index, app.founder_.ai.knowledge, app.founder_.ai.memory, app.founder_.ai.prompts, app.founder_.ai.receipts, app.founder_.ai.studio, app.founder_.crm, app.founder_.movein, app.founder_.org

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `mail.labels` | `/api/mail/labels` |  |
| rust-first | `mail.accounts` | `/api/mail/accounts` |  |
| rust-first | `mail.identities` | `/api/mail/identities` |  |
| rust-first | `mail.counts` | `/api/mail/counts` |  |
| rust-first | `mail.star` | `/api/mail/thread/${threadId}/star` |  |
| bun-only |  | `/api/mail/thread/${threadId}` |  |
| bun-only |  | `/api/mail/send` |  |

## `movein` — founder pages: app.founder_.movein

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| bun-only |  | `/api/public/movein/capacity` |  |
| bun-only |  | `/api/public/movein/request` |  |
| bun-only |  | `/api/movein/deal` |  |
| bun-only |  | `/api/founder/movein/cockpit` |  |
| bun-only |  | `/api/founder/movein/deal/${id}` |  |

## `org` — founder pages: app.founder_.org

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `org.overview` | `/api/org/overview` |  |
| rust-first | `org.members` | `/api/org/members?status=${status}` |  |
| rust-first | `org.roles` | `/api/org/roles` |  |
| rust-first | `org.privilegeRadar` | `/api/org/privilege-radar` |  |
| rust-first | `org.departments` | `/api/org/departments` |  |
| rust-first | `org.policies` | `/api/org/policies` |  |
| rust-first | `org.sessions` | `/api/org/sessions` |  |
| rust-first | `org.anomalies` | `/api/org/anomalies` |  |
| rust-first | `org.proof` | `/api/org/proof` |  |
| rust-first | `org.audit` | `/api/org/audit` |  |
| rust-first | `org.mailboxes.list` | `/api/org/mailboxes` |  |
| rust-first | `org.graph` | `/api/org/graph?days=${days}` |  |
| rust-first | `org.compliance` | `/api/org/compliance` |  |
| rust-first | `org.breakGlass` | `/api/org/break-glass` |  |
| rust-first | `founder.org.state` | `/api/founder/org/state` |  |
| rust-first | `founder.org.list` | `/api/founder/org/list` |  |
| rust-first | `org.members.revoke` | `/api/org/members/revoke` |  |
| rust-first | `org.mailboxes.create` | `/api/org/mailboxes` |  |
| rust-first | `org.members.blastRadius` | `/api/org/members/blast-radius` |  |
| rust-first | `org.sessions.kill` | `/api/org/sessions/kill` |  |
| rust-first | `org.policies.simulate` | `/api/org/policies/simulate` |  |
| rust-first | `org.policies.toggle` | `/api/org/policies/toggle` |  |
| rust-first | `org.audit.verify` | `/api/org/audit/verify` |  |
| rust-first | `org.breakGlass.grant` | `/api/org/break-glass` |  |
| rust-first | `founder.org.killSwitch` | `/api/founder/org/kill-switch` |  |
| rust-first | `founder.org.impersonate` | `/api/founder/org/impersonate` |  |

## `perf` — founder pages: app.founder_.perf

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `perf.runQuery` | `/api/perf/search/run` |  |
| rust-first | `perf.dashboard` | `/api/perf/dashboard` |  |
| rust-first | `perf.budgets` | `/api/perf/budgets` |  |
| rust-first | `perf.prefetch` | `/api/perf/prefetch` |  |
| rust-first | `perf.search` | `/api/perf/search` |  |
| rust-first | `perf.devices` | `/api/perf/devices` |  |
| rust-first | `perf.regressions` | `/api/perf/regressions` |  |
| rust-first | `founder.perf` | `/api/founder/perf/overview` |  |

## `release` — founder pages: app.founder_.launch.checklist, app.founder_.launch.deployments, app.founder_.launch.index, app.founder_.launch.lock, app.founder_.launch.qa, app.founder_.launch.roadmap, app.founder_.revenue_.pipeline

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `founder.release.overview` | `/api/founder/release/overview` |  |
| bun-only |  | `/api/founder/release/checks` |  |
| bun-only |  | `/api/founder/release/run` |  |
| bun-only |  | `/api/founder/release/checklist` |  |
| bun-only |  | `/api/founder/release/checklist/item` |  |
| bun-only |  | `/api/founder/release/deployments` |  |
| bun-only |  | `/api/founder/release/lock` |  |
| bun-only |  | `/api/founder/release/roadmap` |  |
| bun-only |  | `/api/founder/revenue/pipeline` |  |
| bun-only |  | `/api/public/status` |  |
| bun-only |  | `/api/mail/outbox/send` |  |

## `revenue` — founder pages: app.founder_.revenue

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `founder.revenue.overview` | `/api/founder/revenue/overview` |  |
| bun-only |  | `/api/public/revenue/lead` |  |

## `security-platform` — founder pages: app.founder_.security

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `security.deviceState` | `/api/security/devices/state` |  |
| rust-first | `security.killSession` | `/api/security/sessions/kill` |  |
| rust-first | `security.killSwitch` | `/api/security/kill-switch` |  |
| rust-first | `security.disown` | `/api/security/history/disown` |  |
| rust-first | `security.rotate` | `/api/security/encryption/rotate` |  |
| rust-first | `security.runProof` | `/api/security/proof/run` |  |
| rust-first | `security.dashboard` | `/api/security/dashboard` |  |
| rust-first | `security.devices` | `/api/security/devices` |  |
| rust-first | `security.sessions` | `/api/security/sessions` |  |
| rust-first | `security.history` | `/api/security/history?outcome=${encodeURIComponent(outcome)}` |  |
| rust-first | `security.encryption` | `/api/security/encryption` |  |
| rust-first | `security.proof` | `/api/security/proof` |  |
| rust-first | `founderSecurity.overview` | `/api/founder/security/overview` |  |

## `settings` — founder pages: app.founder_.settings

| road | Rust proc | REST (Bun) path | Rust mein? |
|---|---|---|---|
| rust-first | `settings.list` | `/api/settings/${scope}` |  |
| rust-first | `settings.blastRadius` | `/api/settings/blast-radius?key=${key!}` |  |
| rust-first | `settings.explain` | `/api/settings/explain?key=${key!}` |  |
| rust-first | `settings.drift` | `/api/settings/drift` |  |
| rust-first | `settings.scheduled` | `/api/settings/scheduled` |  |
| rust-first | `founderSettings.overview` | `/api/founder/settings/overview` |  |
| rust-first | `settings.save` | `/api/settings/save` |  |
| rust-first | `settings.revert` | `/api/settings/revert` |  |
| rust-first | `settings.schedule` | `/api/settings/schedule` |  |
| rust-first | `settings.simulate` | `/api/settings/simulate` |  |


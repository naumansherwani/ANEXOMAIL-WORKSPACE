# LEGACY FOUNDER FILES — Lovable ke likhe purane founder files (28 Oct 2026)
Yeh files ABHI chalti hain (awam React app mein) — NAYE founder (server/founder + founder-web) ke aane tak NAHI chhedi jati, na move (file-based routes tootte). Naya founder inki jagah leta hai; cutover F9 mein (tab hi yeh hatengi). Naya kaam in files mein NAHI. Tafseel: FOUNDER-CODE-INVENTORY-28OCT.md.

## Routes (src/routes, 36)
- src/routes/app.founder.tsx
- src/routes/app.founder_.admin.tsx
- src/routes/app.founder_.ai.arena.tsx
- src/routes/app.founder_.ai.automation.tsx
- src/routes/app.founder_.ai.billing.tsx
- src/routes/app.founder_.ai.index.tsx
- src/routes/app.founder_.ai.knowledge.tsx
- src/routes/app.founder_.ai.memory.tsx
- src/routes/app.founder_.ai.prompts.tsx
- src/routes/app.founder_.ai.receipts.tsx
- src/routes/app.founder_.ai.studio.tsx
- src/routes/app.founder_.ai.tsx
- src/routes/app.founder_.analytics.tsx
- src/routes/app.founder_.billing.tsx
- src/routes/app.founder_.calls.tsx
- src/routes/app.founder_.crm.tsx
- src/routes/app.founder_.integrations.tsx
- src/routes/app.founder_.launch.checklist.tsx
- src/routes/app.founder_.launch.deployments.tsx
- src/routes/app.founder_.launch.index.tsx
- src/routes/app.founder_.launch.lock.tsx
- src/routes/app.founder_.launch.qa.tsx
- src/routes/app.founder_.launch.roadmap.tsx
- src/routes/app.founder_.launch.tsx
- src/routes/app.founder_.motion.tsx
- src/routes/app.founder_.movein.tsx
- src/routes/app.founder_.org.tsx
- src/routes/app.founder_.perf.tsx
- src/routes/app.founder_.revenue.tsx
- src/routes/app.founder_.revenue_.pipeline.tsx
- src/routes/app.founder_.safety.tsx
- src/routes/app.founder_.security.tsx
- src/routes/app.founder_.settings.tsx
- src/routes/founder.preview.tsx
- src/routes/founder.tsx
- src/routes/founder_.$.tsx

## Components / lib / server
- server/lib/founder-gate-core.ts
- server/lib/founder-gate.test.ts
- server/lib/founder-gate.ts
- server/routes/founder.ts
- src/components/site/FounderBar.tsx
- src/lib/founder-plan.ts
- src/lib/founder-preview.ts
- src/lib/founder.ts
- src/components/app/dashboard/ExpiryWatch.tsx (founder expiry watch — awam dashboard mein bhi)

## Mapping (legacy -> naya phase)
- app.founder_.admin / perf / glitch / org -> F6 Systems + F4 People
- app.founder_.ai.* (arena, automation, billing, knowledge, memory, prompts, receipts) -> AI lane (coming soon), F6 Systems ke baad
- movein / release / revenue pages -> F3 Money+Release
- FounderBar.tsx / .lovable.app host guards -> F1a mein hatenge (awam app se founder alag)
- server/routes/founder.ts (Bun) + 53 Bun-only endpoints -> Rust anexomail-founder (F2-F8), Bun route sirf Rust saboot ke baad hatega

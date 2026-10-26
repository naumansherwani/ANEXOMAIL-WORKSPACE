# CRM — Zoho gap band karne ke 6 phases (CEO, 26 Oct 2026 09:45 PKT) — Rule 53/54: GATE PEHLE, code baad mein

Founder hukm: Zoho jaisa advance CRM, latest technology par (Rust :3200 + Postgres RLS + WebTransport live + WASM kernel; **Bun sirf fallback**), aur **Pro CRM hamesha Business CRM se chhota**.
Source of truth for gates: `docs/packages/features.tsv` (CRM-07..CRM-17). Zoho muqabla (Rule 54): Blueprint, Scoring, Assignment rules, Multi-pipeline, Custom fields/modules, CPQ, Cadences (Sales Signals/Cadences), Forecasts+Quotas, Territories, Approvals, Web forms, Dashboards, Duplicate management.

## Jo ANEXOMAIL ke paas pehle se hai (Zoho ke paas nahi / barabar)
Accounts, leads, pipeline, tasks, reports, health ring, timeline, promise engine, evidence, intelligence graph, CRM->Mail/Work/Calendar. Yeh differentiators hain; naye phases inke upar bante hain, inhe todte nahi.

## Pro vs Business vs Business Pro (Pro < Business strict)
| Feature | Pro | Business | Business Pro | Phase |
|---|---|---|---|---|
| Pipelines | 1 | 5 | unlimited | P1 |
| Custom fields | 5 | 25 | unlimited | P1 |
| Duplicate detect + merge | Y | Y | Y | P1 |
| Web form -> lead | 1 form | 10 | unlimited | P2 |
| Lead scoring + assignment rules (round-robin) | - | Y | Y | P3 |
| Workflow automation / Blueprint | - | 10 rules | unlimited | P4 |
| Quotes / CPQ | - | Y | Y | P5 |
| Deal approval process | - | - | Y | P5 |
| Sales cadences | - | Y | Y | P6 |
| Forecast + quotas | - | Y | Y | P6 |
| Custom dashboards | - | Y | Y | P6 |
| Territory management | - | - | Y | P6 |
Enterprise = Business Pro + upar, **sirf Rust (Bun nahi)**.

## Phases (har phase ka order: gate row -> SQL (E-series, RLS ON, Rule 38/43) -> Rust `crm_core.rs` (std-only tests) + `crm_glue.rs` -> kernel/WT live topic -> UI -> Basic/Pro/Business 403 test -> Chrome live -> ledger)
- **P1 Pipelines + custom fields + duplicate merge.** Tables `crm_pipelines`, `crm_pipeline_stages`, `crm_field_defs`, `crm_field_values`, `crm_merge_log`. Cap server-side (trigger + Rust gate): Pro 1/5, Business 5/25. Duplicate: lowercase email + domain+name fuzzy (pg_trgm), merge ek transaction mein, undo 24h.
- **P2 Web forms.** `crm_forms` + public POST `/rpc/crm.form.submit` (Rust, rate limit, honeypot, no CAPTCHA bypass), lead + timeline row, spam score.
- **P3 Scoring + assignment.** Rule table (`crm_score_rules`), deterministic points (koi AI nahi — LEO COMING SOON), round-robin by `crm_assign_state`; collision guard ke saath.
- **P4 Workflow / Blueprint.** Trigger (stage change, form, score, overdue) -> actions (task, mail template, assign, field set). Tokio job runner `crm_runner` (idempotent, audit row har run). Business 10 rules cap.
- **P5 Quotes/CPQ + approvals.** Products, price book, quote (versioned), PDF, invoice link. Approval: discount > limit -> approver; Business Pro only.
- **P6 Cadences + forecast/quotas + territories + dashboards.** Forecast formula = weights 4/3/2/1 style (analytics se shared), quota vs closed-won; territory by country/segment rule; dashboards = saved widget configs (no custom code).

## Rules jo har phase par lagte hain
Rule 52 (kernel/WT), 53 (gate pehle), 55 (PER MONTH + USER CAP), 43 (RLS), 46 (SQL -> Rust -> Web), **no vanity numbers**, mobile 390 test. Status sirf DONE/READY/TODO; "green" = Chrome live test.

## Status
Sab 6 phases: **TODO** (founder haan ke baad P1 se). Gates features.tsv mein PROPOSED.

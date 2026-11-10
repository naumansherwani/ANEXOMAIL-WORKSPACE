> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

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
Business Premium = Business Pro + upar, **sirf Rust (Bun nahi)**.

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
Founder "haan" 26 Oct 10:45 PKT. **P1 + P2: READY (code)** — E92 SQL + Rust crmx + UI; green sirf deploy + Chrome proof ke baad. P3-P6: TODO (Business). Gates features.tsv.

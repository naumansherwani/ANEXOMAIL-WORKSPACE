# B13 STEP T0 (BL-46): SCHEMA STUDY + THREAT MODEL + ROLLBACK PLAN + ISOLATION TEST LIST (24 Nov 2026 07:3x PKT). Item 10 of docs/claude/admin-desk/TENANT-IDENTITY-CONSENT-DECISION-24NOV.md. Written BEFORE any T1..T6 SQL. Docs only.
ADVANCE TECHNOLOGY (the steps this unlocks): PostgreSQL 16 (FK to the tenant registry, partial unique indexes, forced RLS, append-only hash chain, versioned effective-dated history), Rust Ed25519 Rule 52 doors over HTTP/3, passkey-bound consent, fail closed. WEB RESEARCH: the outside advisor review saved verbatim in the decision file (24 Nov 07:16) + Google Access Approval pattern in D6-B13-CONSENT-ACCESS-LIST-24NOV.md.

## 1. SCHEMA STUDY (what exists, checked in the repo and in his pastes)
| Object | Fact | Consequence for tenant identity |
|---|---|---|
| public.orgs (id uuid, name, created_at) | 7 rows on his server. The Desk company id and the census use this. | Canonical tenant UUID = orgs.id (decided here, proven: 7 of 7 have an approver). |
| public.organisations, public.account_organisations | org_members.org_id has a FK to organisations(id); 16 organisations, 10 account_organisations; all 7 orgs.id are ALSO in organisations and in account_organisations. | Three company tables exist. T1 must prove they never disagree; orgs.id stays the one canonical key and the other two must reference it, never a second identity. |
| public.org_members (org_id, user_id, role owner/admin/member, status) | 16 active owner/admin rows; FK user_id to auth.users. | Approver rule cp.consent_is_approver already reads it (CP5, GREEN). |
| public.org_domains (org_id, domain, status pending/verified/removed, verified_at) | UNIQUE index on domain WHERE status <> removed: one live claim per domain. NO removed_at, NO effective-from/to, NO history of who held a domain before. | "Domain claimed by two tenants" cannot exist among live rows (good). "Tenant changes domain" has no effective-dated history: T1 adds a versioned ownership table (never edits org_domains). |
| public.mail_accounts (org_id, address, owner_id) | An address belongs to ONE org. | Sender membership/alias proof: address -> org_id. |
| desk.fadm_case (ref, address, thread_id, company_ref text 6..64, ...) | company_ref is free text, no FK, no tenant UUID column, no binding evidence. | T2: new binding table (case -> tenant_id UUID FK orgs.id), immutable, with source/actor/time/evidence. company_ref stays a hint. |
| cp.consent_inbox (CP5) | org_id uuid (no FK to orgs, validated in cp.consent_push), case_ref text, scope, window, ledger. | T6: Desk and Control Plane both check case + tenant; consent_push must receive the BOUND tenant UUID only. |
## 2. THREAT MODEL (STRIDE, consent + tenant identity)
| # | Threat | Control (step) |
|---|---|---|
| 1 | Spoofing: attacker emails from a look-alike or shared domain (gmail.com) to get a case bound to a victim tenant | Shared/free domains never auto-match; auto match needs verified domain AND sender is a known member/alias (T3) |
| 2 | Wrong tenant: free-text company_ref points at another customer | company_ref is a hint only; binding comes from the resolution record (T2, T3) |
| 3 | Tampering: staff rebinds a case to move a grant | binding table append-only + immutable; correction = dual-approved procedure (T2, T5) |
| 4 | Repudiation: nobody can say who bound or approved | every resolution and decision = hash-chained ledger line with actor, source, evidence (T2, CP5 ledger) |
| 5 | Information disclosure: consent request leaks case details to the wrong tenant | push only after exactly one tenant is conclusively bound; request carries case ref + scope + reason only, no content (T6) |
| 6 | Denial of service: flood of consent requests at one tenant | per tenant waiting cap 20 (CP5, GREEN), per staff cap 5 (AD20, GREEN), rate limit 50/s (Control Plane) |
| 7 | Elevation: Control Plane or Desk approves by itself | Control Plane role cannot decide (CP5 CHECK, GREEN); Desk has no decide request (consent_cp.rs); only a verified poll Act is applied (Z4b-3) |
| 8 | Stale grant: customer revokes, staff still reads | open polls the Control Plane first; window is in the database; expiry by clock (CP5, AD20) |
| 9 | Cross-tenant read through a shared helper | isolation tests below, forced RLS, no direct table right |
| 10 | Domain handover: old owner's cases bind to the new owner of the domain | historical bindings never change; versioned domain ownership with effective dates (T1) |
## 3. ROLLBACK PLAN (every step is additive; nothing existing is changed or dropped)
- T1..T2 add NEW tables only (versioned domain ownership, case binding, binding ledger). Rollback = the Desk stops reading them (feature flag DESK_TENANT_BIND=off keeps consent requests CLOSED, never open) and the tables stay as evidence. No DROP of anything with data without his word.
- Z4b-3 wiring is behind the same flag: off = no push, requests stay "requested" (today's behaviour, safe).
- Every SQL file is re-runnable (IF NOT EXISTS / CREATE OR REPLACE) with a selftest that rolls back; a failed CHECK leaves the old state; the installer prints WARN and the consent path stays closed.
- Binary rollback: the installer keeps the previous binary; switching back is one install of the previous commit.
## 4. AUTOMATED CROSS-TENANT ISOLATION TESTS (written as SQL selftests + cargo tests in T6; list fixed now)
1 A consent for tenant A can never be pushed with tenant B's UUID. 2 A case bound to A cannot be bound to B (update refused). 3 A grant for case X cannot open case Y. 4 An approver of tenant A cannot decide a request of tenant B (CP5 selftest covers it today). 5 gmail.com sender never auto-binds. 6 Two live claims of one domain are refused by the database. 7 A sender who is a member of two tenants stays UNRESOLVED until a verified selection. 8 After a domain moves to another tenant the OLD cases keep the OLD tenant. 9 Manual resolution of a conflicting identity needs a second reviewer (the first reviewer alone is refused). 10 Control Plane down = nothing approved, nothing opened. 11 Revoke at the Control Plane closes the Desk window at the next open. 12 Every resolution and decision has a chain-verified ledger line.
## 5. ORDER FROM HERE (B13)
T0 (this file, GREEN as a document) -> T1 tenant registry + versioned domain ownership SQL (AD21 world-class SQL, schema-first on AD07, org_domains, orgs) -> T2 case binding table + ledger -> T3 automatic resolution function + Rust ingest hook -> T4 manual resolution + second reviewer -> T5 dual-approved correction -> T6 Z4b-3 wiring + isolation tests -> Z4c customer screen (his haan). Each step: web research line in the blueprint BEFORE code, contract in CURRENT.md, gate, his install paste, then GREEN.

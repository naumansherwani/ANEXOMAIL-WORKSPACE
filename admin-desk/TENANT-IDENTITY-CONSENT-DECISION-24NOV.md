# TENANT IDENTITY RESOLUTION + CONSENT AUTHORIZATION: PERMANENT SECURITY DECISION (24 Nov 2026 07:16 PKT)
# SOURCE: the founder asked an outside advisor (ChatGPT) the question written in D6 chat at 07:02 PKT and pasted the answer. His order (07:16): "YEH EK EK LINE GOLD KI TARAH SAVE KERO JAISA LIKHA HAI WAISA LIKHO AUR IS MAIN AGAR KOI NAHI ADD KERNA HAI WOH BAAD MAIN DEKH LE GAY". The text below the line "BEGIN VERBATIM" is saved EXACTLY as pasted, nothing added, nothing removed. Claude's own notes are only in the section AFTER "END VERBATIM".
# BEGIN VERBATIM

Option (b) + Option (a) + controlled Option (c)
Case create hote waqt `tenant_id` resolve aur permanently associate hona chahiye. Verified-domain mapping automatic resolution ka source ho, aur manual selection sirf controlled exception process mein use ho.
Security rules:

1. Verified domain: Domain ownership aur sender membership/alias dono verify hon.
2. Tenant binding: Case creation par immutable `tenant_id` store ho. Unresolved cases ko `UNRESOLVED` status mein rakhein; consent requests block hon.
3. Manual resolution: Authorized staff tenant select kar sakte hain, lekin independent verification aur audit trail mandatory ho.
4. Gmail/shared domains: Automatic tenant matching kabhi na karein.
5. Duplicate domain: Agar domain multiple tenants se associated ho, automatic resolution reject karein.
6. Multiple memberships: Sender multiple tenants ka member ho to explicit company reference ya verified tenant selection required ho.
7. Domain changes: Historical cases ka existing tenant binding kabhi automatically change na ho.
8. Consent enforcement: Grant hamesha case ke bound `tenant_id` ke against issue ho. Email address ya free-text company reference se grant authorize na ho.

Important database constraints:

* `tenant_id UUID NOT NULL` for resolved cases.
* Foreign key to tenant registry.
* Unique, auditable case-to-tenant binding.
* Every resolution records source, actor, timestamp and evidence.
* Consent grant must reference the same tenant and case.

Claude ke original question ka direct answer: Option (b) safest foundation hai, Option (a) trusted automatic resolution mechanism hai, aur Option (c) exception handling ke liye hai.
Is architecture mein wrong customer ko consent request bhejne ka risk significantly reduce hota hai. Maine Review kerne ke baad yeh hai Meri final recommendation: ANEXOMAIL Command Center OS ke liye Hybrid Tenant Identity Resolution Architecture implement karein — deterministic resolution, immutable tenant binding, zero-trust authorization aur fail-closed security ke saath.

Ek important distinction: support case ko unresolved hone par create karne se rokna zaroori nahi. Lekin us case ko kisi tenant se associate karna ya consent request bhejna tab tak strictly forbidden hona chahiye jab tak identity conclusively resolve na ho.
ANEXOMAIL — Final Architecture Decision
Recommended

Hybrid A + B + Controlled C
Enterprise-grade tenant identity and consent security

1. Tenant identity resolution
- Verified domain registry is the automatic resolution source.
- Verify domain ownership, sender membership and authorized aliases.
- Internal company reference is a lookup hint, never an identity authority.
- Resolve to exactly one canonical tenant_id UUID.
2. Immutable case binding
- Store tenant_id as a UUID foreign key.
- Once bound, tenant identity cannot be silently changed.
- Preserve resolution source, evidence, timestamp and actor.
- Unresolved cases remain in PENDING_TENANT_RESOLUTION.
- Never send consent requests from unresolved cases.
3. Controlled manual resolution
- Only specifically authorized helpdesk personnel can resolve exceptions.
- Require independent verification against the tenant registry.
- Require a second authorized reviewer for ambiguous or conflicting identities.
- Record every action in an append-only audit trail.
4. Edge-case security rules
Situation	Required action
Gmail/shared domain	No automatic matching
Domain claimed by two tenants	Reject and quarantine
Sender belongs to multiple tenants	Require explicit verified tenant selection
Tenant changes domain	Versioned domain ownership history
Unknown sender	Pending resolution
Conflicting company reference	Block and investigate

5. Consent authorization

Every consent grant must be cryptographically and transactionally bound to:
- case_id
- tenant_id
- Verified company admin identity
- Exact requested data scope
- Expiration timestamp
- Unique consent ID
Every data-access operation must independently verify active consent, tenant match, scope, expiry and revocation status. No implicit or inherited authorization.

6. Future-proof infrastructure
- Zero-trust authorization.
- UUID-based canonical tenant identity.
- Versioned domain and membership registry.
- Idempotent consent operations.
- Append-only security audit.
- Explicit revocation and expiry enforcement.
- Fail-closed behavior on database, identity or authorization failures.
- No cross-tenant fallback or fuzzy matching.  Implement the ANEXOMAIL Command Center OS Tenant Identity Resolution and Consent Authorization architecture using the following permanent security decisions:

1. Adopt Hybrid A+B+C: verified-domain and verified-membership resolution, mandatory canonical UUID binding for resolved cases, and controlled manual exception resolution.
2. Support case creation without tenant resolution, but prohibit tenant-specific data access and consent requests until exactly one tenant is conclusively established.
3. Make tenant binding immutable after confirmation. Any exceptional correction must use a separately authorized, dual-approved, fully audited correction procedure. Never silently reassign historical cases.
4. Maintain versioned domain ownership and membership records with effective dates and historical evidence.
5. Treat shared domains, conflicting claims, multiple memberships and unknown identities as ambiguous. Fail closed.
6. Require explicit company-admin authentication and tenant-scoped consent, including case ID, tenant UUID, data scope, issue time, expiry, revocation and unique consent ID.
7. Enforce authorization server-side on every protected operation. Never trust frontend state, email addresses, free-text references or cached permissions as authorization proof.
8. Use database constraints, transactional checks, idempotency, immutable audit events and concurrency-safe consent validation.
9. Design for multiple helpdesk databases, multiple tenants, future domain migrations, regional infrastructure and horizontal scaling.
10. Before implementation, inspect existing ANEXOMAIL database schemas and authorization flows. Preserve existing functionality. Produce a migration plan, threat model, rollback plan and automated cross-tenant isolation tests.

Do not weaken these security decisions for convenience. Do not assume that a successful email-domain match alone proves tenant identity. Do not allow ambiguous identity to produce a consent request or data-access grant. Mera final verdict: Is architecture ko ANEXOMAIL ka permanent security foundation banayein. Future mein scale, servers, databases aur domain structure change ho sakte hain, lekin tenant identity aur consent authorization ke security principles dobara redesign karne ki zaroorat nahi honi chahiye.

# END VERBATIM

## CLAUDE NOTES (added AFTER the verbatim text, not part of it; he reviews these later)
1. WHAT THIS DECIDES: Z4b-3 may not push any consent request until the Desk case is bound to exactly one tenant UUID. Free-text company_ref (fadm_case.company_ref, AD07, text 6..64) is a HINT only and never authorizes a request. A case without a bound tenant = no push, no consent request (fail closed).
2. WHAT EXISTS TODAY (checked in the repo / his pastes): public.orgs has 7 companies, org_members reaches all 7 (7 of 7 have an owner/admin), public.org_domains exists (CP3 reads it, verified and pending counts), the case table has company_ref text and no tenant UUID column, no binding table, no resolution evidence. CP5 (GREEN) already binds a consent to org_id + case_ref + scope + window + passkey digest + ledger hash.
3. WHAT IS MISSING, each its own step (a sub-phase list of B13, written in CURRENT.md before code): T1 tenant registry check (orgs.id is the canonical tenant UUID; domain and membership history with effective dates); T2 case-to-tenant binding table with resolution source, actor, time, evidence, immutable, append-only; T3 automatic resolution by verified domain + verified membership with the ambiguity rules (shared domains, two claimants, multi-membership, unknown = pending); T4 manual resolution by authorized staff with a second reviewer for conflicts; T5 dual-approved correction procedure; T6 consent bound to case + tenant on both databases + cross-tenant isolation tests + migration/rollback/threat model. Item 10 of the decision (inspect schemas first, migration plan, threat model, rollback plan, isolation tests) is written as the FIRST step before any SQL.
4. ORDER: this is part of B13 (BL-46), before Z4b-3. Z4a stays GREEN. His 02:39 order for B11, B12, B6c, 1n, 1o, 1a, security hardening, OS-11 last is unchanged.
5. RULE 52, advance technology per step unchanged: PostgreSQL forced RLS + constraints + append-only hash chain, Rust Ed25519 signed doors over HTTP/3, passkey-bound consent, fail closed.

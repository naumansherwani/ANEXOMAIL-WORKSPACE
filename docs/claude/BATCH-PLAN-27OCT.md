# BATCH PLAN — Basic baaqi endpoints (27 Oct 2026)

Qaida: ek batch = ek package ke SAB endpoints ek saath, ek deploy. Basic ka code Basic aur Pro dono ko milta hai (founder 27 Oct 00:27). Gate ka sach `ENDPOINT-PACKAGE-MAP.csv` (starts_at) aur Rust (`resolve_plan`); UI sirf aaina (Rule 57).

| Batch | Module | Endpoints | Gate (starts_at) | Frontend UI | Halat |
|---|---|---|---|---|---|
| 0 | authx | auth.session | sab plans (login) | auth.tsx -> rpcOrRest | LIVE GREEN 27 Oct |
| A | contx | contacts x6, companies x3, search.universal | sab plans (basic) | lib/contacts.ts -> rpcOrRest; People/Company/Search screens | LIVE GREEN 27 Oct |
| B | basx | storage x5 (+internal/founder Rust-only baad mein), workspace x4, support x3, dashboard.ai-usage | sab plans; storage internal/founder = service/founder | lib/storage, workspace, support, dashboard | LIVE GREEN 27 Oct (storage x5, support x3, setActive); B2 workspace personal/organisations/invitations LIVE GREEN; B2 wsx personal/organisations LIVE (probe) 02:08, creation-path live test baaki |
| C | billx | billing-sync x12 (Polar :3400 NO-TOUCH; sirf read/state/sync) | sab plans | lib/billing | uske baad |
| D | setx | settings 7, integrations 10, security 7 | sab plans (kuch Pro gate) | settings screens | uske baad |
| E | accx | account-deletion 3, mail 2, calendar 1, locale 1 | sab plans | account screens | uske baad |
| F | authy | auth login/refresh/logout/mfa/magic (24) | login-safe, fallback rakho | auth route | sab se aakhir (risky) |

Har batch ka saboot: cargo check (poora crate), bun test, tsc, installer probe, basic-gate-probe (Basic+Pro), kernel-check, Chrome mein REST gayab.

## Batch A/B endpoint list (map se)

- [A] contacts.ts GET /api/contacts/tags — gate: basic
- [A] contacts.ts GET /api/contacts — gate: basic
- [A] contacts.ts GET /api/contacts/:id — gate: basic
- [A] contacts.ts PATCH /api/contacts/:id — gate: basic
- [A] contacts.ts POST /api/contacts/:id/tags — gate: basic
- [A] contacts.ts GET /api/contacts/:id/timeline — gate: basic
- [A] contacts.ts GET /api/companies — gate: basic
- [A] contacts.ts GET /api/companies/:domain — gate: basic
- [A] contacts.ts GET /api/companies/:domain/timeline — gate: basic
- [A] contacts.ts GET /api/search/universal — gate: basic
- [B] dashboard.ts GET /api/dashboard/ai-usage — gate: basic
- [B] storage.ts GET /api/storage/state — gate: basic
- [B] storage.ts POST /api/storage/preflight — gate: basic
- [B] storage.ts POST /api/storage/reserve — gate: basic
- [B] storage.ts POST /api/storage/commit — gate: basic
- [B] storage.ts POST /api/storage/release — gate: basic
- [B] storage.ts POST /api/internal/storage/accept — gate: internal
- [B] storage.ts POST /api/internal/storage/commit — gate: internal
- [B] storage.ts GET /api/founder/storage/volumes — gate: founder
- [B] storage.ts POST /api/founder/storage/volume — gate: founder
- [B] storage.ts POST /api/internal/storage/sweep — gate: internal
- [B] support.ts GET /api/public/sla — gate: basic
- [B] support.ts GET /api/support/drafts — gate: basic
- [B] support.ts POST /api/support/drafts/:id/discard — gate: basic
- [B] workspace.ts POST /api/workspace/personal — gate: basic
- [B] workspace.ts POST /api/workspace/organisations — gate: basic
- [B] workspace.ts PATCH /api/workspace/active-organisation — gate: basic
- [B] workspace.ts POST /api/workspace/invitations — gate: basic

## B2 — workspace.personal + workspace.organisations (27 Oct 2026, compact se pehle likha)
Kya likhunga: `wsx_core.rs` (std-only tests: slugify, normalize_org_domain [anexomail.com mana, company.com format], personal/business slug, name>=2) + `wsx_glue.rs` (Tokio async): `workspace.personal` (existing org => stamp kind + {existing:true}; warna organisations insert [owner_id retry], org_members upsert [status retry; fail => rollback delete], account_organisations + account_org_members upsert, orgs upsert, mail_accounts attach, account_profiles.preferences.workspace_kind + onboarded) aur `workspace.organisations` (name, domain). `POST /workspace/invitations` ALAG nahi: Rust `team.invites.create` (team_glue) pehle se hai, Bun route sirf uska fallback — map lag.
Technology: React form (onboarding.tsx / claim.tsx / auth.tsx / ConvertToBusiness.tsx) -> `rpcOrRest` -> WASM kernel -> Rust Tokio -> Supabase REST (PostgREST) ; Bun sirf fallback. Domain errors 400/409 (Rule 59), 404 sirf unknown_proc.
Gate: sab plans (login). Koi Pro gate nahi. UI mirror: kuch nahi badalta, sirf call-sites.
Frontend technology (jo ban chuki + jo aayegi): React 19.2 + TanStack Start/Router/Query + Vite 8 + Tailwind 4 + TS 5.8 (live); WASM kernel web-wasm v0.2.0 (live); three/R3F/drei/postprocessing/GSAP/motion/lottie (installed, landing/loader/CRM stage/globe); aane wali: WebGPU+TSL, ScrollTrigger+Lenis, Theatre.js, Rapier, Rive, WebXR (Rule 60, Business+, K3 ke baad). Kaam wale screens cinematic NAHI.

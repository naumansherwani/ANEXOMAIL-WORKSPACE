# Package surface matrix (generated from `src/lib/plan-surface.ts`)

Regenerate: `TOOLS=/opt/npm-tools/node_modules node docs/cursor-work/founder/tools/plan-surface-matrix.mjs > docs/cursor-work/founder/plan-surface-matrix.md`. Rule 5: this is what the CODE says; it is not proof of what a live account sees.

`personal` is what Basic and Pro buyers get by default; `business` is what Business / Business Pro buyers get. A cell is ✔ when the rail item shows.

| Rail item | basic · personal | basic · business | pro · personal | pro · business | business · personal | business · business | business_pro · personal | business_pro · business |
|---|---|---|---|---|---|---|---|---|
| Dashboard | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Mail | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| People | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Calendar | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Work | ✔ | — | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| CRM | — | — | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Org | — | — | — | — | — | ✔ | — | ✔ |
| Domains | — | ✔ | — | ✔ | — | ✔ | — | ✔ |
| Safety | — | — | ✔ | — | ✔ | — | ✔ | ✔ |
| ANEXOChat | — | — | ✔ | — | ✔ | ✔ | ✔ | ✔ |
| _Pro mail tools_ | — | — | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| _Multiple identities_ | — | — | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| _Full video_ | — | — | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| _CRM collab_ | — | — | ✔ | — | ✔ | ✔ | ✔ | ✔ |
| _CRM activity ledger_ | — | — | ✔ | — | ✔ | — | ✔ | ✔ |
| _CRM risk_ | — | — | ✔ | — | ✔ | ✔ | ✔ | ✔ |
| _CRM graph_ | — | — | ✔ | — | ✔ | — | ✔ | ✔ |
| _Work business record_ | — | — | ✔ | — | ✔ | ✔ | ✔ | ✔ |

## Package names the user sees

| plan · kind | copy name |
|---|---|
| basic · personal | Personal Basic |
| basic · business | Basic |
| pro · personal | Personal Pro+ |
| pro · business | Pro |
| business · personal | Personal Pro+ |
| business · business | Business |
| business_pro · personal | Personal Premium |
| business_pro · business | Business Pro |

## What a locked page says (denial copy), per package

**basic · personal** (Personal Basic)
- **CRM** → “Full CRM is on Personal Pro”
- **Org** → “Organisation centre is a Business workspace”
- **Domains** → “Company domains are on a Business workspace”
- **Safety** → “Safety centre is on Personal Pro”
- **ANEXOChat** → “ANEXOChat is on Personal Pro”

**basic · business** (Basic)
- **Work** → “Work is on Pro”
- **CRM** → “CRM is on Pro”
- **Org** → “Organisation centre is on Business”
- **Safety** → “Safety centre is on Business Pro”
- **ANEXOChat** → “ANEXOChat is on Business”

**pro · personal** (Personal Pro+)
- **Org** → “Organisation centre is a Business workspace”
- **Domains** → “Company domains are on a Business workspace”

**pro · business** (Pro)
- **Org** → “Organisation centre is on Business”
- **Safety** → “Safety centre is on Business Pro”
- **ANEXOChat** → “ANEXOChat is on Business”

**business · personal** (Personal Pro+)
- **Org** → “Organisation centre is a Business workspace”
- **Domains** → “Company domains are on a Business workspace”

**business · business** (Business)
- **Safety** → “Safety centre is on Business Pro”

**business_pro · personal** (Personal Premium)
- **Org** → “Organisation centre is a Business workspace”
- **Domains** → “Company domains are on a Business workspace”

**business_pro · business** (Business Pro)
- nothing locked

## Plain-reading checks

- Basic · business sees Domains but not Work/CRM (a Basic company account gets the domain tool without the tools that use it)

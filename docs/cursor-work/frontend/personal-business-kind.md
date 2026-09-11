# Personal vs Business — Polar pe naya product NAHI

**Status:** READY (repo). **DONE** nahi — pull + SQL phase65 + Masood/Humza live look.

**Mashwara (locked):** Personal Polar cards / landing Personal section **mat banao**. Paise wahi 4 Polar SKUs se aate hain. Kind backend session pe hai.

## Do axes (mix nahi)

| Axis | Kahan | Kya hai |
|---|---|---|
| **Money** | Polar + `plans.ts` **no-touch** | Basic £23 · Pro £46 · Business £97 · Business Pro £2,850 |
| **Kind** | `account_profiles.preferences.workspace_kind` + session `account_kind` | `personal` \| `business` |

Landing wahi 4 cards. Checkout ke baad: **Create your account for workspace → Personal | Business**.

## Default (jab kind explicit na ho)

| Polar SKU | Kind | Workspace feel |
|---|---|---|
| `basic` / `pro` | personal | Masood = Personal Pro buyer |
| `business` / `business_pro` | business | Humza = Business Pro buyer |

Slug `personal-*` bhi personal. Explicit `workspace_kind` jeet’ta hai.

## Power vs presentation

**Personal Pro = Business Pro power.** Sirf use-case alag:

- Personal: Org rail **nahi**. Book = “Your book”. Team follow-through **nahi**.
- Business: Org + company chrome. Humza = shared/company book.

Premium (copy) = Polar **Business Pro** SKU + kind personal. Naya Polar ID nahi.

## Buyers (family tester UI nahi)

| Login | Polar SKU | Kind | Rail |
|---|---|---|---|
| Masood | `pro` | personal | Mail People Calendar Work CRM Chat — **Org nahi** |
| Humza | `business_pro` | business | + Org + Chat + CRM shared/activity |
| Raana | AI Exec → platform Biz Pro | business | mail host = Biz Pro UX, LEO nahi |

## Files

- Session: `server/routes/auth.ts` → `user.account_kind`
- Stamp: `POST /api/workspace/personal` \| `/organisations`
- Gates: `src/lib/plan-surface.ts` (`featurePlan`, `surfaceFromSession`)
- SQL video Pro+: `docs/cursor-work/sql/phase65_account_kind.sql`

E4 mail-gate ke baghair rooms khali reh sakti hain — yeh fail nahi.

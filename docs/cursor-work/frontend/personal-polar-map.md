# Personal pay — separate Polar products

**Status:** READY (repo). **DONE** nahi. Polar Rust webhook no-touch. SQL: `docs/cursor-work/sql/E13_personal_polar_products.sql`.

Do axes mix nahi:

1. **Kind** (signup): Personal | Business — `account_kind`. Polar product nahi.
2. **Paise** (signed-in `/app/billing`): Personal Basic £17 · Personal Pro+ £83 · Personal Premium £1,850.

Public home aur `/plans` par Business cards unchanged hain. Personal prices sirf signed-in Personal Billing par hain.

| Personal Polar product            | Kind     | Workspace naam       | Canonical power                                    |
| --------------------------------- | -------- | -------------------- | -------------------------------------------------- |
| Personal Basic £17 / £187         | personal | **Personal Basic**   | `basic`; Chat/full CRM nahi                        |
| Personal Pro+ £83 / £913          | personal | **Personal Pro+**    | `pro` billed; Business Pro feature power; Org nahi |
| Personal Premium £1,850 / £18,500 | personal | **Personal Premium** | `business_pro`; Org nahi                           |

Six Personal keys checkout ko alag price dete hain, lekin entitlement existing `basic` / `pro` / `business_pro` values mein rehta hai. Is se mail, CRM, chat aur video gates stable rehte hain.

Business account Personal key use nahi kar sakta; guest Personal checkout bhi blocked hai. Missing Polar ID par checkout fail-closed hota hai.

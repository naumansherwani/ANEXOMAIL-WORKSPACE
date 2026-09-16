# Personal Polar Plans — Safe Separation Plan

## Maqsad
Signed-in Personal account ke Billing page par sirf teen independent Personal plans dikhane aur checkout karwane hain. Public home, `/plans`, existing Business products/prices, AI/founder surfaces aur Polar Rust webhook bilkul unchanged rahenge.

## Personal product truth
| Personal plan | Monthly | Yearly | Existing feature power |
|---|---:|---:|---|
| Personal Basic | £17 | £187 | Basic; Mail, People, Calendar, personal Work; ANEXOChat/full CRM nahi |
| Personal Pro+ | £83 | £913 | Business Pro power; ANEXOChat, CRM, video; Company Org nahi |
| Personal Premium | £1,850 | £18,500 | Business Pro power plus current Premium storage/file limits; Company Org nahi |

Yearly cards full annual totals dikhayenge, `/mo` effective amount nahi. Basic aur Pro+ par 1 month free; Premium par 2 months free.

## Kaam
1. **Personal catalog alag karna**
   - Personal tier source ko naye prices, `Personal Pro+` name, exact annual totals aur existing feature gates ke saath update karna.
   - Personal checkout keys ko six distinct keys banana: monthly/yearly for Basic, Pro+ and Premium.
   - Existing Business keys aur `WORKSPACE_PLANS` byte-for-byte pricing truth ke taur par unchanged rakhna.

2. **Checkout aur payment safety**
   - Backend registry mein six Personal products add karna; unke Polar IDs server environment se lazmi load honge.
   - Missing/unknown Personal ID par checkout fail-closed hoga; kisi Business product ya cheap fallback par nahi jayega.
   - Checkout metadata mein Personal account kind preserve karna, magar entitlement plan existing safe values `basic`, `pro`, `business_pro` hi rahenge. Is se current CRM/chat/mail gates nahi tootenge.
   - Signed-in Personal checkout ko server-side account-kind check se bind karna; Business account Personal price use nahi kar sakega. Guest Personal checkout expose nahi hoga kyun ke Personal cards public pages par nahi honge.

3. **Database payment truth**
   - Nayi E-series migration mein six Personal price-book rows add karna; protected Phase 43/60–65 files touch nahi karna.
   - Exact amounts, cycles, annual rules, canonical entitlement plans aur Personal account-kind requirement database mein enforce karna.
   - Migration idempotent hogi, grants/RLS existing price-book model ke mutabiq rahenge, aur Polar IDs absent hon to gap report sach batayegi.

4. **Personal Billing polish**
   - Personal account par duplicate “All plans” Business section hata kar sirf teen Personal cards aur ek shared monthly/yearly switch dikhana.
   - Personal cards full feature lists expandable form mein dikhayenge; current/recommended state aur upgrade/downgrade wording tier rank se niklegi.
   - Business account par existing four Business cards, prices, features aur checkout behavior unchanged rahega.

5. **Polar copy-paste guide**
   - Personal Basic, Personal Pro+ aur Personal Premium ke six Polar products ke exact names, descriptions, GBP prices, billing intervals, metadata aur environment-key placeholders document karna.
   - IDs banne ke baad sirf documented environment lines aur E-series ID update block paste karna hoga; secrets print/store nahi honge.
   - Status `READY` rahega jab tak IDs, migration, deploy aur real checkout proof complete na hon.

## Technical scope
Expected edits: `src/lib/personal-tiers.ts`, `src/routes/app.billing.tsx`, `server/config/billing-products.ts`, `server/routes/billing-sync.ts`, a new `docs/cursor-work/sql/E*.sql`, Personal Polar documentation/index, and focused tests. `src/lib/plans.ts`, public landing routes, existing Business product rows/IDs, protected blueprints, Phase 43/60–65, `.env`, and `server/rust/polar-payment/main.rs` will not be edited.

## Verification
- Typecheck/lint/format and focused product-registry tests.
- Browser proof: Personal account shows exactly 3 cards; Business account shows existing 4 cards; yearly totals are £187, £913, £18,500.
- Endpoint proof: Business account cannot open Personal checkout; missing Personal Polar ID fails closed; configured ID opens the same existing secure checkout flow.
- Database proof after founder runs E-series SQL: six rows, exact prices/cycles, zero amount mismatch.
- Live payment/webhook entitlement proof is not claimed until deployment and a real/discounted Polar checkout completes.

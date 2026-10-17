# UI harness (sandbox verification, not shipped)

Asli page code (`src/routes/app.domains.tsx`) + asli `src/styles.css` ko sandbox mein build karke Chromium mein screenshot leta hai. Server, `vite.config.ts` ya `package.json` ko nahi chhuta. Nakli data `stubs/` mein hai.

**Zaroori:** yeh sandbox ke paths par chalta hai (`TOOLS=/opt/npm-tools/node_modules` mein esbuild, tailwindcss, playwright, `CHROME=/opt/pw-browsers/chromium-1194/...`). Founder ke server par chalane ki cheez nahi.

```bash
cd docs/cursor-work/frontend/ui-harness
OUT=<koi khali folder>
node build.mjs $OUT                       # esbuild + Tailwind compile
node shot.mjs $OUT <name> <hash> [w] [h] [steps...]
# hash: empty (default) | list | hosted | loading | error | fast
# steps: click:<text> | fill:<placeholder>=<value> | wait:<ms> | scroll:<top|bottom|px> | shot:<file.png>
# DOH=namecheap|cloudflare|godaddy|none  -> registrar-detect (DNS-over-HTTPS) ka nakli jawab
```

Misal: `DOH=namecheap node shot.mjs $OUT wiz empty 390 844 "click:Connect probuyer" wait:800 "click:Continue" wait:1300`

Nateeja sirf **READY** hai: stubs asli backend nahi, aur founder ka browser alag ho sakta hai (Rule 5). Naya page add karna ho to `stubs/` mein uske imports ka stub aur `build.mjs` ke alias mein ek line.

**Dashboard scenarios (`#dash…`):** `dashmail` / `dashnomail` / `dashnoanalytics` (setup checklist), `ios` (install hint), founder expiry watch (8o): `expok` | `expwarn` | `expcrit` | `expunknown` | `expstale` | `expnone` (report abhi nahi) | `expfail` (Rust nahi => tile chup) | `nofounder` (tile chup). Misal: `TOUCH=1 node shot.mjs $OUT crit dashexpcrit 390 844`.

## Asli ComposeStudio (17 Oct 2026)

`build.mjs` ab `ComposeStudio.tsx` ko asli code se bundle karta hai (stub nahi): sirf data/network wali libs `stubs/compose-libs.ts` se aati hain, `Label` ke liye `stubs/radix-label.tsx`.
Phone par dekhne ke liye (touch + keyboard-jitni choti screen):

```
TOUCH=1 node shot.mjs <outDir> rc2-390 '#compose' 390 844
TOUCH=1 node shot.mjs <outDir> rc2-390-kb '#compose' 390 480
node shot.mjs <outDir> rc2-820 '#compose' 820 1180
```
(`into:<label>=<text>` step se field mein likha ja sakta hai.) Hash/route ke naam ke liye `entry.tsx` dekho.

## Naye steps / scenarios (17 Oct 2026, 8d/8e/8f)

- `btn:<exact button name>` — role=button, exact (jaise `btn:Send`). `ff:<ms>` — fake clock aage (`CLOCK=1` zaroori; 30 DNS polls = 10 min ek step mein).
- Domains hash: `list` (verified + pending domain + address), `list-stuck` (verify kabhi aage nahi barhta), domain naam mein `taken` => `domain_taken`.
- Compose stub ab send par foran success deta hai (post-send states dekhne ke liye).

```
node shot.mjs <out> q-mine list 1440 900 "click:Connect a domain" "fill:company.com=acme-studio.com" "click:Continue"
CLOCK=1 TOUCH=1 node shot.mjs <out> q-stuck list-stuck 390 844 "click:Continue setup" "click:I've added them" "ff:640000" "into:Still not found"
TOUCH=1 node shot.mjs <out> q-sent list 390 844 "click:Write the test email" "btn:Send" "wait:800" "into:Your first email is on its way"
```

## Public site (M5 funnel audit)

`ENTRY=entry-site.tsx node build.mjs <outDir>` builds the *public* routes (asli `src/routes/{index,plans,get-started,onboarding,auth}.tsx` + `src/components/site/*`) with the same Tailwind CSS. Hash picks the page: `#home | #plans | #getstarted | #onboarding | #auth` (query ok: `#auth?mode=signup|forgot|reset`; add `-signed` style via `#signed`). Stubs: `stubs/motion.tsx` (framer-motion/motion/react → plain elements), `stubs/site-libs.ts` (api/auth/i18n/locale/react-query), `stubs/router.ts` (Link, `Route.useSearch()` through the route's own `validateSearch`), `stubs/radix-checkbox.tsx`.

Overflow check at any width (finds elements past the viewport):
`FULL=1 TOUCH=1 node shot.mjs <outDir> <name> home 820 1180` → read the `page: {scrollW, winW}` line — `scrollW > winW` means horizontal overflow (with `isMobile` the layout viewport silently grows, e.g. 820 → 980).

## Asli /app routes (M6 audit, 17 Oct 2026)

`ENTRY=entry-routes.tsx node build.mjs <outDir>` bundles the *real* signed-in route files (`src/routes/app.{calendar,people,work}.tsx` + their components) with sample data from `stubs/api-sample.ts` (`stubs/query.ts` = react-query stand-in, `stubs/router.ts` = reactive router so `?id=` / tab navigation works on click). Hash picks the route (`billing?state=active|past_due|cancelled|none`, `billing-personal`, `account?del=1|blocked=1`): `cal | people | people?id=c1 | work | crm | crm/pipeline | crm/leads | crm/relationships | crm/collab | crm/activity | crm/tasks | crm/reports | crm/accounts`; suffix `-basicplan` (Basic: no Promises rail) and `?empty=1` (empty states). CRM data is mutable in the harness (`crm.moveDeal` really moves a deal; `stubs/query.ts` re-runs active queries on invalidate).

```
ENTRY=entry-routes.tsx node build.mjs $OUT
TOUCH=1 node shot.mjs $OUT cal-390 cal 390 844                   # hash WITHOUT '#': shot.mjs adds it
TOUCH=1 node shot.mjs $OUT cal-detail cal 390 844 "click:Customer"   # event kholo -> poori screen + back
TOUCH=1 node shot.mjs $OUT people-390 'people?id=c1' 390 844
node shot.mjs $OUT work-820 work 820 1180
TOUCH=1 node shot.mjs $OUT crm-pipe 'crm/pipeline' 390 844            # CRM pages render inside the real CrmStage nav
```
Naya route add karna: uska import `entry-routes.tsx` ke route map mein, sample data `stubs/api-sample.ts` mein, aur agar naya lib import ho to `build.mjs` ke alias mein ek line.

**Admin (ENTRY=entry-routes.tsx):** `admin-members`, `admin-teams` (+ `?empty=1`, `?err=1` = endpoint 404 "aren't live yet" state, `&role=member|admin` = non-owner view). AlertDialog stub ab real class strings use karta hai (`stubs/ui.tsx`), `click:Remove` / `click:Delete` se dialog khulta hai.

## Locked-page wall (PlanSurfaceGate, 17 Oct 2026)

`#<page>?gate=1&plan=basic|pro|business|business_pro[&personal]` renders the REAL `PlanSurfaceGate` for `/app/<page>` (e.g. `#chat?gate=1&plan=basic&personal`, `#crm/collab?gate=1&plan=pro`, `#safety?gate=1&plan=business`). When the package already opens the page you see "THE REAL PAGE OPENS HERE". Kind is `business` unless the hash contains `personal`. Plan regex lists `business_pro` before `business` on purpose (otherwise `business_pro` silently became `business`).

`#cal` + a file chosen into `input[type=file]` drives the .ics import panel (`#cal?imperr=1` makes every "Standup" fail to shoot the partial-failure state).

`#dashboard[?plan=…][&personal][&empty=1][&nofounder]` renders the REAL `src/routes/app.index.tsx` (Greeting, SetupChecklist, KPI tiles, panels) on `api-sample.ts` data; `empty=1` = brand-new account, `nofounder` hides the founder-only Expiry Watch. CSS entrance animations (`ax-stagger`) take ~0.6 s: shoot with `wait:1500` or the last tile looks missing.

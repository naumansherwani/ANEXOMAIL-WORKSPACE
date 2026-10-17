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

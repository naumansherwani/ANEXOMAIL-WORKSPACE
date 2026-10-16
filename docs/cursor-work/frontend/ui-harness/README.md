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

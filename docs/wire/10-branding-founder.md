# STEP 10 — BRANDING: sirf founder ka naam (koi build-platform credit nahi)

Rule: repo aur website par sirf **Muhammad Nauman Sherwani** (founder) aur
ANEXOMAIL / ANEXOChat / ANEXOVideoCall ka naam. Build platform ka naam, logo ya
credit kisi doc, comment, UI copy ya asset mein nahi.

## 10.1 — Repo se naam nikalna (repo mein pehle se ho chuka hai — READY)

Yeh cheezein repo mein already saaf kar di gayi hain:

| Jagah                                  | Pehle                                   | Ab                                        |
| -------------------------------------- | --------------------------------------- | ----------------------------------------- |
| `AGENTS.md`                            | platform block                          | Founder rules + wire rule + branding rule |
| `anexochat/docs/anexochat-blueprint.md`| "Lovable Suggestions / READ THIS FIRST" | "Founder Suggestions / FOUNDER — READ…"   |
| `anexochat/README.md`                  | same heading                             | Founder Suggestions                       |
| `docs/polar-rust-payment.md`           | guardrail heading mein platform naam    | sirf "kisi bhi agent ke liye"             |
| `src/lib/lovable-error-reporting.ts`   | file + `reportLovableError`             | `src/lib/error-reporting.ts` + `reportClientError` |
| `src/lib/plans.ts`, `src/components/site/AiCreditMeter.tsx`, `src/lib/pwa.ts` | comments mein platform naam | neutral comments |

## 10.2 — Jo technical majboori hai (jaan bujh kar chhoda gaya)

Yeh 3 jagah naam hataana **build tor deta hai**, is liye chhoda gaya — awam ko yeh
kahin nazar nahi aata:

1. `package.json` / `vite.config.ts` / `bunfig.toml` → `@lovable.dev/*` build packages.
2. `src/lib/error-reporting.ts` → `window.__lovableEvents` / `__lovableReportRuntimeError`
   (sirf editor preview mein mojood; production par undefined).
3. `src/lib/pwa.ts` + `src/lib/host.ts` → preview host suffixes, jinse preview par
   PWA/founder-bar band rehte hain.

## 10.3 — Website par koi platform badge nahi

Published site par platform ka badge/logo **off** hona chahiye.

Verify (browser, published site par):

```sh
curl -s https://anexomail.com | grep -ic "lovable" || echo "0 = green"
```

Green = `0`.

## 10.4 — Repo verify command

Server par:

```sh
cd /opt/anexomail-web && git pull
rg -i "lovable" . -g '!node_modules' -g '!.git' -g '!bun.lock*' -g '!*.tsbuildinfo' \
  -g '!package.json' -g '!vite.config.ts' -g '!bunfig.toml' \
  -g '!src/lib/error-reporting.ts' -g '!src/lib/pwa.ts' -g '!src/lib/host.ts' \
  -g '!AGENTS.md' -g '!docs/wire/10-branding-founder.md'
```

Green = **zero output**. Koi line aaye = us jagah naam abhi baqi hai, wahi theek karni hai.

## 10.5 — UI par founder naam kahan likha jata hai

- Footer: ANEXOMAIL (parent company ka zikr public par nahi).
- Founder surfaces: `founderworkspace.anexomail.com` → `/app/founder`
  (`naumansherwani.founder@anexomail.com`).

Status ledger `docs/wire/README.md` mein update hota hai — 10.3 ka `0` aur 10.4 ka
zero output aane ke baad hi DONE likha jayega.

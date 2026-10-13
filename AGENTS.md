# ANEXOMAIL Workspace — Agent Rules

**Founder:** Muhammad Nauman Sherwani (NEXATECT Global Ltd, internal only — public copy mein NEXATECT ka zikr nahi).

---

## TECHNOLOGY CONSTITUTION (locked — touch nahi)

| Layer | Technology |
|---|---|
| Host | Hetzner only |
| Edge | Caddy — HTTPS + HTTP/3 |
| Frontend | React 19.2 |
| Router / SSR | TanStack Start v1 (router 1.17.0) |
| Build | Vite 8.2 |
| CSS | Tailwind v4.2 (`src/styles.css`) |
| UI | Radix + shadcn/ui |
| Animation | Framer Motion, GSAP, Three.js |
| SSR runtime | Bun — Nitro bun preset |
| PM2 interpreter | bun |
| Frontend port | 3000 |
| Backend PRIMARY | Rust :3200 — Tokio async, WebTransport, QUIC, tRPC, PostgreSQL. **Har naya phase yahi (locked 12 Sep 2026).** |
| Backend FALLBACK | Bun :3100–3300 — **fallback total**. Naya Bun-primary **nahi**. |
| Emergency only | Node 22 (normal kaam mein nahi) |
| Database | Supabase / PostgreSQL (source of truth) |
| Mail | Postfix / Dovecot / OpenDKIM (Hetzner pe installed) |
| Payments | Polar — Rust webhook (PM2 mein) |

**Constitution violations banned:** WebContainer, Supabase Realtime/WebSocket (unless already exists + founder approve), mock backend, fake success states.

---

## HOST MAP (locked)

| Domain | Surface | Users |
|---|---|---|
| `anexomail.com` | Public mail workspace | Awam (registered users) |
| `ai.anexomail.com` | AI workspace (LEO) | Awam — Coming Soon publicly |
| `founderworkspace.anexomail.com` | Owner protocol | Sirf Nauman |

`src/lib/host.ts` browser mein `window.location.hostname` check karta hai — yeh browser-side code hai, alag server nahi.

---

## TARTEEB (build order — locked)

1. `anexomail.com` — awam mail product (real login, real send/receive)
2. Founder workspace — `founderworkspace.anexomail.com`
3. AI — `ai.anexomail.com` (Coming Soon for awam)
4. ANEXOChat Phase 1–31A — live wire
5. ANEXOChat Phase 32+ — sirf founder ke paste karne pe
6. GitHub → Server 2 pull

---

## RULES (sab locked)

### Rule 1 — GitHub is source of truth
Sab kuch GitHub repo mein. Server sirf pull karta hai. **Founder pull command locked** — ALWAYS `--rebase`, NEVER `--no-rebase`. Ek `&&` block only:
```bash
cd /opt/anexomail-web && git restore src/routeTree.gen.ts && git pull --rebase origin main && bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save && curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
```
Agent `web /health` **200** confirm kare.

### Rule 2 — No local clone on agent
Agent sirf GitHub repo read karta hai, push karta hai. Server pull karta hai. Agent ke pass kuch nahi.

### Rule 3 — No code without founder approval
Ek bhi file tab tak nahi banti jab tak founder "Phase N shuru karo" na bole.

### Rule 4 — No touch (locked items)
- Landing pages, logo, existing UI
- Polar Rust payment webhook (already fixed by founder)
- `package.json` / `vite.config.ts` / `bunfig.toml` build packages
- `.env` / secrets

### Rule 5 — Status sirf teen
- **DONE** — live test hua (green verify command)
- **READY** — repo mein, server par nahi
- **TODO** — abhi nahi bana

"Implemented" / "Locked" / "Working" kehna banned hai jab tak verify green na ho.

### Rule 6 — No mix, no duplicate
- ANEXOChat aur ANEXOMAIL mix nahi
- Lovable / ChatGPT / Grok suggestions nahi banane jab tak founder original block paste na kare
- Duplicate systems nahi

### Rule 7 — Blueprint law
- ANEXOMAIL phases → `docs/anexomail-blueprint.md` (founder paste karay)
- ANEXOChat phases → `anexochat/docs/anexochat-blueprint.md`
- Phase 32+ sirf founder paste karne pe

### Rule 8 — cursor-work folder
Ab se sab kaam `docs/cursor-work/` mein:
- Naya SQL → `docs/cursor-work/sql/`
- Frontend log → `docs/cursor-work/frontend/`
- Server commands → `docs/cursor-work/server/`
- Founder phases → `docs/cursor-work/founder/`
- AI phases → `docs/cursor-work/ai/`
- ANEXOChat 32+ → `docs/cursor-work/anexochat/`

**SQL fail rule (locked):** Fail ho to **usi file** ko shuru se theek likho. Naya naam (`phaseNNb`, `_fix`, `_v2`) **banned**. Duplicate patch file delete.

**Phase 60s no-touch (locked 11 Sep 2026):** `sql/phase60–62` aur `docs/cursor-work/sql/phase63–65` founder blueprint hain. Agent edit / rewrite / dubara-run **nahi**. Naya SQL = E-series `docs/cursor-work/sql/E<n>_….sql` (`ANEXOMAIL-EXECUTE.md`).
### Rule 9 — Wire rule
Har wiring ka record `docs/wire/` ya `docs/cursor-work/` mein. Status sirf DONE / READY / TODO.

### Rule 10 — Branding rule
Repo mein sirf founder + ANEXOMAIL/ANEXOChat/ANEXOVideoCall ka naam. Build-platform ka naam, logo ya credit kisi doc, comment, UI copy ya asset mein nahi.

### Rule 11 — Git history
Force push, rebase/amend/squash on pushed commits banned. Connected branch hamesha working state mein rahe.

### Rule 12 — Blueprint protection (locked — touch nahi)
ANEXOMAIL aur ANEXOChat blueprints HAMESHA alag rahenge. Kisi bhi agent/session ko yeh files delete, overwrite, ya merge karne ki ijazat nahi.

| File | Kya hai | Status |
|---|---|---|
| `docs/anexomail-blueprint.md` | ANEXOMAIL workspace blueprint (Phase 1–62+) | PROTECTED |
| `anexochat/docs/anexochat-blueprint-original.md` | ANEXOChat Phase 1–57 founder original | PROTECTED |
| `anexochat/docs/anexochat-blueprint-original-with-added-features.md` | ANEXOChat Phase 1–57 + Founder Suggestions + Proof Mode + WOW-FACTOR | PROTECTED |

**Delete ban.** **Mix ban.** **Rename sirf founder ke kehne pe.**
ANEXOChat Phase 32+ build sirf tab jab founder original `## PHASE N` text paste kare.

### Rule 13 — Mail send + receive gate (locked 10 Sep 2026)
Asli email **bhejni aur aani** ke baghair agla flow nahi.

- **F5 thread / F6 contacts / F7 calendar / F8 work / F9 founder polish / ANEXOChat 32+ / AI** — wait
- Awam Basic + Pro + Business — **mail included** (chat alag; Basic/Pro ko email nahi katni)
- Proof: website se send → Postfix → bahar; bahar se receive → Postfix/Dovecot pipe → inbox list
- Status **DONE** sirf `bash server/gates/mail-gate.sh` green + founder ne live send/receive dekha

### Rule 14 — Kaam ki tarteeb LOCKED (locked 11 Oct 2026)
Ek hi list: `docs/anexomail-blueprint.md` → section "11 Oct 2026 — remaining work" (27 items; dusri queue nahi). `docs/cursor-work/server/PLAN-order-2026-10-11.md` sirf us ki copy hai; farq ho to blueprint jeetta hai. Tarteeb **#1 se #27**, section A (#1–#10) pehle.

- Agent **skip nahi** karta, aage nahi jata, naya kaam shuru nahi karta jab tak founder na kahe ya pehle wala item DONE na ho.
- Naya kaam pehle list mein likho, phir tarteeb mein; chupke se beech mein nahi.
- Item **DONE** sirf live verify (green output) par; warna READY ya TODO (Rule 5).
- Server par poora `git pull` nahi: sirf specific files, sha-gated installer, backup + `restore.sh`.
- Har deploy mein build ke baad `pm2 restart anexomail-web --update-env && pm2 save` hamesha.
- Server 1 (main brain) sensitive: agent wahan kuch chalane ko nahi kehta.
- Repo `main` par push sirf founder ke "repo update" kehne par; live-only files (jo GitHub par nahi) pehle repo mein aayen, phir overwrite.

### Rule 15 — Server ka sach server par (locked 14 Oct 2026, founder)
Repo sirf update ki machine hai, sach nahi. Server par jo code/state dekhna ho (live file, diff, pm2, logs, DB) uske liye agent **seedha chat mein command deta hai**, founder server par chalata hai aur output paste karta hai. Agent repo ko live ka sabut nahi maanta, aur "repo == server" ka andaza nahi lagata.
- Command chat mein, ek block, copy-paste ready. Agent khud server par kuch nahi chalata.
- **Delivery ka asli tareeqa (founder, 14 Oct):** server hi backend + frontend hai. File badalni ho to chat mein base64 payload (`echo '<b64>' | base64 -d > <server path>`, pehle `.bak`), SQL ho to seedha server se PostgreSQL par (`. /etc/anexomail/sync.env && psql "$WORKING_URL" ...`). Fix ke liye GitHub pull ka intezar nahi. Repo sirf copy/update ki machine hai.
- Gate/"PASS PASS" scripts founder ko nahi dene; asli output wale seedhe commands (curl code, grep, psql, pm2).
- Mismatch ho to pehle live ka output manga kar dekhe, phir faisla.

---

## PENDING (founder action required)

| Item | Action |
|---|---|
| MAIL send+receive | **GREEN 27 Sep 2026** — founder confirmed send and receive both live. Do not reopen. |
| ANEXOMAIL blueprint (59 phases) | **Founder paste kare** → `docs/anexomail-blueprint.md` banegi |
| SQL phase60/61/62 | Supabase #4 SQL Editor mein paste karo (tarteeb se) |
| Server pull | `git pull && bun install && bun run build:bun && pm2 restart...` |

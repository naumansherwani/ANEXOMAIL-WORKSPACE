# F3 B — Cinematic mail (ideas only) + UI backup

**Status:** TODO (ideas freeze). Visual rebuild tab jab founder **“cinematic mail UI — Phase shuru”** bole.  
**Landing / logo / `plans.ts` / Polar — no-touch.**  
**Backup tag:** `backup-ui-20260910-lovable-shell` = commit `7dd210b` (wapis laane ke liye).

---

## Backup (server pe yeh, ek dafa)

Current Lovable-mix shell save:

```bash
cd /opt/anexomail-web
git fetch origin
git tag backup-ui-20260910-lovable-shell 7dd210b
git push origin backup-ui-20260910-lovable-shell
```

Wapis:

```bash
cd /opt/anexomail-web
git checkout backup-ui-20260910-lovable-shell -- src/components/app src/routes/app.index.tsx
# ya poori tree: git checkout backup-ui-20260910-lovable-shell
bun run build:bun && pm2 restart anexomail-web
```

---

## Goal (kyun cinematic)

Awam bole **wow** — Gmail clone / dashboard-of-zeros nahi.  
Pehli 3 second: **mera mail, mera naam, compose**. Leo / CRM / Org / Speed yahan nahi.

---

## Ideas (wire nahi — choose later)

1. **Mail is the stage** — login splash → inbox. “Today” command center awam pe band.  
2. **One light** — compose button pe cyan bloom; chaar grey statistic cards nahi.  
3. **Honest empty** — “No mail yet” + Compose. “Inbox zero / nothing owes you a reply” poster nahi.  
4. **Motion budget** — list stagger ~40ms, page-wide GSAP circus nahi. Three.js mail pe nahi.  
5. **Type** — mailbox `humzasherwani@anexomail.com` top pe readable; greeting local-part hero nahi.  
6. **Rail lean** — Mail, People, Calendar, ANEXOChat (plan). CRM / Org / Work / AI / Speed / Admin / Founder = founder host ya Business settings.  
7. **Glass, not plastic** — existing dark + cyan; naya theme pack nahi.  
8. **Soundless cinema** — splash already hai; doosri movie mat daalo.

**Nahi:** landing redo, logo change, Leo widget, fake unread counts, NEXATECT.

---

## Host split (locked — ek codebase, teen host, per-user subdomain NAHI)

| Host | UI |
|---|---|
| `anexomail.com` | **Personal mail** (image 1): Mail, Chat, People, Calendar. Collapse rehta. Logo → inbox, landing nahi. |
| `ai.anexomail.com` | **Image 3** (Today, CRM, Org, Work, AI, Admin). Awam Coming Soon. Delete nahi — host alag. |
| `founderworkspace…` | Founder. |

**Humza / family:** `anexomail.com` pe **personal mail UI**. Business Pro = billing plan, alag website nahi.

**GREEN anexomail-leo :3100** = SSH deploy check. Website pe nahi.


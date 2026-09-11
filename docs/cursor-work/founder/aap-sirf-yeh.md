# Aap sirf yeh — E-series (investor pressure)

**Aap akela product nahi bana rahe.** Agent code likhta hai + GitHub. Aap **teen kaam**: paste · dekho · green/red bolo.

Packages alag apps **nahi**. Ek website. Test ke liye teen login:

| Login | Package | Investor ko dikhao |
|---|---|---|
| Masood | **Personal Pro** (Polar `pro`) | Mail People Calendar Work CRM Chat — Org nahi. Buyer, tester nahi |
| Humza | **Business Pro** | + Org + Chat + CRM Shared + Activity. Buyer |
| (Basic user jab ho) | **Personal Basic** | Chat/full CRM wall |

Aap Polar pe Personal product **mat** add karo. Kind backend pe hai.

Aap architecture mat socho. Har E pe agent kehte: yeh command chalao.

---

## Aapke teen kaam (hamesha yahi)

**1. Server — ek block paste** (vim khule to `:wq`)

```bash
cd /opt/anexomail-web && git pull --no-rebase origin main && bun install && bun run build:bun && pm2 restart anexomail-web && pm2 save
```

**2. Jab agent bole — mail (E4)**

```bash
cd /opt/anexomail-web && bash server/mail/deploy-mail.sh && bash server/gates/mail-gate.sh
```

Output yahan paste (password **mat**). GREEN/RED.

**3. Browser** — Masood / Humza kholo. Jo tootay: screenshot. Jo theek: **green**.

SQL tabhi jab agent file ka naam de (`docs/cursor-work/sql/…`) → Supabase #4 paste → Run.

**Ab:** `docs/cursor-work/sql/phase65_account_kind.sql` (Personal kind + video Pro+).

Masood **Invalid login credentials** = `.env` mein `MASOOD_PASSWORD` missing/galat. Password chat/GitHub mein **mat**. `bash server/accounts/create-accounts.sh` dubara.

---

## Tarteeb (aap skip mat karna)

E1 rail → E1A CRM → E2 session → E3 inbox → **E4 mail jaani+aani** → phir E5–E8.

E4 ke baghair rooms khali rehengi. Yeh fail nahi — mail pipe baaki.

**DONE** sirf aap **live green** bolo. Agent “working” nahi kahega.

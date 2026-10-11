# ANEXOMAIL — baqi kaam ki tarteeb (11 Oct 2026)

Maqsad: awam user kam se kam qadam mein product use kare (signup -> address -> send -> receive).
Status sirf DONE / READY / TODO. Sirf side branch; main sirf founder ke "repo update" par.

| # | Kaam | Status | Note |
|---|---|---|---|
| 0 | Founder/public alag: `resolved@` + DMARC thread basic account mein dikh rahe hain | TODO | diagnose SQL output chahiye -> E16 SQL |
| 1 | Mail cinema UI (chip, filter strip, groups, thread badge) | READY | server par load; screenshot par DONE |
| 2 | Outbound proof: company address se send, Sent thread, DKIM/SPF/DMARC (Gmail) | TODO | live worker repo se alag (server par uncommitted changes) |
| 3 | Backend: `/accounts` company addresses + `/schedule` identity org-check (security) | TODO | |
| 4 | Test accounts Pro/Business (4 packages asli buyer jaise) | TODO | |
| 5 | Naya buyer signup: workspace + member + trial plan + apna @anexomail.com address | TODO | sab se bara; naya phase = Rust |
| 6 | Part E: Compose "From" selector, Sent mein address | TODO | |
| 7 | Part D: domain wizard (3 scenes, DNS ticks, copy buttons) | TODO | A,B DONE; C receive DONE |
| 8 | Business Pro support 12h (phase63 -> E-series rename, polar.ts untouched) | TODO | |
| 9 | Browser checks (founder): CRM pages, 4 packages, Basic 11-point | TODO | founder ka kaam |
| 10 | Docs + repo main sync (live-only files samet) | TODO | sirf founder go-ahead |
| 11 | Purani mail import, founder side | TODO | user-side green ke baad |

Security (founder ke zimme): .env plaintext secrets, repo public, purana Supabase token revoke,
DB password rotate, test passwords rotate, git email.

Purani list ki do baatein ab galat/purani hain:
- "Domain system bana hi nahi": A (DB), B (Rust), C (server sync, receive side) ban chuke.
- "Worker Sent mein nahi likhta": repo main worker `mail_threads(folder: "sent")` likhta hai; live worker alag hai, test se pakka hoga.

# ANEXOMAIL vs Zoho Mail vs Google Workspace — asli user ka pehla din (17 Oct 2026)

Founder ka hukm (17 Oct 04:06 PKT): "CEO ki tarah socho, competitor Google aur Zoho hain; pehle dekho Zoho basic kaise karta hai, woh karo, phir ANEXOMAIL ko un se behtar banao." Yeh file sirf **verify ki hui** baaton par hai (official pages, 17 Oct 2026) aur repo mein jo mila (search se). Jo verify nahi hua woh "verify baqi" likha hai.

## 1. Competitor kya karte hain (official pages se)

**Zoho Mail** (`zoho.com/mail/help/adminconsole/domain-verification.html`, `.../adminconsole/`):
- Domain verify ke 4 tareeqe: **Domain Connect (ek click)** — page ke mutabiq IONOS by 1&1, GoDaddy, Cloudflare; **TXT**; **CNAME**; **HTML file** (khud unka page isay recommend nahi karta).
- **"Send to DNS admin":** verification ki hidayat kisi ke email par bhejna (IT / registrar / hosting wale ke liye) — jo user khud DNS nahi chhoota.
- Verify ke baad: MX lagao (zaroori), verification TXT/CNAME hata do (Zoho ki salah), propagation ke liye unke lookup tools.
- Poora flow: (domain khareedna optional) → verify → **users banana/import** → groups aur aliases → MX → **purani mail migrate** (IMAP/POP/PST/Exchange, migration wizard) → SPF → DKIM → **mail clients jorna** (IMAP/POP) → optional: catch-all, dual delivery, custom login URL → Admin Console controls.
- DNS host ki **auto-pehchan** unke is page par bayan nahi (provider-wise alag instructions hain, aur Domain Connect sirf unhi providers ke liye).

**Google Workspace** (`knowledge.workspace.google.com/admin/domains/verify-your-domain-for-google-workspace`):
- Setup tool se verification code milta hai, registrar par TXT lagana hota hai (page par yahi do raaste bayan hain).
- Pehle trial mein 9 din ke andar verify; na ho to unverified account 21 din mein delete.
- Record lagane mein ~10 minute, Google ko confirm karne mein aam taur par jaldi, **zyada se zyada ~1 ghanta**; DNS ka asli waqt registrar par.
- MX baad mein; page par MX ke qadam nahi (alag page hai — verify baqi).

## 2. ANEXOMAIL abhi kahan hai (repo + live, 17 Oct)

| Real user ka qadam | Zoho / Google | ANEXOMAIL abhi | Item |
|---|---|---|---|
| Domain jodna + 5 records (TXT, MX, SPF, DKIM, DMARC) | Haan | Haan, asli backend par live | #8 |
| Registrar **khud pehchanna** | Zoho ke page par nahi | **Haan** (NS dekh kar, subdomain par parent se) | 8b |
| Pehle se mail hai (Google/Microsoft) to **warning + SPF merge** | In pages par nahi dekha | **Haan** | 8c |
| Subdomain ke liye lamba Name khud | In pages par nahi dekha | **Haan** | — |
| DNS IT wale ko bhejna | Zoho: "Send to DNS admin" | **Haan** (email kholta hai + "Copy all as text") | 8g |
| DNS ke intezar mein user phansa na rahe | Dono mein intezar hi intezar | **Haan**: "aap ka inbox pehle se chal raha hai" + live ring + countdown | 8h |
| Ek click DNS (Domain Connect) | Zoho: GoDaddy, IONOS, Cloudflare | **Nahi** (provider ka template register karna padta hai) | 8l (founder decide) |
| Purani mail laana (IMAP import) | Zoho wizard; Google data migration | **Nahi self-serve**; `/migration` sirf managed service ka page hai | 8j |
| Mail client / phone (IMAP/SMTP) settings | Zoho: haan | **Nahi mili** (search: koi in-app page nahi; docs mein sirf import ka zikr) — verify baqi | 8i |
| Setup checklist / progress | Google "setup tool", Zoho flow | Dashboard par sirf "Finish setup" badge | 8k |
| Verify ke baad **pehli mail ka test** | Dono admin console par chhor dete hain | **Nahi** (Compose ka deep link nahi hai) | 8f |
| Catch-all, forwarding, vacation reply | Zoho: haan (catch-all, dual delivery) | **Nahi mili** (search) — verify baqi | 8m |
| Team: user/mailbox invite | Dono: haan | Org members hain (`src/lib/org.ts`); address ko member se jorna verify baqi | — |

## 3. Tarteeb (real user ke pehle din ke hisaab se)

1. **Domains ko asli verified tak pohanchana** (8d–8f, ek aur test domain par asli DNS) — jab tak user ka pehla email chalta nahi, baaqi sab bekaar.
2. **8f pehli mail ka test** (verified → "apne aap ko test mail bhejo" → aate hue dekhna). Yahan Zoho/Google dono user ko khali chhor dete hain; yeh hamara sab se asaan "wow" hai.
3. **8i IMAP/SMTP settings + app password** (phone/Outlook) — bina iske business user nahi tikta.
4. **8j self-serve IMAP import** (Zoho ke migration wizard jaisa) — purani mail ke bina switch nahi hota.
5. **8k dashboard checklist** (5 qadam, asli data se).
6. **8l Domain Connect** (founder decide; bahar ki registration chahiye).
7. **8m catch-all / forwarding / vacation**.
8. AI sab se aakhir mein (#41, founder ka locked order).

## 4. Jo ANEXOMAIL ko aage rakhta hai (product mein pehle se; marketing/ui mein dikhana hai)

Shared inbox collision guard, tasks/boards/CRM mail ke andar, promises, ANEXOChat, calendar, address-wise unified inbox. Competitor in cheezon ke liye alag app/plan bechte hain. UI mein har page par yeh "nateeja" dikhana (jaise Domains ke hero mein "From: you@company") hi asli farq hai.

## 5. Jo sirf founder dekh sakta hai (test account se nahi)

Asli payment aur provisioning (Ali ka personal account), asli registrar par DNS badalna (nayi domain par), bahar ki mail ka inbox/spam mein girna, asli phone ka tajurba, DKIM ka asli pass hona (Gmail "Show original").

## Sources
- Zoho Mail — Domain Verification: https://www.zoho.com/mail/help/adminconsole/domain-verification.html
- Zoho Mail — Email Hosting Setup (Admin Console): https://www.zoho.com/mail/help/adminconsole/
- Google Workspace — Verify your domain: https://knowledge.workspace.google.com/admin/domains/verify-your-domain-for-google-workspace

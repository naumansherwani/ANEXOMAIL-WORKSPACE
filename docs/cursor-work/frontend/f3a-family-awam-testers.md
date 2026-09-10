# F3 A — Family awam testers + passkey + recovery (founder lock)

**Date:** 10 Sep 2026 (chat lock — agent yahan se yaad kare)  
**Founder:** Muhammad Nauman Sherwani  
**Status:** READY (repo). **DONE** nahi — live proof: SQL paste + pull + family login + Face ID / recovery mail.  
**Passwords:** is file / GitHub / docs mein **kabhi nahi**. Sirf server env.

F3 = inbox list. **F3 A** = awam ki aankh + asli auth (passkey store, recovery, password change). **F4** = mail bhejna + aana. F3 founder-preview se naapo mat.

Caddy: **HTTPS**, **HTTP/3 pehle**, fallback **HTTP/2 + HTTP/1.1**. Passkey HTTP version se nahi tut’ti — galat host / HTTP / fake save se tut’ti hai.

Polar / `plans.ts` / landing / `host.ts` — **no touch**.

---

## Apple se advance — lock (haan, lekin jhoot nahi)

**Haan — ANEXOMAIL F3 A Apple se is jagah ADVANCE hogi** (product honesty + mail workspace):

1. **WebAuthn public key store** — Apple flag nahi chhodta; hum bhi `passkey_set` boolean ko Face ID nahi maante. Asal `credential_id` + public key + `sign_count`.
2. **Recovery mailbox alag** — reset us Gmail / iCloud / Outlook / jo user like kare par jaye. Apple ID kho jane par bhi rasta; hum `@anexomail.com` kho jane par user ko **apne hi mail** mein qaid nahi karte.
3. **Family vs awam** — testers bina Face ID force ke `anexomail.com` dekhain; awam Create account par Face ID **asli**. Apple is split ko product test ke liye nahi rakhta — yeh hamari advance.
4. **Device vault ≠ Face ID** — ek device se bar bar naya account nahi (ungli ka photo nahi). Dono gates alag, dono real.
5. **Fake green zero** — cancel / 501 / purana phone par “passkey saved” nahi. Apple bhi fail par success nahi dikhata; hum **zyada sakht**: NotImplemented ko live se pehle jhoot nahi.

**Nahi — yeh claim nahi** (warna Lovable wala dhoka):

- Hum Apple ka **Secure Enclave / iCloud Keychain server** nahi banate.
- Passkey **OS/browser** sync kare to theek; hum apna iCloud nahi.
- **Sign in with Apple** button nahi (social login band).
- SMS recovery sirf jab asli SMS pipe ho — jhoota phone tick nahi.

**Ek jumla:** Face ID / passkey **Apple-equal (real WebAuthn)**. Recovery + honest gates + family/awam split **Apple se advance**. Hardware magic **Apple jaisa dawa nahi**.

---

## 1. Teen testers (aam user — founder protocol nahi)

`anexomail.com` + email/password. `founder_accounts` **nahi**. Preview / `?founder=1` **nahi**. Apni organisation. Family mail founder inbox mein copy **nahi**.

| Kaun | Email | Plan | Real matlab |
|---|---|---|---|
| Father (Masood) | `masoodsherwani@anexomail.com` | **Pro** | Basic ke **saare** + Pro. Chat nahi. Alag Basic account nahi. |
| Brother (Humza) | `humzasherwani@anexomail.com` | **Business Pro** | Basic + Pro + Business. AI **nahi**. |
| Mother (Raana) | `raanasherwani@anexomail.com` | **AI Executive** | Business Pro platform + AI. Awam `ai.anexomail.com` Coming Soon; unka grant payment nahi. |

Founder: `naumansherwani.founder@anexomail.com` → `founderworkspace.anexomail.com`.

Lifetime / lamba grant Polar se nahi. Password change family ke liye chalu.

---

## 2. Do gates — mix nahi

| Gate | Kya hai | Family | Awam Create account |
|---|---|---|---|
| Password | login + change-password + forgot | **Lazmi rasta** | Pehla rasta |
| Passkey | WebAuthn is device (Face / Touch / Hello) | Signup **skip**; Account se optional Add | Device chalaye to **asli**; fake success nahi |
| Device vault | Sealed device pehchan | Script — signup jail nahi | Ek device, bar bar naya account **nahi** |

---

## 3. Passkey live (SQL mein pehle store nahi tha — F3 A banayegi)

Phase 32 `passkey_set` sirf nishaan hai. **F3 A naya store:**

- `credential_id`, **public key**, `sign_count`, user, device naam, created, last used
- Bun `:3100` (auth Rust nahi): `/api/auth/passkey/register/options` · `register/verify` · `options` · `verify`
- Register ke baad `passkey_set` **sach** (flag store ki jagah nahi)
- RP ID `anexomail.com` (www isi ID). Founder host par passkey mat banao
- Platform authenticator; USB key lazmi signup nahi
- Cancel = screen par ruko, “saved” mat bolo
- Device na chale / WebView → password, account mat maro
- Login: passkey ho to Face ID; warna password
- Account: kai devices, list se **hatao** (lost phone)

---

## 4. Password change (real tareeqa)

1. `anexomail.com` login  
2. Account → Current + naya + confirm → **Update password**  
3. Doosri sessions band  

Bhool gaya: Auth **Forgot** → link.

**Rule ek:** server **6–15** characters. Account page ab **12+** likhti hai — F3 A mein **ek jaisa** (12+ wala mix toot’ta hai).

---

## 5. Recovery (Lovable SQL + founder hukum)

Phase 32: `recovery_kind` = `gmail | apple | outlook | other_email | phone` · `recovery_hint` · `recovery_set`.

Aaj forgot-password **login email** par jata hai. Founder: recovery **Gmail / Apple / jo like**.

**F3 A real:**

- User woh **email** likhe jo khol sake (Gmail, iCloud/Apple mail, Outlook, Yahoo, Proton…)
- Reset / recovery **usi** par — sirf `@anexomail.com` par nahi
- `apple` = Apple wala **email**, Sign in with Apple **nahi**
- `recovery_set` tab true jab address save + mail ja sake, khali dropdown nahi
- Hint SQL; poora address logs mein nahi
- Phone/SMS: pipe na ho to honest “email chale, SMS baad”
- Family: recovery optional. **Awam:** recovery lazmi (Face ID kho jaye to rasta)

---

## 6. F3 list un ke login par

Incognito → teen family → Mail → list (khali theek). “Sign in to read mail” / Missing token / founder preview **nahi**.

---

## 7. F3 A mein nahi

F4 send/receive. F5+. Polar, landing, prices.

---

## 8. Server (passwords nahi)

- `family_accounts`: Masood `pro`, Humza `business_pro`, Raana `ai_executive`
- `create-accounts`: Masood + env passwords
- Naya WebAuthn SQL + Bun passkey routes
- Recovery email wire

## 9. Live (founder)

1. Supabase #4 SQL Editor: `docs/cursor-work/sql/phase63_f3a_passkey_family.sql` paste → Run.
2. Server (password kabhi type nahi — `/opt/anexomail/.env` mein `FOUNDER_MAIL_PASSWORD` · `HUMZA_PASSWORD` · `RAANA_PASSWORD` · `MASOOD_PASSWORD`):
```bash
cd /opt/anexomail-web && git pull && bun install && bun run build:bun && pm2 restart anexomail-web && pm2 save
bash server/deploy-brain.sh
bash server/accounts/create-accounts.sh
```
Lovable wala `read -s` password prompt **banned**. Missing key = RED.

3. Incognito `https://anexomail.com` — Masood Pro, Humza Business Pro, Raana AI Executive. Mail list (khali theek). Preview nahi.

**DONE** us proof ke baad. Abhi READY.

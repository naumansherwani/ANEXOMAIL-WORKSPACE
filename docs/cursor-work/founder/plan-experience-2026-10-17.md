# Har plan ke user ka duniya ka best experience (17 Oct 2026)

Founder ka hukm (17 Oct 06:04 PKT, AGENTS.md Rule 20): "user ko lage yeh product uska apna hai, competitors se behtar aur use karna aasaan — Basic, Pro, Business, Business Pro, har ek ka worlds best experience; cinematic frontend; backend latest."

Yeh agent ki CEO + user-dimaag wali soch hai. **Plan ki list/qeemat `src/lib/plans.ts` se (no-touch)** — yahan sirf experience ki soch aur gaps; qeemat ya feature-list nahi badalti. Competitor ke tathya sirf `competitive-baseline-zoho-google-2026-10-17.md` (official pages) se; baqi "verify baqi".

## 0. Har plan par lagne wale 5 usool

1. **Pehle 60 second mein wow:** login ke saath `naam@anexomail.com` kaam kare, DNS ke intezar mein bhi (8h), aur pehli mail ek tap mein (8f).
2. **"Mera" ka ehsaas:** user ka apna domain, apna rang/naam, apna address har jagah (Compose "From", inbox badge). Hamara brand sirf tab dikhe jab user ne ijazat di (V1).
3. **Jhoot nahi:** jo button hai woh kaam kare (Attach ab "coming soon" bolta hai, jhoot nahi), jo "live" hai woh sach mein live (health `webtransport` field).
4. **Tez:** Rust + QUIC. Mail aate hi dikhe (R5 event-driven push). Phone par bhi (Safari 26.4 se WebTransport).
5. **Nikalna aasaan:** import (8j), export, no lock-in. Jo jaana chahe woh aasani se jaye — isi se log aate hain.

## 1. Basic (£23) — akela founder / freelancer

**Woh kaun hai:** ek aadmi, ek domain, koi IT team nahi — "bas professional email chahiye, jhanjhat nahi".
**Plan mein (plans.ts):** 1 company address, 3 mailboxes, 5GB, 5 free aliases, undo send 30s, contacts+calendar, thread ownership, Cmd+K search.
**Best experience kaisa dikhta hai:**
- Signup → 5 minute mein apni domain par mail. Checklist (8k) har qadam asli data se.
- **Gmail se purani mail le aana** (8j) — sab se bara rukawat.
- Phone ki Mail app / Outlook se jurna (8i): IMAP/SMTP settings page.
- Phone par app jaisa (M1–M7 READY; push M9).
- Undo send 30s sach mein chale (backend `hold_seconds` hai) — "ghalti se bhej di" ka dar khatam.
**Gaps:** 8f, 8i, 8j, 8m (forward/vacation), 8p (attachments — Basic ko bhi chahiye, sab se pehla sawal), M5 funnel phone par.

## 2. Pro (£46) — gaahak ko roz jawab dene wali team

**Plan mein:** 3 addresses, 5 mailboxes, 10GB, **shared inbox + collision guard**, snooze, schedule send, templates, boards, tasks, thread analytics.
**Best experience:**
- **"Do log ek hi mail ko jawab nahi denge"** — collision guard ko UI mein dikhao (thread par "Ali likh raha hai"), owner/status/due har thread par (blueprint ka "mail is work").
- Phone par triage: swipe archive/snooze/assign (Mail mein hai), "Move to…" menu.
- Teammate invite ek tap (navigator.share) — viral + zaroori (M8, V4).
- Template aur schedule send phone par bhi 44px.
**Gaps:** 8p (attachments — gaahak ko file chahiye), 8m, M8, CRM phone (M6), thread→deal ek tap.

## 3. Business (£97/user) — barhti company, governance

**Plan mein:** 30 users tak, roles/departments, policies + audit ledger, one-click revoke + export, ANEXOChat, promises/work chain, device vault.
**Best experience:**
- **Admin ka pehla din:** CSV/bulk invite, roles ka seedha template, offboarding ek click (access revoke + mail forward + export).
- **Audit ledger auditor ko dikhane layak** (saaf, filter, export).
- **Domain health kisi se chhupa nahi:** apni domain ke cert/DKIM/SPF/DMARC ka status — founder ka expiry watch (8o) ka customer version (P4).
- SSO (OIDC/SAML) — business ka sawal; plans.ts mein nahi, PLANNED (P2, founder decide).
**Gaps:** org admin phone par (M6), bulk invite, P1 (plan-promise audit), P2.

## 4. Business Pro (£2850 / company) — poori company, poora stack

**Plan mein:** unlimited users, 1TB pooled, 5GB files, device trust + vault, safety review queue, 40-person calls, relationship graph, tamper-evident record, 12h priority support.
**Best experience (white-glove):**
- **Migration concierge** (`/migration` managed service) + status/health page apni company ke liye: SLA, uptime, cert/DKIM, backup — "company ko dikhe ke hum nigrani kar rahe hain".
- **Tamper-evident record export** — legal/audit ke liye ek file.
- Support 12h **sach** ho (founder ka support desk SLA tool, jhoota promise nahi).
- Data location/retention saaf (verify baqi).
**Gaps:** P1 (har lafz ka audit: plans.ts ki har line server par saabit hai ya nahi — jo nahi hai woh customer ke saath dhokha hai, founder ko batana), P4, P2, R2 (JMAP/native client).

## 5. Cross-plan gaps jo sab ko cheerein

| Gap | Asar | Item |
|---|---|---|
| Attachments nahi | Har plan | 8p |
| Mail Rust par nahi (`mail.send`) | Tez + sach | R1 |
| Live push har 700 ms DB poll | Scale + bijli | R5 |
| Phone par People/Calendar/Work/CRM/Billing/Account/Admin audit baqi | Rule 19 | M6 |
| Funnel (landing → checkout) phone par | Naya user | M5 |
| Viral loop (V1/V4) | Growth | M8 (founder decide V1) |
| Urdu/RTL | Pakistan | M9 |
| Plan ke dawe vs product | Bharosa | P1 |

## 6. Naye items (blueprint mein likhe gaye)

- **P1** Plan-promise audit: `plans.ts` ki har feature line ke samne "server par saabit (DONE) / READY / nahi hai" — jo nahi hai woh founder ko, kyunki customer ko bika hua wada hai.
- **P2** SSO (OIDC/SAML) Business+ ke liye — founder decide.
- **P3** Passkeys (WebAuthn) — sab plans, password-free login.
- **P4** Customer-facing "Domain health" tile (expiry watch ka customer version) — Business/Business Pro.
- **8q** Mail security hardening: MTA-STS + TLS-RPT (+ DANE jahan DNSSEC ho) + DMARC aggregate reports ka parse (Rust) — deliverability dashboard.

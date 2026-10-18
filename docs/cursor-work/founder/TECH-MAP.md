# ANEXOMAIL — latest technology map (18 Oct 2026, 05:11 PKT)

Founder ka hukm: **backend Rust-first; Bun sirf fallback/emergency.** Yeh file batati hai ke kaun si technology **kahan** hai, kyun, aur kya abhi baqi hai. Jo yahan "baqi" likha hai woh baqi hai — dawa nahi.

## 1. Kahan kya chalta hai

| Kaam | Technology | Kyun yeh | Status |
|---|---|---|---|
| Naye backend procs (calendar, people import, team invites) | **Rust** (tokio async, axum 0.7, reqwest/rustls → Supabase PostgREST) | memory-safe, ek binary, kam RAM, tez; HTTP + WebTransport ek hi process | READY (installer chalana baqi) |
| Chat / calls ka transport | **QUIC + WebTransport** (`wtransport`, UDP 3443) | head-of-line blocking nahi, connection migration (wifi → data) | pehle se live |
| Mail bhejna / lena | **Postfix + OpenDKIM + Dovecot** (SMTP / IMAP) | duniya ka standard; DKIM signing server par | unchanged (production path) |
| Calendar invitations | **iCalendar RFC 5545, iTIP RFC 5546, iMIP RFC 6047** (`METHOD:REQUEST/CANCEL`, `SEQUENCE`) | Gmail / Outlook / Apple Calendar mein asli invitation, Yes/Maybe/No | READY (E31 + installer) |
| Calendar Find-a-time | engine par exact UTC busy/free + browser mein `Intl` time zones | har guest ke apne ghadi ke hisaab se "kaun sa waqt munasib" | READY |
| Team invitations | **Postgres `SECURITY DEFINER` atomic function** + DB-issued uuid token + explicit "Join" click | role invitation row se aata hai (kabhi user_metadata nahi); mail scanner khud join nahi kar sakta | READY (E33 + installer) |
| Data safety | **Postgres Row-Level Security**, service_role-only tables (E32/E33) | public publishable key se koi tenant ka data nahi padh sakta | E32 chalana baqi |
| Frontend | **React 19.2, TanStack Start/Router/Query, Vite 8, Tailwind 4** | typed routes, server-state caching | live |
| Web host (SSR) | **Bun** | sirf web page serve karta hai; business logic nahi | live (isay "avoid" nahi kar sakte — yeh host hai, backend nahi) |
| Purane routes | **Bun (Brain `anexomail-leo` :3100)** | **sirf fallback** — Rust 404/501/502/503 de to frontend purane route par girta hai | jab tak har proc Rust par na ho |

## 2. Code kaise likha jata hai (taake galti kam ho)

* **Functional core / imperative shell:** faisla karne wala hissa `*_core.rs` (std-only, koi crate nahi) — server par installer **build se pehle** uske unit tests chalata hai. I/O wala hissa `*_glue.rs` patla.
* **Differential fuzz:** People import ka Rust core Bun wale TypeScript se **3956 inputs** par check hua — farq zero.
* **Mutation check (SQL):** E33 ki self-test ko jaan-boojh kar 3 tarah se tora (role ignore, revoked link, role downgrade) — teeno pakde gaye.
* **Installer:** anchor-based patch, backup, build fail => src wapas, health fail => purani binary wapas.

## 3. Abhi Bun par kya hai (Rust port baqi)

* Brain ke baqi routes: `workspace.ts` ke 4 purane routes, `org.ts`, `crm.ts` ka bara hissa, `contacts.ts`, `integrations.ts`, `mail*.ts` ka kuch hissa… (asli ginti: `rust-procs-check.sh` — live Rust mein 182 procs, repo mirror mein kam).
* People import ka Bun route **mojood hai (fallback)**; Rust pehle jawab deta hai.

## 4. Jo "latest" hai par abhi nahi bana

* **JMAP / JSCalendar (RFC 8620 / 8984)** — naya open standard (Gmail API ka khula muqabil). Plan: Rust par JMAP-Calendar read endpoint; CalDAV (RFC 4791) phone/desktop calendars ke liye.
* **Gmail / Outlook se purani mail ki migration (IMAP + OAuth2/XOAUTH2)** — worker nahi bana; sirf honest "guided move" copy lagi. Wajah aur faislay: ledger G30.
* **Inbound iMIP REPLY parse** (Gmail ke "Yes" button ka mail-reply) — mail production path mein hook chahiye (founder "haan"): ledger G26.

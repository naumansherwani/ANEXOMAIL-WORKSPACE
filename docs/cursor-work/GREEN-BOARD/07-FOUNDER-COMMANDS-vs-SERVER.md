# 07 — founder-commands.md ki har command: code mein? server tak aaya?

21 Oct 2026 ~07:10 PKT · `docs/cursor-work/founder/founder-commands.md` (506 lines) poori padhi, har command ko repo code + server ke output se milaya.

**Server tak aaya ka saboot (kaise tay kiya):**
- **Web (src/, public/):** `pull.sh` output 06:35 — `server==repo: src same=490 differ=1 (sirf routeTree.gen.ts, jo build khud likhta hai) missing=0`. Yani repo ki har Web file server par hai.
- **Rust:** founder ke install outputs — jwt, passkey, mail (06:00), events (06:47, SAB PASS), deliver (06:40), plus pehle ke modules (cal/people/team/mig/device/export/security/locale/attach/dnsauth).
- **Brain:** brain-* installers (refresh, passkey-harden, mail, attach, crm, auth-harden).
- **SQL:** `sql-run.sh` + founder ke "SQL sab success" (E31–E54).
**Darje:** 🟢 server par aaya · 🟢✔ server par aaya + live dekha · 🔴 server par NAHI aaya (bana hi nahi) · 🔵 aapka server kaam · 🟠 server par par ek hissa baqi.

## A. Aakhri aur khule hukm (queue, jaisa file mein likha)
| # | Hukm | Code | Server | Halat |
|---|---|---|---|---|
| A1 | Versions: tokio 1.53.3, axum 0.8.9, wtransport 0.7.2, rustc 1.99.1+2024, N7 error frame | Cargo/installers | live (3:28–6:07) | 🟢✔ |
| A2 | R1a aane wali mail ka pipe Rust par | deliver_bin.rs | live (+hub push 06:40) | 🟢✔ |
| A3 | Attachments (Option A: org-ke-andar dedup, Storage Box mount, quota) | E48/E49/E50, attach_*, inbound_attach | live; inbound download ✔; **bhejna ka live Chrome test baqi** | 🟢 |
| A4 | **Chat audit (AnexoChat)** | — | — | 🔴 shuru nahi |
| A5 | **iMIP REPLY (G26)** | — | — | 🔴 (B7) |
| A6 | Bun routes -> Rust (Business/Business Pro pehle), differential tests | B1–B4 Rust | B1–B4 live | 🟠 B5–B8 baqi |
| A7 | **Caddy read-only check script (+ TECH-MAP row)** | repo mein script hai hi nahi (sirf `attach-caddy-close-files.sh`) | — | 🔴 bana nahi |
| A8 | Business / Business Pro blueprint tarteeb | GREEN-BOARD + FINAL-FOUNDER-BLUEPRINT | docs | 🟠 jari |

## B. Halat table (19 Oct 03:35 wala bada message), 15 points
| # | Hukm | Server |
|---|---|---|
| 1 G29 revoked member guard | 🟢✔ live 06:16 |
| 2 G30 migration worker (App-Password IMAP, walled garden, SHA-256 chain, rustls) | 🟢✔ live (mig-live-test GREEN). *Farq:* aap ne `async-imap`+`tokio-native-tls` likha tha; code ne apna `mig_imap.rs` + rustls (kam dependencies) rakha — Cargo.toml mein async-imap nahi. OAuth jaan-boojh kar baad mein |
| 3 G31 seats/audit chain/work address | 🟢✔ live E34 |
| 4 G32 manager rank | 🟢✔ live |
| 5 Chat audit | 🔴 |
| 6 iMIP reply | 🔴 |
| 7 Bun -> Rust | 🟠 (A6) |
| 8 Caddy check script | 🔴 (A7) |
| 9 Pull command har technology ki alag | 🟢 rule AGENTS 24 + har jawab mein |
| 10 AI pointer line anexomail.com par na dikhe | 🟢✔ |
| 11 Business Pro test accounts | 🟢✔ (dono LOGIN OK) |
| 12 Business + Business Pro focus | 🟠 jari (Pro/Business/BP live test baqi) |
| 13 Final jawab simple Roman Urdu | 🟢 qaida |
| 14 Attachments files copy (migration + inbound) | 🟢 G38/G38b |
| 15 E31, E33 SQL | 🟢✔ |

## C. Commands (naya -> purana), har ek
| Waqt | Aap ne kya kaha | Code | Server |
|---|---|---|---|
| 21 Oct 03:15 | Chrome ke bina kaam; Rust no-touch; rule 35/36 | AGENTS 35/36; `rust-auth-harden.sh` | 🟢✔ (Rust auth cache live) |
| 21 Oct 03:07 | Migrated Rust ko touch nahi; memory update | Rule 35 | 🟢 |
| 21 Oct 02:49 | Ambient blob hata do | FxAmbient sirf edge-light | 🟢 |
| 21 Oct 02:42 | Graphics real + toggle | FxAmbient + Appearance toggle | 🟢✔ toggle live |
| 21 Oct 02:36 | Login loop (dashboard->login->loading) | auth-harden.ts + client retry + Rust cache | 🟢✔ probe 72 calls 200 |
| 21 Oct 02:31 / 02:20 | Landing par 3D nahi; orb hata | MailboxScene unwired, orb removed | 🟢 (LOCK) |
| 21 Oct 02:03 | 3D kahan kahan | fx/* (loader logo, empty gems, plans tilt) | 🟢 live test baqi |
| 21 Oct 02:11 / 00:29 | Repo + sandbox update har kaam par | memory files + sandbox-state | 🟢 |
| 21 Oct 01:31 | Graphics settings toggle; 27 Oct deadline sirf real users; test accounts exempt | experience.graphics; passkey exempt | 🟢 toggle ✔; 🟢✔ exempt marker live Brain mein (07:09 output) |
| 21 Oct 00:26 / 00:11 | Kaam ka tareeqa; 3-command had radd | AGENTS Rule 31 radd | 🟢 |
| 20 Oct 23:57 | Blueprint/founder md ki tarteeb, repo=live | MASTER-GAP-LEDGER, GREEN-BOARD | 🟢 |
| 20 Oct 21:50 | Postfix/Caddy haan; ClamAV + G38b | E50, inbound_attach, clamd-tcp-fix | 🟢✔ (EICAR FOUND, hello.txt) |
| 20 Oct 21:38 | Caddy /files band, 18 MB | attach-caddy-close-files.sh, E49 | 🟢✔ (probe 404) |
| 20 Oct 21:34 / 21:30 | Rust attach; SQL ab server se | sql-run.sh | 🟢✔ |
| 20 Oct 20:31 / 20:21 / 20:10 / 20:09 / 19:54 | E41–E47, device+export, timers, DONE file, Rule 29/30 | sab E-files, Rust device/export | 🟢✔ (E41–E47 GREEN 20:21) |
| 20 Oct 19:02 | Version history, retention, Hamza lifetime label, BP mobile, RPC Rust | E40, ComposeStudio, app.billing | 🟢 server par; **Hamza label + version-history Chrome check baqi**; RPC Rust = 🟠 B5 |
| 20 Oct 18:50 | SHA-256/HMAC + passkey lazmi + policy wade | HASHING.md, E42/E43, PROMISES.md | 🟢; PROMISES ke 'VERIFY' rows 🟠 |
| 20 Oct 18:34 / 10:53 | Family = real buyer; family profile packages ke mutabiq | E41, session family_accounts | 🟢 (B4 proof: family 3/3 org); **Humza profile Chrome check baqi** |
| 20 Oct 10:53–09:52 | Mail pane drag, side bar drag, AI settings Basic se hatao | HScroll, use-drag-scroll.ts, plan-surface | 🟢✔ (HScroll live, Basic sweep: AI nahi) |
| 20 Oct 10:32 | Manifest verify strict rule | Rule 28 + manifest-verify.py | 🟢 (0 bad har push) |
| 20 Oct 09:44 | BASIC-AUDIT-DONE + Rule 27 | file maujood | 🟢 |
| batch 6 Calendar | calendar.events/event/load Rust | cal_glue.rs | 🟢✔ (E51, create/drag live) |
| batch 5 Integrations | jhoote Connect buttons hatao | Web | 🟢 |
| batch 4 Settings toggles | isOn() fix | Web | 🟢 |
| batch 3 Billing daam | E40 | SQL | 🟢 |
| batch 2 Security page sach | E39 + Rust security module | security_*.rs | 🟢 (Chrome check baqi) |
| batch 1 PWA / sign-out saaf / copy | public/sw.js | Web | 🟢✔ (sw activated, offline inbox) |
| 20 Oct 09:09 | Server live facts; 3443/udp, WT cert | wt-url.ts | 🟢 Web; 🟢✔ ufw active, 3443/udp rule maujood (07:09 output) |
| 20 Oct 08:37 / 08:29 | Server user ki tarah; git 143 peeche; .env khatra | .gitignore `.env` jod diya | 🟢 |
| 20 Oct 08:18 | Blueprint green; Domains 8 features (D1/D2/D3…) | `dnsauth_*` (D2) | 🟢✔ D2; 🔴 **baqi 7 domain features** (D3 admin link, D1 zero-gap, catch-all/forwarding/vacation, health guard, DMARC reader, Domain Connect, BIMI) |
| 20 Oct 07:54 | Mail kholne par sirf mail; Reply/Forward neeche | InlineReply, SafeMailBody | 🟢✔ |
| 20 Oct 07:00 | X button; Sent folder khaali; Rust mail.thread | thread via Rust | 🟢✔ |
| 20 Oct 06:50 | Device record Basic ko; Import mail customer tak | device module, `/app/import` | 🟢✔ ; **Terms (point 5) 🔴** |
| 20 Oct 06:41 / 06:36 / 06:29 | E37 + technology Rust/tRPC/WT/tokio ka hukm; TECH-MAP; locale | E37, TECH-MAP 0b/0c, locale module | 🟢✔ |
| 20 Oct 06:07 | rustc 1.99.1; footer; E37 leak | toolchain pin, E37 | 🟢✔ ; **Terms of Service page: 🔴 `/terms` route repo mein hai hi nahi** (Refund: aap ka faisla — refund nahi, page nahi) |
| 20 Oct 05:37 | Basic live login; policies/footer real wire; 1.99.1 | PROMISES.md, footer | 🟢; 🟠 policies ke baqi VERIFY rows; "hum kyon better hain" page: `src/routes/about.tsx` hai, live check baqi |
| 20 Oct 05:03 / 04:37 / 04:03 / 03:59 / 03:55 / 03:28 / 03:18 / 03:10 | N7, wtransport, axum, tokio, N5 business.test, package tarteeb, N6 tiles, standing orders | installers + sab Rust | 🟢✔ (har ek ka output aaya) |
| Notes N1–N7 | N1 Import page customer tak (`/app/import`), N2 Members (`/app/org/members`), N3 locale, N4 sw.js, N5, N6, N7 | routes maujood | 🟢 (N1/N2 Chrome check Business/BP par baqi) |
| 20 Oct 03:02 / 03:03 | Test accounts (passwords repo mein nahi) | `/root/.anexo-test-creds` | 🟢 |
| 19 Oct 06:44 | Live public pages dekhe; sw.js 404 | public/sw.js | 🟢✔ |
| 19 Oct 06:34 | Technology table = LAW; upgrades priority | TECH-MAP 0, AGENTS 25 | 🟢 |
| 19 Oct 06:29 / 06:27 | mig-live-test GREEN; queue (shaam ko) | mig-live-test.sh | 🟢✔ |
| 19 Oct 06:16 | Rust + Web pull; attachment policy lock | attach stack | 🟢✔ |
| 19 Oct 06:06 | Attachments Option A + E34 | E34, E48.. | 🟢✔ |
| 19 Oct 05:58 | G29–G32 blueprint mein as-is | anexomail-blueprint.md | 🟢 |
| 19 Oct 05:45–05:14 | E35/E36 fail/fix, Rule 24, gussa, 'naya kaam nahi' | E35 cast fix, E36 script | 🟢✔ |
| 19 Oct 05:40 | "Nahi hua" list | A4–A7 upar | dekho Section A |
| 19 Oct 03:35 | Bada hukm: G29 haan, G30 App-Password IMAP walled garden, G31 fix | mig_* + E34/E35 | 🟢✔ |

## D. Jo server par NAHI aaya / bana nahi (founder-commands.md ke hisaab se)
1. **Chat audit (AnexoChat)** — shuru nahi (aapka D10 order, packages ke baad).
2. **iMIP REPLY (G26)** — B7.
3. **Bun -> Rust baqi:** B5 (19 calls), B6 (billing), B8 (Brain 38 files).
4. **Caddy read-only check script** — kabhi bana hi nahi.
5. **Terms of Service page (`/terms`)** — repo mein route nahi (legal text aap ka; main product-facts se draft dunga agar kahen).
6. **Domains ke baqi 7 features** (zero-gap, admin link, catch-all/forwarding/vacation, health guard, DMARC reader, Domain Connect, BIMI).
7. **Server kaam (aapka):** E24 email_hash HMAC migrate; Caddy cert 12 Nov se pehle. (ufw 3443/udp + passkey exempt: DONE 07:09.)
8. **Live Chrome click-test baqi (code server par hai):** Humza lifetime label + version history, Security page (E39), Domains page, outbound attach bhejna.

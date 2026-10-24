# CLAUDE CHAT CONTEXT WITH FOUNDER NAUMAN SHERWANI

> **RULE 24 (founder, 19 Oct 05:20 PKT, STRICT): sabse pehle `docs/cursor-work/founder/founder-commands.md` padho (founder ki commands verbatim + halat). Uske baghair koi kaam shuru nahi. Jo kaam ho gaya uski usi waqt pull command, har technology ki alag.**

> ## FOUNDER KA RULE (locked, 17 Oct 2026)
> **Jo bhi Claude / agent / session founder Nauman Sherwani se chat karega, woh PEHLE yeh poori file padhega, PHIR chat karega.**
> Yeh founder ka rule hai. Bina padhe chat shuru nahi hoti, aur founder se woh sawal nahi poochhe jate jinka jawab is file mein likha hai.

Yeh file isliye hai ke chat compact ho ya naya chat khule (claude.ai ka Claude chat ho ya Claude Code ka cloud session), agla Claude **wahin se** kaam shuru kare jahan pichla chhoda tha. Founder ko kuch dobara samjhana nahi parna chahiye. Isko update karna AGENTS.md **Rule 18** hai. (Pehle yeh `CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md` thi; founder ke kehne par 17 Oct 2026 ko is naam se badli — ek hi file, duplicate nahi.)

Aakhri update: **21 Oct 2026, 08:33 PKT — B5 GREEN** (founder server output 08:27). Aaj ka kaam B5 tak complete; **baqi shaam ko isi din**: `docs/claude/EVENING-PENDING-2026-10-21.md` (B6 pehle). Founder workspace plan + stack: `docs/claude/FOUNDER-WORKSPACE-PLAN.md`, `TECH-STACK-BEAST.md` (sulah locked, privacy metadata-only, founder side B-series ke baad). Dobara mat likho: b5_core.rs/b5_glue.rs (founder.brain.command samet), brain-pricefix-install.sh, ConfirmButton, status page fix.

Pichla: **21 Oct 2026, 05:50 PKT — B2 GREEN (server par chala): Rust `rust-passkey-install.sh` proof SAB PASS (14 checks: tamper/replay/clone/ghalat origin/recovery/filter-injection) + Web pull (build OK, server==repo 486/487, sirf routeTree.gen.ts generated diff). Backup /opt/anexomail-rust/src/main.rs.bak.1792541331.**
Passkey/recovery LOGIN ab Rust PRIMARY (Bun fallback). Dobara mat likho: passkey_core.rs, passkey_glue.rs, passkey_patch.py, passkey-proof.py, rust-passkey-install.sh, src/lib/passkey.ts Rust-first.
**21 Oct 05:40 — B2b READY (repo, server par chalna baqi):** (a) Bun fallback hardening: `server/routes/auth-passkey.ts` challenge single-use + shape + user-match, test `server/routes/auth-passkey.test.ts` (5, purane code par 2 fail), installer `brain-passkey-harden-install.sh` (+ `brain_passkey_harden.py` surgical patch); (b) Rust `auth.passkey.list` / `auth.passkey.delete` (passkey_glue.rs), client `app.account.tsx` rpcOrRest; `passkey-proof.py` ab authenticated checks bhi (sandbox mock: nakli Supabase + ES256 JWT + asli Rust binary, SAB PASS). Install: Brain `brain-passkey-harden-install.sh` -> Rust `rust-passkey-install.sh` (dobara; rebuild + proof) -> Web `pull.sh`. Phir B3.
**Founder ka hukm (05:16): B3 se PEHLE (a) Bun fallback mein bhi challenge-pehle-mitao (replay band), (b) passkey/list + DELETE passkey/:id ko Rust mein (ledger nahi, code), phir B3 (R1 mail.send + org.mailboxes.*), B3 ke baad green.** Founder ka sawal: tokio async / quinn+QUIC / tRPC kab? Jawab: tokio 1.53.3 + axum 0.8.9 + wtransport 0.7.2 (quinn QUIC) + `/rpc/*` tRPC-style JSON PEHLE SE LIVE; baqi = B4 (event-driven WT push) aur B8 (tokio 1.54, Bun 1.4.3, Brain->Rust).

**21 Oct 2026, 06:00 PKT (asli ghadi) — B3 GREEN (server par chala, founder ne output diya).** `rust-mail-install.sh`: mail_core 13 tests, build OK, health 200, nakli token 401, proof SAB PASS (asli Postfix mail + Postfix log entry + mail_outbox_log ok=true; queue worker ne uthayi, status=sent; undo ok/dobara 409; parai identity 403; CRLF/101 rcpt/foreign thread/attachment id sab band; org.mailboxes list/create; test rows saaf), Rust mail worker log 1. Backup /opt/anexomail-rust/src/main.rs.bak.1792543838. Web pull pehle ho chuka (client Rust-pehle). **FOUNDER TARTEEB (locked, 05:53): PEHLE technology migration POORI (B4..B8), PHIR packages: Basic green hai -> Pro -> Business -> Business Pro (live test 1440/820/390).** **AGLI TARTEEB: B4 R5 event-driven WebTransport push (polling khatam) -> B5 G40 work/crm/org/integrations/settings 19 Bun-only founder routes Rust par -> B6 G16 self-serve billing Rust par (polar :3400 NO-TOUCH) -> B7 G26/G27 calendar (inbound iMIP reply, recurring, scheduling link, CalDAV) -> B8 Brain ~38 route files/504 endpoints Rust par + Bun 1.4.0->1.4.3 + tokio 1.54.** Ab B4 shuru.

**21 Oct 2026, 05:55 PKT (asli ghadi) — B2b GREEN + B3 aadha server par.** Founder output: SQL E54 + CHECK_E54 sab OK · Brain `brain-passkey-harden` OK (injection/khali/anjaan 400, session 401) · Brain `brain-mail-install` OK (health 200, undo-cancel nakli token 401, queue fetch failed 0) · Rust `rust-passkey-install` proof SAB PASS (20 checks incl. list/delete) · Web pull OK (origin/main 2781405, build OK, server==repo 487/488, sirf routeTree.gen.ts generated diff; client ab mail.send/schedule Rust-pehle, abhi Rust par proc na hone se 501 => Bun fallback, safe). **B3 mein sirf `rust-mail-install.sh` baqi** (founder ko dena/chalwana); uska output aane par B3 GREEN. **FOUNDER NOTE (locked): yeh technology POORI WEBSITE ke liye hai, package plan ke liye nahi.** Tokio async (1.53.3), axum 0.8.9, QUIC via wtransport 0.7.2 (quinn), tRPC-style `/rpc/*` — TEENO PEHLE SE LIVE hain, dobara 'kab aayega' mat poochna/likhna. Jo baqi: B4 (events ka live push WebTransport par) aur B8 (tokio 1.54, Bun 1.4.3, Brain->Rust).

**21 Oct 2026, 07:00 PKT — B3 READY (repo mein, server par chalna baqi; sandbox proof SAB PASS).** R1 poora: Rust `mail.send` + `mail.schedule` / `mail.schedule.cancel` (undo-send hold) + **Rust queue worker** + `org.mailboxes.list/create`. Files: `server/rust/mail_core.rs` (std-only, 13 tests: MIME, attachments wrap, SMTP client, parse_iso, sender rules) + `mail_glue.rs` (5 tests) + `docs/cursor-work/server/mail_patch.py` + `rust-mail-install.sh` + `mail-proof.py` (live proof: asli Postfix mail, queue, undo, hostile, mailboxes). SQL `E54_mail_queue_claim.sql` (+CHECK_E54): `mail_queue_claim/release/cancel`, `claimed_at` — Bun aur Rust worker dono isi se uthate hain => ek mail ek hi baar; Bun worker STANDBY (Rust band ho to Bun bhejta hai). Brain: `brain_mail_patch.py` + `brain-mail-install.sh` (mail-worker.ts claim, mail-compose.ts cancel; E54 na ho to purana tareeqa). Client: `src/lib/compose.ts` + `mail.ts` Rust-first (`mail.schedule`, `mail.schedule.cancel`, `mail.send`), test `src/lib/mail-rpc.test.ts` (5). Sandbox saboot `mail-sandbox-proof.py` (mock Supabase + capture SMTP + asli Rust binary + ASLI Bun sendmail.ts): Rust MIME bytes == Bun bytes (3 cases + worker), attachments, CRLF/foreign-thread/101-rcpt/bad send_at band, SMTP fail => koi row nahi bachti, undo/claim, identity, storage reserve/commit/release, mailboxes role/limit/duplicate/writes-switch. Loopholes band (Bun mein the): foreign thread_id ka message_count badal jata tha; SMTP fail par 'sent' row bachti thi; recipients par koi shape check nahi (CRLF header injection); smtp_failed ko Rust 424 deta hai (502 par client Bun se dobara bhej deta). **Install order (founder):** (1) SQL `sql-run.sh E54_mail_queue_claim CHECK_E54` (2) Brain `brain-mail-install.sh` (3) Rust `rust-mail-install.sh` (4) Web `pull.sh`. B2b ke 3 installs bhi baqi (brain-passkey-harden, rust-passkey-install, Web) — Rust passkey install pehle, phir mail install. Output aane par B3 GREEN likhna. Dobara mat likho: mail_core.rs, mail_glue.rs, mail_patch.py, E54, brain_mail_patch.py.

Pichla update: **21 Oct 2026, 04:55 PKT — B1 GREEN (server par chala, founder ne output diya).** SQL E53 OK · Brain `brain-refresh-install.sh` (health 200, nakli refresh 401, asli refresh -> naya token+refresh_token) · Web `pull.sh` (build OK, 200, server==repo 483/484, sirf routeTree.gen.ts generated diff) · Rust `rust-jwt-install.sh` (jwt_core 9 tests, build OK, asli token -> 403 auth chali, 24 parallel 848ms, logout ke baad wohi token 401 = revocation asli). Backups: /root/anexomail-backups/brain-refresh-20261020-233911, /opt/anexomail-rust/src/main.rs.bak.1792539693.
**UNIVERSAL UI (founder 21 Oct): Rule 37 + tier-guard test + tier-sweep.sh live; har UI badlav sab packages par ek saath.**
**AGLA: B2 = G42 passkey/recovery login Rust par** (p256/ciborium/sha2, `/rpc/auth.passkey.*`, differential test vs Bun, installer restore-on-fail), phir B3 R1 mail.send/org.mailboxes, B4 R5 WT push, B5 G40, B6 G16 (polar :3400 NO-TOUCH), B7 G26/G27 calendar, B8 Brain->Rust + Bun 1.4.3 + tokio 1.54. HAR batch se pehle yeh file repo+sandbox-state update; batch ke baad per-technology POORI pull command (sirf script ka naam nahi). Founder ko sirf 'green' batao.

Pichla update: **21 Oct 2026, 04:50 PKT — B1 ka plan (ab poora ho chuka):** REPO PADHNE KE BAAD B1 KA ASLI NAKSHA (AGENTS.md Rule 1-36, TECH-MAP 0/0a/0c, auth.ts, main.rs auth_user):**
- Abhi har request par GoTrue `/auth/v1/user` (Brain: `getAdmin().auth.getUser`, Rust: `auth_user`) — revoke/logout GoTrue session se hota hai (`account_sessions.revoked_at` + `admin.signOut`). Sirf JWT local verify karne se logout/device-revoke TOOT jata hai (token exp tak chalta rahe).
- Isliye B1 = (a) JWT local verify (HS256: hmac+sha2 already Cargo mein; ES256/RS256: p256/rsa crate chahiye — sandbox ko crates.io proxy se milta hai, compile check ho sakta hai) + (b) revocation: `auth.sessions`/`account_sessions` ki cached (5s) jaanch — warna 'sign out everywhere' jhoota ho jata hai + (c) fallback purana GoTrue check. Rust ke paas direct Postgres pool NAHI (R4 TODO) — pool ke baghair revocation check PostgREST se hoga (GoTrue se alag rate-limit, tez, par network). Asli poori jeet = R4 direct pool (tokio-postgres/deadpool + rustls) + local verify.
- Rule 24 ('ek time par 1-2 point') ko founder ke 04:21 hukm ne override kiya: B1..B8 tarteeb se.
- Pehla block: `jwt-life-probe.sh` (alg/kid/JWKS/secret-env-NAAM) — output ka intezar.

**21 Oct 2026, 04:35 PKT — FOUNDER HUKM (04:21): "sab ka sab implement, batch + tarteeb se; har batch se pehle memory update repo+sandbox, live test, loophole khatam, green; har complete ke baad pull command (SQL ho to postgres par); technology har minute read, advance code".**
Batch tarteeb: **B1 Rust JWT local verify** (Supabase network call/request khatam; HS256 hmac+sha2 ya ES256/JWKS — alg `jwt-life-probe.sh` se; revoked sessions `account_sessions.revoked_at` check ZAROORI; fallback network getUser) -> B2 G42 passkey/recovery login Rust -> B3 R1 mail.send + org.mailboxes.* -> B4 R5 event-driven WebTransport push -> B5 G40 work/crm/org/integrations/settings RPC -> B6 G16 self-serve billing (polar :3400 NO-TOUCH) -> B7 G26/G27 iMIP reply, recurrence, scheduling link, CalDAV -> B8 Bun Brain 38 route files -> Rust + Bun 1.4.3 + tokio 1.54. Har batch: differential test, restore-on-fail installer, Rule 35 (live Rust sirf surgical script se).
**Abhi B1 mein:** jwt-life-probe.sh (alg/kid/JWKS/secret-env-NAAM, token nahi) founder se chalwana; output ke baad code.

**21 Oct 2026, 04:30 PKT — BASIC 100% GREEN (live saboot BASIC-AUDIT-DONE.md; repo==server). AGLA QADAM: PRO live test (pro.* account `/root/.anexo-test-creds`), phir Business, Business Pro, phir Rust login G42.** Founder-note: browser tab ko founder bhi use karta hai — apna test naye tab mein karo.

**21 Oct 2026, 03:35 PKT** (asli ghadi; session compact hone ke baad bahal).

---

## 0. Naya chat shuru karte hi (tarteeb)

0. **Founder ka rule (upar):** pehle yeh file, phir chat.
1. `AGENTS.md` (Rule 1–18) — locked qaide.
2. Yeh file poori. Khaas kar **section 1 (ABHI KA QADAM)** aur **section 4 (qaide)**.
3. `docs/anexomail-blueprint.md` ke sections: "11 Oct 2026 — remaining work" (item #1–#42, ek hi list), "13 Oct" (E19–E26), "15 Oct" (U1–U7). Har item ka status wahin hai.
4. Founder se woh mat poochho jo yahan likha hai. Section 1 se seedha chalo.
5. Har natije ke baad is file ko update karo (Rule 18, section 11).

---

## 1. ABHI KA QADAM (17 Oct 2026)

**21 Oct 2026, 03:35 PKT — COMPACT KE BAAD BAHAL (Basic 100% green ki dauR; founder ka maqsad: login-loop khatam + Basic live-tested green, phir Pro->Business->Business Pro).**
- **Web repo=server: bb9007e** (pull OK, build OK, /health 200, server==repo src same=479, sirf routeTree.gen.ts generated-file farq). app.tsx guard + fx/Graphics toggle + SiteNav xl: live.
- **Brain auth-harden LIVE** (20s cache + in-flight dedupe + transient retry, transient=503 not 401). **Rust auth_user cache LIVE** (rust-auth-harden.sh: 'Pehle se lagi hai').
- **LOGIN-LOOP SERVER PROOF (login-probe v2, bina typing, 21 Oct 03:30):** basic.test token se 24 parallel x 3 rounds: Brain /api/auth/session, trial/state, passkey/status, mail/handoff = **sab 200, koi 401/5xx nahi**. (Rust 404 = probe ne ghalat rpc path maara tha, bug nahi; probe ab theek.) Client side: auth.tsx retry + /auth redirect guard + app.tsx refresh guard live.
- **Rule 35: Rust/migrated NO-TOUCH (sirf surgical + founder-approved). Rule 36: Chrome sirf founder ke pull ke BAAD final look ke liye.** Test creds: server/sandbox `/root/.anexo-test-creds`. Test accounts passkey-exempt (live).
- **Locked design:** landing par koi 3D nahi; dashboard orb nahi; aurora blobs nahi. Rakha: Graphics ON/OFF (Settings->Appearance), loader 3D logo, empty inbox/calendar gem, plans tilt, patli edge light.
- **AGLA QADAM:** Basic ka hard stress test (user + CEO, 390/820/laptop) -> fix -> phir 'Basic 100% green' repo+sandbox mein likhna -> Pro -> Business -> Business Pro -> G40/G42/R1/G16 -> leftovers -> father account -> founder profile -> AnexoChat. Loader logo / calendar gem / plans tilt ka live final-look baqi (founder pull ke baad).

**19 Oct 2026, 03:27 PKT — FOUNDER KA HUKM (19 Oct, 03:25 PKT) — SAB PAR "HAAN":** (1) **E31 + E33 SQL server par SUCCESS** (founder: 'baki sql sab success hai'). (2) **G29 (revoked member Rust mail_identity), G30 (migration worker), G31 (team ke baqi hisse), G32 (Rust manager rank) — sab par haan, bas website na tootay.** (3) **G30 faisle:** shuruaat **App-Password IMAP** se (OAuth baad mein, sirf enterprise bulk ke liye); worker seedha **Rust :3200** ka hissa; `Cargo.toml` mein IMAP/TLS crate ki **ijazat di** (founder ne ek draft toml bheja — usmein `async-imap` ka `tokio-native-tls` feature nahi hai aur `tls-codec` TLS connection ke liye nahi; agent sahi crates chunega); inbound write **sirf migration-only walled garden** mein (migration_session_token, migration khatam => write gate band, read-only); har email ka SHA-256 append-only ledger. (4) **Pull ka qaida (naya, locked):** har technology ki **alag** pull/install command — SQL alag, Rust alag, Web alag, Brain alag, Caddy alag; founder ko ek ek karke di jaye. (5) **Caddy (Edge + HTTP/3) founder ka doosra dimagh hai — kabhi nahi chhedna; koi bhi badlav pehle read-only check, backup, `caddy validate`, reload; HTTP/3 band nahi hona chahiye.** (6) **SUDHAR (founder, 19 Oct 03:35 PKT — 'maine yeh nahi bola tha ke AI ka zikr anexomail.com se hata do'): sirf EK line — 'AI plans open on ai.anexomail.com' (ai-subdomain ka pointer) — anexomail.com par nazar nahi aani chahiye. Baqi AI ka zikr anexomail.com par jaisa tha WAISA rahe, kuch nahi hatana.** (Pehli galti: agent ne AI ka zikr zyada hata diya tha; wapas liya, ab sirf wohi ek pointer line badli: plan-surface.ts body 'Basic, Pro, Business and Business Pro have no AI.', workspace-i18n 4 zubanen, app.settings.ai blurb, pages.tsx 4 notes.) ai.anexomail.com founder ne khud block kar diya hai — us par ab koi baat nahi (Rule 23). (7) **Bun se door:** backend naya sab Rust; Bun sirf web SSR host (constitution) + abhi ke fallback jab tak har proc Rust par live verify na ho. (8) **Business Pro test account `business_pro.test@anexomail.com` login nahi hota — theek karna + naya Business Pro test account banana** (password founder ne chat mein diya — **repo/memory mein KABHI nahi**, script prompt se leti hai). (9) Founder ko summary mein sirf **kya theek hua** + jo theek na ho uska **mashwara** — purani ledger rows (L75…, G29…) dohrani nahi jaayein; sada aasaan lafz. (10) Focus: blueprint tarteeb se, **Business aur Business Pro** (Basic/Pro complete), latest technology.

**18 Oct 2026, 05:43 PKT — SQL EMERGENCY THEEK (E31 + E33 shuru se dobara likhi, usi file mein; READY — founder ko dobara Run karna hai):** local Postgres 16 par dono asli errors dohraaye (line 45 / 77 at RAISE). E33 ka bug sirf self-test mein nahi tha — `team_invite_accept` ka apna write `org_role` enum par girta; ab accept column ka asli type DB se dhoondh kar likhta hai. E31 ka self-test ab asli org (FK target pg_constraint se) use karta hai. Dono mein Part 1 (schema) aur Part 2 (self-test) alag transactions; aakhir mein ek jawab-row (`e31_result` / `e33_result`, selftest = PASSED ya SKIPPED+wajah). Test: 5+5 schema-variants (enum/text, FK org/orgs/none, status+email ho/na ho), dobara chalana, purani state par upgrade, 9+12 mutation (sab pakde gaye), `service_role` se chala kar, browser role refuse. **Founder ke liye tarteeb:** E31 pehle, phir E33, phir `rust-engine-install.sh`. **ai.anexomail.com par is chakkar mein koi kaam nahi (Rule 23); founder ne kaha SQL ke baad ruk jao — ruk gaya.** Ledger L78, G32.

**18 Oct 2026, 05:35 PKT — FOUNDER KA SAKHT HUKM (ai.anexomail.com BAND) + SQL EMERGENCY:** (1) **`ai.anexomail.com` (LEO AI product) ek ALAG product hai, agle saal launch hoga, founder ke liye priority nahi; anexomail.com (human side) 100% bug-free hone ke baad hi uska kaam shuru hoga.** Ab se koi agent/session us par KAAM NAHI karta, na check, na naya feature, na copy badalna, na uske liye installer — jab tak founder khud likh kar na kahe. Jo AI surface repo mein pehle se hai woh jaisa hai waisa chhoda gaya (SiteLock: awam ko sirf `/` coming-soon; baqi sab gated). Founder ne kaha 'tum ne touch kiya aur khol diya' — repo ka git saboot: 17 Oct 18:00 PKT ke baad ke kisi commit ne AI file / `host.ts` / `SiteLock` / Caddy / gates nahi chhua; lekin ek codebase teen host serve karta hai, is liye web pull ka naya code (join/rsvp/calendar/team) `ai.` host par bhi jata hai aur uska gate server ki `VITE_SITE_LOCK` par hai — yeh live dekh kar hi pakka hota hai, founder ne ab is par kaam rokne ko kaha. (2) **SQL emergency:** E31 fail (`calendar_events_org_id_fkey` — self-test ne bana-banaya org uuid daala; asli table mein FK hai) aur E33 fail (`org_members.role` ka type `org_role` enum hai, SQL `text` daal raha tha). Founder: E31 'shuru se, super advance level par' likho; dono usi file mein (SQL fail rule). Is chakkar mein sirf yeh do SQL files; uske baad ruko.

**18 Oct 2026, 05:13 PKT — SAME HUKM, AGLA HISSA (commits f1f1c93, 1d045a6 pushed):** Founder ka hukm wahi: Gmail/Outlook migration + team invites theek karo, "worlds best", Bun sirf fallback/emergency, batao latest technology kahan, **pehle pending/emergency ka pull command, phir naye**. **Bana (READY — server par chalana baqi, Rule 15):** (1) **People/Leads import Rust par** (`people_core.rs` 16 tests + TS ke saath 3956-case differential fuzz; `people_glue.rs`) — L75/G23. (2) **Team invites poora stack** — `sql/E33_team_invites.sql` (invitations/teams/people_log, atomic `team_invite_accept`, self-test), `team_core.rs` + `team_glue.rs` (14 procs), `/join` page (explicit Join click), Members/Teams rewire — L76/G17. (3) **`rust-engine-install.sh`** — ek hi command calendar + people + team ko ek cargo build mein lagata hai (pehle unit tests, backup, restore-on-fail, health, probes). (4) Integrations copy sach ki (L77). (5) `founder/TECH-MAP.md` — latest technology kahan/kyun/kya baqi. **Founder ke liye tarteeb:** emergency pehle (web pull, phase64 SQL, `brain-org-install.sh`, `brain-people-import-install.sh`, `rls-open-check.sh`/E32) -> SQL E31, E33 -> `rust-engine-install.sh` -> ek web pull. **Honest baqi:** migration worker nahi bana (G30: OAuth app registration + encrypted credentials + naye crates + inbound path = founder faisla/"haan"); Rust `mail_identity` revoked member ko nahi rokta (G29 — mail production path, founder "haan"); Calendar ko "Google se behtar" **nahi** kaha (recurrence, scheduling links, inbound reply sync, Google/Outlook sync, CalDAV nahi bane); cargo build asli server par pehli baar hoga (G28). Chat audit shuru nahi hua.

**18 Oct 2026, 04:47 PKT — FOUNDER KA HUKM (04:18 PKT, `brain-people-import-install.sh` ke fail output ke saath) + KYA KIYA:** Founder ke alfaaz ka matlab: (1) installer ne `/opt/anexomail/backups/1789071646` utha liya ("live lib/supa.ts mein export const admin nahi mila") -> **galti meri thi** (`find | head -1`), ab saari scripts mein ek `find_brain_src()` (backup/node_modules/.git/dist/build chhor kar `routes/` + `index.ts` wali dir; `BRAIN_SRC` override; pm2 `anexomail-leo` ka path) — decoy backups dir ke saath sim-test, pushed. (2) **Hukm:** Gmail/Outlook migration (G19a), team invites (G17) theek karo, "duniya ka best"; **Bun sirf fallback/emergency**; jahan latest technology lagi wahan likho; (3) **Calendar `.ics` attendees ko invite jaati hai ya nahi (L67)** — nahi jati thi (Bun `calendar.create` sirf row likhta tha); founder: "CEO ban ke best advanced banao… duniya ka advance, Google se zyada advance — **tum khud bolo ke yeh Google se zyada advance hai tab main qabool karun ga**"; (4) People import -> latest technology (Rust, **avoid Bun**), kaun si technology suit karti hai woh batao aur khud karo; (5) team invites, Chat audit, migration worker, Rust ports (Rule 22) -> latest technology par; (6) **commands ki tarteeb: pehle jo emergency/pichli commands pending hain unki pull, phir nayi**; (7) blueprint tarteeb se user-side kaam aaj poora, taake founder side par focus ho.
**Is chakkar mein bana (READY — server par install ke baad DONE):** (a) **Security finding (S-class):** `phase52/60/61/62/64_crm_locale` ne ~40 tables par `authenticated` ko `using (true)` policies di hain + browser mein publishable key => koi bhi logged-in customer `…/rest/v1/mail_messages` seedha kholkar SAB organisations ka data padh/likh sakta tha (org_members mein khud ko likh sakta tha). **`sql/E32_tenant_lock.sql`** (sab anon/authenticated/public policies hata kar service_role-only; chat/billing/config tables chhodi; self-test; asli PG16 par test) + read-only **`rls-open-check.sh`** (live par pehle OPEN tables dikhata hai; checks-all mein). Server ka Brain+Rust service_role se jata hai => app par asar nahi. (b) **Calendar v2 (Rust-first, Bun fallback)**: `server/rust/cal_core.rs` (std-only functional core: RFC 5545/5546 iMIP ICS REQUEST/CANCEL + SEQUENCE, multipart mail + RFC 2047, dot-stuffing, attendee clean/dedupe/cap 50, uuid RSVP token shape, common-free-slot maths; **21 unit tests pass**), `server/rust/cal_glue.rs` (thin I/O: Postfix 127.0.0.1:25 SMTP, PostgREST; procs `calendar.create/update/invites.resend/busy/findtime/guests` + public `calendar.rsvp.lookup/respond`; daily cap 200; har invite ka ledger; **sirf mock crates se type-check — asli `cargo build` founder ke server par**), `sql/E31_calendar_v2.sql` (sequence/cancelled_at/tz; rsvp_token, role, invite_status…; `calendar_invite_log`; `calendar_rsvp_lookup/apply`, `calendar_busy`; self-test), `server/rust-calendar-install.sh` (LIVE `main.rs` ko replace nahi karta — 3 anchored jagah patch, build, restore-on-fail, health, nakli-token proof; sim-test pass). **Frontend:** NewMeeting ("E-mail an invitation to N guests" toggle, "Create & invite"; natija sirf wahi jo engine ne report kiya — engine purana ho to "Saved, but the guests were NOT e-mailed"), `Guests.tsx` (har guest ka Yes/Maybe/No/Waiting + invitation ledger + Re-send + Reschedule + Cancel, sirf organiser), `FindTime.tsx` + `src/lib/find-time.ts` (engine exact free/busy UTC; browser working-hours windows + guests ke time zones, kaun sa waqt kis ke liye early/late/night; 14 bun tests), public **`/rsvp`** page (link kholne se jawab record NAHI hota — guest "Send my answer" dabata hai; scanner-safe). Agent ke apne screenshots 390/820/1366/1440 (harness: sample + toasts). **Sach (jo abhi NAHI hai):** inbound METHOD:REPLY (Gmail/Outlook ka reply mail se RSVP) parse nahi hota (mail production path — founder "haan" chahiye); recurrence (RRULE) naye meeting mein nahi; private event visibility, scheduling link (Calendly-jaisa), Google/Outlook calendar sync nahi => **"Google se zyada advance" ka dawa agent nahi karta** jab tak yeh na hon; jo hai: agenda-gate, meeting cost, focus shield, fairness-ranked find-a-time (har guest ka local clock), invitation ledger (kisko gaya, SMTP ka jawab), organiser-only reschedule/cancel + SEQUENCE. Install tarteeb: E31 SQL -> `rust-calendar-install.sh` -> web pull. Ledger L68+; manifest 88 lines.

**17 Oct 06:04 PKT — FOUNDER KA NAYA HUKM (locked: AGENTS.md Rule 20):** (1) Backend ki technology — **Rust, tRPC, Quinn/QUIC, WebTransport, async/Tokio** — repo mein update ho, aur **duniya mein jo isse bhi latest hai woh bhi** use ho; repo mein saaf likha ho **kaun si technology kis kaam ke liye hai aur sirf usi kaam ke liye** -> `docs/cursor-work/TECH-MAP.md` (ek hi sach). (2) Agent = **CEO + user ka dimaagh**: jo website ke liye best ho wohi; blueprint ke gaps **bari bari tarteeb se** implement. (3) **Ultimate goal:** har user ko lage yeh product uska apna hai, competitors se behtar aur use karna aasaan; **Basic, Pro, Business, Business Pro — har plan ke user ka duniya ka best experience** (agent sochta hai har plan ka kaise). Cinematic frontend. (4) **Backend par latest technology, koi compromise nahi; mail bhi Rust (ya jo sab se latest ho) par jayegi; website sirf latest technology par.** Yeh founder rule hai. Constitution ki purani rows (AGENTS.md) ko chhedna nahi — naya sab TECH-MAP.md aur Rule 20 se; purani technology badalna (jaise mail server) sirf founder ke "haan" aur parallel-staging ke baad, kyunki mail send/receive GREEN hai (27 Sep) aur use tod'na nahi.
**18 Oct 2026, 03:39 PKT — FOUNDER KE FAISLE (18 Oct 03:31 PKT, live CRM ki tasveer ke saath) + KYA KIYA:** (1) **phase64 SQL founder ke editor mein fail** (`null value in column "organisation_id" of "org_audit_ledger"`): uski database mein is naam ki PURANI table pehle se thi (alag shakal) — meri galat dharna. Ab **usi file** (`sql/phase64_org_audit_ledger.sql`, AGENTS.md SQL-fail rule: naya naam nahi) shuru se naye NAAMON ke saath: `org_audit_chain` + `org_chain_append/verify/hash`; purani table/functions ko chhoo-ti bhi nahi. Asli Postgres 16 par purani table ke decoy ke saath test (dobara chalao theek, parallel appends). (2) **CRM "The loop" numbering** (1,2,5,9): plan ke hisaab se steps chhupte the par numbers purane rehte the -> ab position se 1,2,3,4 (Pro) / 1–7 (Business) (L60). (3) **Polar ke 2 failing tests**: payment ka masla NAHI — test file purane naam (`PERSONAL_PRO_*`) dhoondh rahi thi, registry/`personal-tiers` mein `PERSONAL_PRO_PLUS_*` hai; test theek kiya, payment code nahi chhua (L61). (4) **FAISLE (CEO ko delegate):** contacts import (vCard/CSV) **default Leads mein**, phir ek bulk "Move to People?" confirm (Rust :3200 tRPC route, multi-tenant safe); **Basic (£23) + business kind = Domains haan (1 domain), Work/CRM nahi**; Business-type plans = Domains par Work/CRM haan; **Personal Basic = Gmail jaisa simple: na org, na company address, na CRM, na chat — card/greeting/app mein kahin in ka zikr nahi**; koi package kisi se mix nahi; aam user founder se door (data mix nahi); founder workspace `founderworkspace.anexomail.com`, email `naumansherwani.founder@anexomail.com`. (5) **Founder ka tareeqa:** "kaam adhoora ki list mat do — poora kaam karke batao kya fix hua aur website par kya natija aayega"; chat mein ordered blueprint dikhao. (6) **Live site:** yeh chat computer se linked nahi => built-in browser nahi khula; WebFetch sirf SPA shell dikhata hai (HTML head + marketing text), logged-in pages nahi. Founder ki tasveer + server commands hi live ka saboot. Calendar import attendees: repo mein Bun `calendar.create` sirf attendees row likhta hai, email nahi bhejta; Rust mein `calendar.*` hai hi nahi — live behaviour ka saboot nahi, isliye copy "no invitation emails are sent" nahi, jab tak server se verify na ho (neeche).

**18 Oct 2026, 03:57 PKT — KAAM POORA (sandbox mein verified, server par pull ke baad dikhega):** (a) `/plans` Personal tab ab sirf Personal dikhata hai (apni compare table + apne FAQ; company-address services sirf Business) — L62. (b) Personal Basic/Pro+/Premium ki feature lists `plan-surface.ts` gates se line-by-line dobara likhi, jhoote wade hata diye ("1 company address", "3 mailboxes", "5 aliases", "Thread ownership", "Human support 72h" …) — L63. (c) Personal dashboard/greeting/billing par CRM/chat/company ka zikr band, denial copy "Personal Pro+" — L64/L65. (d) **Contacts import** (Google/Outlook/Zoho/Apple/LinkedIn CSV + vCard): browser parse, server dobara check, CRM plans par **Leads default -> "Move N to People?"**, Personal Basic/Basic seedha People; mojooda log overwrite nahi; Brain par live karne ke liye `brain-people-import-install.sh`; **Rust port abhi baqi (G23, Rule 22)** — L66. (e) Calendar `.ics` import ke attendees ko invite mail jaati hai ya nahi: repo mein nahi, **live ka saboot `calendar-invite-check.sh` ke output se** (checks-all mein judi) — tab tak import ki copy mein "invitation mail jaati hai/nahi" ka wada nahi — L67. (f) Premium ke claims (8K/40 log/vault) ka live test baqi (G24); `founderworkspace` subdomain ka fetch public site laya (G25). **Yeh chat computer se linked nahi => live site browse nahi hui**; agar founder chahe to Claude desktop app mein is chat ko kholkar ek message bhejein, phir computer ka folder jodein.
**17 Oct 20:38 PKT — ADMIN CENTER AUDIT + BRAIN SECURITY (READY, server par abhi nahi):** Admin ke 8 pages (health/storage/monitoring/logs/reports/diagnostics/audit/export) harness mein 390/820/1440 par dekhe. **Mile aur theek:** (1) phone par Admin tabs ek doosre ke upar chhap rahe thay (`ax-tap` min-width 44 + flex shrink) -> `shrink-0` (L58); (2) **Audit page jhooti thi, Export page par button hi nahi** -> asli (`LedgerPanel` shared, `/api/org/export`; copy sach: sign-ins record nahi, mail files ka one-click nahi — IMAP) (L57); (3) Reports raw keys -> label+unit (`report-figures.ts`), Heal now/Search/filters 44px (L59). **SECURITY (bara, code se; live par purana ho sakta hai):** (a) **har `/api/founder/*` Brain router sirf `requireUser` se gated tha** — koi bhi customer token movein (mailbox/DNS/rollback/invoice), release lock/run, revenue, storage, org kill-switch chala sakta tha -> ek founder-gate `index.ts` mein sab se pehle (L53); (b) `org.ts` ke writes par role/org-scope nahi (revoke/policy/session/break-glass) + audit khali par poori table + 'pehli organisation' fallback (L54/L55) -> `org-authz.ts` + guards; (c) audit ledger ki table/functions repo mein thi hi nahi -> `sql/phase64_org_audit_ledger.sql` (L56). **Saboot:** 47 bun tests (purane org.ts par 18/21 guard tests fail, naye par pass); phase64 asli **Postgres 16** par (sandbox mein `/usr/lib/postgresql/16`, `su postgres` se initdb/pg_ctl, socket `/tmp/pgtest16` port 54329): legacy objects ke upar, dobara, 8x25 parallel appends (seq 1..200 gap-free), tamper detect, anon denied; Brain installer ek nakli Brain+nakli origin/main par 4 scenarios (success / dobara / health-fail restore / live-edit abort). **Sach:** sandbox mein `billing-products.test.ts` ke 2 tests pehle se fail (Polar no-touch, maine nahi chhua). **Founder ke 3 kaam (Rule 15):** pull (web) + `phase64` SQL + `brain-org-install.sh` (+ `checks-all.sh` ab `org-authz-check.sh` bhi chalata hai). Ledger L53–L59, G21–G22, F7; manifest 69 file. **Baqi:** Chat audit, Pro/Business dashboard first-run, team invites (G17), contacts import decision, Rust port (Rule 22).
**17 Oct 20:11 PKT — BASIC FIRST-RUN AUDIT + MERI RUST-SOURCE GALTI SUDHARI (READY):** Harness mein asli Dashboard route (`#dashboard?plan=…&personal&empty=1&nofounder`). Mile aur theek: Personal ki pehli screen par "Connect a domain" (locked page par le jata tha) -> ab "Your address is ready / New email"; Greeting CRM+chat ka jhoota waada; phone par KPI 2x2. **Sudhaar:** pehle likha tha "Rust source repo mein nahi, compile nahi" — sach: `server/rust/main.rs` (5790 lines) + Cargo.toml repo mein HAIN; sandbox mein cargo hai magar crates.io 403 => compile nahi, syntax `rustfmt --check` se. Founder ke 182 Rust-first procs mein se repo mein sirf 10 hain; baqi + `calendar.*` Bun fallback par chalte hain. Ledger L47–L49, G3/G18 sudhare. **Agla: Rule 22 ka Rust kaam (pehle `rust-procs-check.sh` output se pata chale ke live Rust mein kya hai), phir members/teams/invitations.**
**17 Oct 20:03 PKT — PLAN-WISE ASSESSMENT #1 (READY, sandbox 390/820 dekha):** `founder/plan-surface-matrix.md` (tool: `founder/tools/plan-surface-matrix.mjs`) — asli `plan-surface.ts` se 4 plan × personal/business ka rail + lock text. **Natija: Business Pro (business) par code kuch lock nahi karta => `business_pro.test` ka masla gating nahi, account data/login hai (`test-accounts-check.sh` output chahiye).** Bug mila aur theek: locked page ka "Upgrade to …" card galat plan bechta tha (apna hi plan / Safety par Pro) — ab `PlanSurfaceGate` usi rules se poochhta hai kaun sa plan kholta hai; jahan koi plan nahi kholta wahan card nahi. Personal ke liye Safety wall copy theek. Locked-page buttons 44px. Ledger L44–L46, G20. Agla: Basic ka dashboard/mail first-run audit, members/teams/invitations (G17/L32/L33).
**17 Oct 19:58 PKT — CALENDAR .ICS IMPORT (READY, sandbox 390/820/1366/1440 dekha):** Google/Zoho/Outlook/Apple se calendar lane ka asli raasta. `src/lib/ics.ts` (browser mein parse; TZID/Windows zones/UTC, DST, RRULE daily/weekly/monthly/yearly + EXDATE + moved instances; all-day/cancelled/purane skip ginti ke saath; unsupported rule = pehli occurrence) + `src/components/app/calendar/IcsImport.tsx` (confirm panel, 3 saath `calendar.create`, progress, Stop, fail ginti, wahi file dobara chuno to sirf fail wale dobara, "Show on calendar"; "already imported" yaad sirf is browser mein). Attendees default OFF — Rust `calendar.create` invite bhejta hai ya nahi, saboot nahi (khula item). Calendar header ke export/import buttons ab 44px + aria-label. Ledger L43; G19 mein calendar hissa band, **contacts import (vCard/CSV) baqi — founder ka faisla chahiye (contacts table ya Leads).** Agla: plan-wise Basic/Business Pro assessment, `test-accounts-check.sh` ka output (business_pro.test kyun nahi chala), phir members/teams/invitations (G17/L32/L33).
**17 Oct 19:50 PKT — SWITCH JOURNEY + 3D (READY):** Founder ke hukm par `/migration` ko Google Workspace / Zoho / M365 se shift ka hub banaya: **3D `ConvergenceCanvas`** (raw WebGL, koi dependency nahi, tarteeb: reduced-motion/low-power/no-WebGL/hidden-tab safe), 5 steps, honest 'What moves' (contacts/calendar 'Ask us first', Drive/Docs 'Stays put'), FAQ. **Asli sachai (G19):** migration jobs `queued` bantin par chalane wala worker repo mein nahi; contacts/calendar import nahi (sirf .ics export); LeadForm placeholder mein NEXATECT leak tha (L40) — theek. Founder-stack audit (Rule 22): 181 calls Rust-pehle + Bun fallback, 19 sirf Bun (G18); naye read-only scripts: `rust-procs-check.sh`, `switch-journey-check.sh`, `test-accounts-check.sh`, `workspace-api-check.sh`. Browser (built-in) abhi computer se linked nahi => test accounts mein asli login nahi hua; plan-wise dekhna route-harness + `test-accounts-check.sh` se.
**17 Oct 19:40 PKT — FOUNDER KA NAYA HUKM (19:34 PKT, locked: AGENTS.md Rule 22) + LIVE SCREENSHOTS KE BUGS:** (1) Founder ne apne laptop (Lenovo L490, Windows) se **live site ki 4 tasveerein** bhejin (CRM, Mail, People, Calendar) aur kaha: "yehi kaam style pasand hai ... love you ho gaya" — style: fix + ek pull command + apni screenshots + kaam jaari + sach wali ledger (Rule 22 mein likha). Tasveeron se asli bugs: **Install ANEXOMAIL pill search box ke upar** (L34), **safed Windows scrollbar** (L35), **People ki jhooti khali-copy** (L36) — teeno READY. (2) **P1 band:** Business Pro = **12 ghante** (founder). Dekha to queue 72h lagati thi / row hi nahi banti thi (L37): `sql/phase63_business_pro_support_12h.sql` READY, Polar chhua nahi. Naya sawal F5b (Priority Support add-on ka '2 business days' ab sust). (3) **Test accounts `basic.test` / `business_pro.test`** (founder ne diye; **passwords repo/memory mein nahi**, sirf chat mein): founder kehta hai business_pro.test login nahi hota -> `docs/cursor-work/server/test-accounts-check.sh` (read-only) login store/confirm/ban/plan dikhayegi. Purane `*.buyer@anexomail.com` (E28) alag accounts hain. (4) **Founder workspace = sirf Rust/tRPC/WebTransport/QUIC/quinn/tokio; Bun/Node/webhook nahi** (Rule 22): pehle audit `founder-stack-audit.md`, phir ek ek call Rust par; fallback tab hi band jab Rust proc live verify ho. (5) **Maangen:** website ko CEO nazar se parkho (Google Workspace / Zoho se anexomail.com par kaise shift), har package duniya ka best (phone/tablet/laptop), **3D graphics frontend** (naya package nahi; raw WebGL/CSS-3D, reduced-motion safe), Admin ke 9 pages + Chat audit jaari.
**17 Oct 18:59 PKT — M6 PART 3: BILLING + ACCOUNT + ADMIN NAV (READY):** Harness mein `billing`, `billing?state=past_due`, `billing-personal`, `account` (+ sample data). **Bara bug: `relativeTime()` future ko hamesha 'now' likhta tha** => Billing par 'Auto-renews now' (renewal 20 din baad ho to bhi), Tasks 'due now'. Theek: future = 'in 3d'/date (unit-test: +30s now, +5m, +2h, +3d, +20d date; past waisa hi); Billing par asli taareekh ('Auto-renews on 6 Nov 2026', invoice date). Billing ke 30–50% opacity + 9–11px text 12px/normal contrast; toggle 44px; personal delta '+£1,767'. **Dead end (G16):** cancel/card/VAT ka koi rasta nahi (hooks bane, use nahi) -> abhi `billing@anexomail.com` ki sach line (+ past_due par), asli self-serve Polar customer-portal endpoint (Rust) baqi. Account password row wrap; Admin nav 44px + active nazar mein. Ledger L26–L30, G16; manifest 41 file. **Admin Members/Teams (19:07):** member Remove / team Delete ek tap par bina confirm thay -> confirm dialog; phone par poora email + 44px pills (L31). Repo ke Brain `workspace.ts` mein sirf 4 routes hain (members/teams/invitations-list ka handler repo mein nahi, `teams` table SQL mein nahi) -> G17; invite ka `role` server ignore karta hai (L32); invite accept par org se judna repo mein wired nahi (L33). Read-only `workspace-api-check.sh` founder se chalwana hai. **Baqi M6:** Admin ke baqi 9 pages (data ke saath harness), Chat.

**17 Oct 18:55 PKT — M6 PART 2: CRM (9 pages) PHONE+TABLET+DESKTOP AUDIT + TENANT ISOLATION (READY, server par abhi nahi):** Routes harness mein CRM routes + sample data (`crm`, `crm/pipeline|leads|relationships|collab|activity|tasks|reports|accounts`). **Mile aur theek:** (1) Tasks/Reports/Accounts pages kahin se link nahi the -> CrmStage nav; (2) deal Lost/peeche nahi ho sakta tha -> har card par 'Move to…' (server `/crm/deals/stage` sab 6 stages leta hai); (3) Relationships phone par bina label ke numbers + person tap = kuch nahi (panel list ke neeche) -> labelled line, scroll-to-panel, 'All people'; (4) Activity/Tasks/Leads par text kat'ta tha, Accept button kinare se kata hua; (5) nav pills 44px, pipeline par stage chips + snap. **SECURITY (bara):** `server/routes/crm.ts` mein shared/mentions/approvals/audit/permissions service-role se BINA org filter ke padhe jate the aur `/crm/live` timeline mein sab workspaces ki taza activity aati thi -> repo mein har read/write `orgId`/owners tak band (founder god-view poora). **Live Brain par abhi purana ho sakta hai (Rule 15):** founder `crm-tenant-check.sh` (read-only) chalaye -> output se Brain installer. Ledger L20–L25, G14, G15; blueprint M6; manifest 37 file; harness README (hash `#` ke baghair). **Baqi M6:** Billing/Account, Admin (11), Chat. **Founder ka agla qadam:** pull (ek command) + `crm-tenant-check.sh` + (pehle wala) 13.11 facts.

**17 Oct 18:44 PKT — M6 (Calendar / People / Work) PHONE+TABLET AUDIT, ASLI ROUTE CODE HARNESS MEIN (READY, server par abhi nahi):** Naya harness mode `ENTRY=entry-routes.tsx` (asli `/app/*` routes + sample data; `#cal`, `#people[?id=c1]`, `#work`, `-basicplan`, `?empty=1`) — 390/820/1440 par agent ne khud dekha. **Bara loophole mila: phone par in teeno ka `DetailPanel` chhupa rehta tha** (`mobileVisible` set hi nahi) => Calendar mein event par tap = kuch nahi, People mein contact par tap = kuch nahi, aur Work par Tasks board + "Add a task" phone par nazar hi nahi aata tha (sirf Promises list; Basic ke 'Tasks' ka wada toot'ta tha). Theek: Mail jaisa pattern (`ListPanel mobileHidden` + `DetailPanel mobileVisible` + 'back' bar), Calendar week = din-wari agenda list (7 tang columns nahi) aur month = dots + din par tap, 7-column detail grid sirf xl+; People header wrap + chips/tabs 44px; Work phone par Pro+ ko [Tasks & boards | Promises] switch (Basic seedha Tasks); TaskBoard aur contact/company stats `auto-fit` grid (820 par 4 pichke boxes khatam). Files: `app.calendar.tsx`, `app.people.tsx`, `app.work.tsx`, `ContactProfile.tsx`, `CompanyProfile.tsx`, `TaskBoard.tsx` (manifest 27 file). Ledger L15–L19. **Baqi M6:** CRM ('Move to…', 7 pages), Billing/Account, Admin (11 pages), Chat — agla kaam, `entry-routes.tsx` mein route + sample data jod kar. **Founder ka agla qadam:** 13.11 (pull + facts v2) — ab ek hi pull M6 bhi laayega; phone par Calendar/People/Work mein ek item kholna.

**17 Oct 18:24 PKT — FOUNDER KA HUKM (locked: AGENTS.md Rule 21) + 13.10 KA ASLI NATIJA:** (1) Founder ne 13.10 chalaya: **pull OK** (19 file, build OK, `/health` 200, `/app/domains` 200), **expiry-watch install OK** (26 items sab OK: mail TLS 76 din, web hosts 76-80, domain renewal 289, DKIM DNS==key, MX/SPF/DMARC/PTR; report mail founder inbox mein `status=sent`; timer chal raha), **Rust bilkul same, `/rpc/health` 200, `founder.expiry.watch` nakli token par 401 (proc pakda)** => 8o DONE (tile browser mein dekhna baqi). (2) **Facts (server ka sach):** Caddy 2.11.4, Bun 1.4.0, **Node v22.23.2 installed** (Constitution: emergency only; website/backend Node par nahi), rustc 1.97.1, PG **17.6**, Postfix 3.10.6, Dovecot 2.4.2, OpenDKIM 2.11.0; Rust: edition 2021, axum 0.7.9, tokio 1.53.1, **wtransport 0.1.14** (+quinn 0.10.2 AUR 0.11.11, rustls 0.21 AUR 0.23), `main.rs` 5,789 lines; health `webtransport live`, UDP 3443 bind, `wt_port `; pm2: n8n, anexomail-rust (48 restarts), anexochat, anexvox-ai-swarm-s2, polar-rust-payment, anexomail-web (95), anexomail-leo; **mail: MTA-STS/TLS-RPT/TLSA DNS KHALI**, DMARC `p=reject` strict maujood, Postfix `milter_default_action=accept`, `virtual_transport=anexopipe` (mail Dovecot ko nahi pipe se app ko), `/var/mail/vhosts/anexomail.com` sirf 8 KB => phone ki IMAP inbox khali ho sakti hai (8i). TECH-MAP §10 mein poori table. (3) **Founder ka naya hukm:** mission = user ko anexomail.com tak laana (CEO khud screenshot le); loophole khud band karo jab tak 100% na ho sake; har fix par pull command + pm2 restart; repo + server hamesha up-to-date; **har summary ke aakhir mein 'Loophole ledger' — sach, jhoota 'ek bhi nahi chhoda' kabhi nahi** -> `docs/cursor-work/founder/loophole-ledger.md`. M5a ke liye founder ne delegate kiya (meri 'haan' ki puchh par general hukm). (4) **Is chakkar mein bane (READY):** M5a `PlanFeatureList` (pehli 8 + Show all N; landing 390 17,902->13,058 px, Business card 3,435->700 px), M5b hamburger/menu 44px + /plans table pehla column sticky + CTA gap, `facts-tech-map.sh` v2 (master.cf, Dovecot 2.4, har pm2 process ka interpreter, mail queue/24h, mail store ginti, Rust panic ginti), `pull.sh` ab server==repo ka saboot chhapta hai (`src/ same/differ/missing` + pm2 uptime), 8u (Rust health `wt_port`), blueprint 8t/8u/D1/D2 + 8i/8q ke asli facts, TECH-MAP §10, Rule 21, ledger. **Founder ka agla kadam: command 13.11 (neeche).**

**17 Oct 06:31 PKT — M5 FUNNEL AUDIT (public site, phone/tablet) — 2 ASLI BUG MILE, THEEK (READY, server par abhi nahi):** Agent ne site ka asli route code + asli CSS harness mein chala kar (390/360/430/744/768/820/834/1024/1440) dekha: landing, /plans, /get-started, /onboarding, /auth (login, forgot, reset, signup). (1) **/auth login phone par dayen se kat raha tha** (email ka '@anexomail.com', password ki aankh, buttons clip; har phone < ~500px) — `AnexoMailField` ke input ki natural chaurai card ko 448px par rokti thi -> `w-0` (ek class). (2) **iPad (744-1023px) par website header ka 'Sign in / Get started' screen se bahar** (page 980px chauda) -> SiteNav `md`->`lg`. Dono ke baad 360-1024 par page-level overflow 0. **Founder se faisla chahiye (Rule 4):** landing + /plans par har plan card apni saari ~50-55 bullets dikhata hai (home 390 par 17,902px) -> 'pehli ~8 + Show all N' (M5a); plans.ts untouched. Baqi M5: hamburger 44px (M5b), checkout + pehla dashboard, comparison table sticky column. Manifest 19 file (AnexoMailField, SiteNav naye).

**17 Oct 07:20 PKT — AGLA COMMAND (13.10 + facts):** `facts-tech-map.sh` (read-only) pehle chalta hai: asli versions (Caddy/Bun/Rust/PG/Postfix/Dovecot), `Cargo.lock` mein axum/tokio/wtransport/quinn ka resolved version, `/rpc/health` ka `webtransport` field + UDP 3443, pm2 list, `doveconf -n` ke passdb/userdb/mail_location, postfix submission/sasl/virtual, mail ports, `_mta-sts`/`_smtp._tls`/`_dmarc`/TLSA DNS, mail store. Isse TECH-MAP ke "LIVE" status sach hon aur 8i/8j/8q/R0 bina andaze ke shuru hon. Sandbox mein crates.io 403 (policy) => Rust compile sirf server par.
**17 Oct 07:05 PKT — BLUEPRINT KE GAPS, TARTEEB SE (Domains): 8d, 8e, 8f, 8r BANE (READY, harness 390/820/1440 dekha; server par abhi nahi):** (1) **8d** step 3 par "DNS aam taur par 5-60 minute, aap ko yahin rukna nahi" + 30 auto-check ke baad "Still not found" card (kya kya missing, save/publish click, naam doubled to nahi, DNS host kaun sa). (2) **8e** `domain_taken` ke do halaat: isi workspace mein pehle se (seedha agla qadam, server ko bulaye baghair) vs kisi aur workspace ke paas ("sign in there and remove it" + hello@ mailto). Pehle jhoota paigham tha. (3) **8f** pehla company address banne par "Send your first email" card (From = naya address, To = login address, bhara hua subject/body; asli ComposeOverlay + 30s undo hold; sirf analytics sent=0 par). (4) **8r LOOPHOLE:** Basic user apni company address se Compose mein From chun hi nahi sakta tha (selector plan se chhupa); ab data se (2+ addresses). Naya TODO **8s**: `/api/mail/send` fallback identity ignore karta hai (R1 mein khud theek). Manifest 17 file sha-verified. Harness: `btn:`, `ff:` (fake clock), `list-stuck`, `taken` scenarios.
**17 Oct 06:40 PKT — RULE 20 KA KAAM BANA (docs, READY):** (1) `docs/cursor-work/TECH-MAP.md`: har technology ka kaam / NAHI-kaam / status / verify (tareekh + source). Verify hua: Rust 1.99.1 (15 Oct) edition 2024, Tokio 1.53.3, axum 0.8.9, Quinn 0.11.12, wtransport 0.7.2, Vite 8 (Rolldown, 12 Mar), Tailwind 4.2, PostgreSQL 18, React Compiler 1.0, Caddy 2.11.1, Bun 1.4.3, Stalwart v0.16.26 (Rust mail server, 1.0 se pehle, AGPL), **Safari 26.4 mein WebTransport (Mar 2026) => iPhone par bhi live QUIC push**. **Sach (dawa vs haqeeqat):** hamara Cargo.toml edition 2021 + axum 0.7 + wtransport 0.1 (purane), `opt-level="z"`, 5,789-line ek `main.rs`; "tRPC" sirf tRPC-jaisa wire (types haath ke); WebTransport "mail live" har session ke liye har 700 ms DB poll (event-driven nahi); `mail.send` abhi Bun par. (2) `docs/cursor-work/founder/plan-experience-2026-10-17.md`: Basic/Pro/Business/Business Pro har ek ka best experience + gaps. (3) Blueprint naye items: 8q (mail security), R0–R6 (Rust modernization, mail Rust par, Stalwart staging, typed contract, direct pool, event-driven push, ECH), M11 (React Compiler; vite.config no-touch => founder izazat), P1–P4 (plan-promise audit, SSO, passkeys, domain-health tile). Rust ka kaam server par scratch-copy `cargo check` se (sandbox compile nahi kar sakta). **Agla:** blueprint tarteeb se Domains ke gaps 8d, 8e, 8f.
**17 Oct 05:55 PKT — SCREENSHOT REVIEW POORA (founder ka 05:19 hukm, hissa 2):** Agent ne asli code ko harness (esbuild + Tailwind + Chromium, 390/820/1440) mein khud chala kar dekha: Dashboard (Expiry watch tile ok/warn/crit/stale + checklist ke 4 halaat + cap0 + done + iPhone hint), Mobile nav + More, Domains wizard, aur **asli `ComposeStudio`** (pehle sirf stub dekha tha). **Jo gaps mile aur theek kiye (READY, server par abhi nahi):** (a) Domains phone: "existing mail" warning registrar box ke upar, lambi SPF/DKIM value tootti nahi thi, step-3 heading beech lafz mein toot'ti thi, 8h/8g cards dabe hue the; (b) Compose: touch par select/chip/button chhote (ab 44px), To field sirf ek address leta tha (ab `multiple` + email keyboard + autocapitalize off), keyboard khulne par Send chhup sakta tha (phone par sticky Send bar; choti 480px screen par bhi nazar aata hai), ⌘↵ hint touch par bekaar tha (chhupa); (c) **LOOPHOLE (bara): Attach button file chun kar chupke se chhod deta tha — mail bina attachment ke jati thi.** Server par attachment ka koi rasta hi nahi (`/api/mail/send`, `/api/mail/schedule`, `sendmail.ts`). Ab UI honest: "Attachments — coming soon". Asli feature = **blueprint 8p (TODO)**. Manifest 17 file (ComposeStudio.tsx + naya app.domains.tsx sha). Jo review mein theek mila (koi change nahi): Expiry tile (4 halaat), checklist (phone par progress patti, tablet/desktop par tiles), iPhone hint, MobileNav. **Ab bhi sirf asli phone/iPhone se confirm hoga** (notch, keyboard, swipe) — isliye READY. Founder ka agla qadam wahi 13.10 ek command (web pull ab ComposeStudio + Domains bhi laayega).
**17 Oct 05:40 PKT — 8o BANA (READY; server par abhi nahi lagaya):** (1) **Expiry watch** `docs/cursor-work/server/expiry-watch/` (Python stdlib + openssl, systemd timer 03:47/15:47 UTC): mail TLS (993+587 live), Caddyfile ke web hosts ka live cert, domain renewal (RDAP), DKIM (OpenDKIM key == DNS), MX/SPF/DMARC/PTR; email alert (founder inbox + ALERT_TO, har level din mein ek baar, theek hone par "all clear"), `unknown` 3 run lagataar to khud alert; `/var/lib/anexomail/expiry-watch.json`. `selftest.py` 40+ check green; test ne ek asli bug pakda (SMTP 587 par smtplib hostname galat verify karta tha — ab SNI se). (2) **Rust `founder.expiry.watch`** (`server/rust/main.rs`; gate = `FOUNDER_EMAILS`/`founder_accounts`; file 36 ghante se purani => `stale`) — compile sandbox mein nahi ho sakta, `rustfmt` parse clean; deploy `server/rust-safe-deploy.sh` (build fail => src wapas, health 500 => binary wapas). (3) **Dashboard `ExpiryWatch`** (sirf founder; "Mail TLS: N days", laal/peela, poori list; sab theek ho to patti; phone par bhi) — harness 1440/820/390 + probes, `tsc --strict` clean. Manifest 16 file. **Founder ka agla kadam: 13.10 (ek command).** Founder ka 05:18 hukm ka doosra hissa (poora kaam screenshot se review) ab chal raha hai.
**17 Oct 05:19 PKT — CERT FIX ASLI SERVER PAR GREEN (13.9 ka output):** `mail-cert` install chala: purana cert `notAfter 2 Nov 2026` -> **naya `notAfter 1 Jan 2027`** (Caddy ne 3 Oct ko renew kiya tha, copy purani thi), "naya cert laga diya", `exit code: 0`, live verify: **993 (IMAPS) aur 587 (SMTP) dono `Jan 1 2027`** de rahe hain, `cert-status.json` `ok:true days_left:76`, timer lag gaya (agla run 03:21 UTC), Postfix ne dono alert mail `status=sent` kiye, Caddyfile mein `mail.anexomail.com {` block maujood (line 198). **Blueprint 8n = DONE.** (Baqi: founder inbox mein "Test alert" email apni aankh se dekhni.)
**FOUNDER KA NAYA HUKM (05:19 PKT, locked):** (1) 8o banao: founder dashboard mein "Mail TLS: N din" tile + **expiry watch** (domain renewal, DKIM, web certs — chupke se kuch expire na ho). (2) **Abhi tak ka sara kaam bari bari screenshot se review karo**, blueprint ki tarteeb se sab kaam complete karo (sach ke saath: DONE sirf live-verify par). (3) CEO ki tarah khud screenshot le kar kaam karo, gaps/loopholes hamesha ke liye theek karo, repo aur server dono update rakho.

**FOUNDER KA HUKM (05:06 PKT, locked, URGENT): TLS cert ka masla sab se bada — jaldi, HAMESHA ke liye, aur founder ko alert aaye.** Founder ka output (13.8) aa gaya, root cause pakka: mail cert Let's Encrypt ka hai (`notBefore 4 Aug`, `notAfter 2 Nov 2026`), file `/etc/anexomail/mail-cert.pem` ki mtime **18 Sep** — yani `server/mail/deploy-mail.sh` ne Caddy ke store se **ek baar copy** kiya. Caddy apna cert khud renew karta hai (web cert 3 Oct ko renew hua, `notAfter 1 Jan 2027`), magar mail wali copy ko koi refresh nahi karta (sirf `deploy-mail.sh` copy karta hai). Fix: `docs/cursor-work/server/mail-cert/` (monitor script + systemd timer, din mein 2 baar: Caddy ka naya cert dhoondo, key milao, atomic lagao, postfix+dovecot reload, live 993/587 par verify, fail ho to purana wapas; <21 din bache ya masla ho to founder inbox + ALERT_TO par email, roz ek baar; `/var/lib/anexomail/cert-status.json`). **READY (sandbox simulation green) — founder ne install command (13.9) abhi nahi chalaya.** Dusre facts 13.8 se: 587/465 asli **Postfix master** hain (`master.cf` mein `submission`/`submissions`), 993/143 Dovecot (`ssl = required`); Dovecot **2.4.0**, `mail_driver = maildir`, `mail_path /var/mail/vhosts/%{user|domain}/%{user|username}`, `passdb pam` + `userdb passwd`, `doveadm user '*'` = 12 users (company addresses; customer mailboxes ka Dovecot mein hona SABIT NAHI — 8i/8j ke liye ek aur sawal).

Founder **asli browser login** se test accounts ek ek karke check kar raha hai. Agent har waqt **sirf ek cheez** batata hai ke kya dekhna hai; founder dekh le to agli. Current account: **`pro.buyer@anexomail.com`** (Pro plan, Business workspace). Basic founder ne chhod diya ("Basic ko chhodo, Pro karo"); Pro ke baad Business, phir Business Pro.

Ho chuka (founder ke screenshot se, 16 Oct 21:37 PKT):
- Pro rail: Dashboard | Mail | People | Calendar | Work | CRM | Domains. Org aur ANEXOChat nahi. Sahi.
- Rail ka Pro text ab naya: "Shared inbox with collision guard, boards, tasks and CRM — your team, organised." Pehle founder ko purana "…ANEXOChat — teams done right" dikha tha; wajah browser/service-worker ka purana cache thi (code mein naya tha). Hard refresh se theek hua.
- Dashboard par: storage "44 B / 50 GB · 10 GB × 5 mailboxes", badge "probuyer.axonetis.com · Domain not verified · Finish setup", Received 1, Sent 1, Send success 50%.

**Domains page ka pehla look (founder ka screenshot, 17 Oct 02:37 PKT) — 3 cheezein pakdi gayin:**
1. **Scroll bug (asli bug):** page neeche se kat raha tha ("No company addresses yet." aadha). Wajah: `AppShell` `h-screen overflow-hidden` hai aur `app.domains.tsx` par scroll dabba (`min-h-0 flex-1 overflow-y-auto`) tha hi nahi — wizard ke 5 records tak pohanchna mumkin nahi tha.
2. **Dashboard vs Domains tazaad:** dashboard "probuyer.axonetis.com · Domain not verified · Finish setup" dikhata tha, Domains page "0 of 3 · No company domain yet". Wajah: domain `organisations.domain` mein (signup/E28 seed) hai, `org_domains` khali (mera Rust test usay hata chuka tha). Asli buyer ke saath bhi yahi hota.
3. **Khali page sada tha** (plain card, CTA ek kone mein).

Fix (repo mein, 17 Oct 2026): `src/routes/app.domains.tsx` dobara likha — scroll dabba + wizard scroll-into-view, signup wala domain "Finish connecting <domain>" suggestion (dashboard summary se), hero empty state (3-step preview), jud'ti hui step lakeer, record cards 1/5…5/5, live ring (x/5) + countdown, DKIM row khud refresh, verified celebration, Addresses ka locked preview. Syntax `bun build --no-bundle` green; asli build server par.

**17 Oct 02:49 PKT:** founder ne claude.ai wale Claude chat ka context paste kiya (Appendix A) aur kaha: naye naam ki file banao, "her latest command repo mein update ho", aur yeh rule likho ke founder se chat karne wala pehle yeh context padhe. Ho gaya (yeh file, AGENTS.md Rule 18, `.cursor/rules/founder-chat-context.mdc`).

**Domains page browser mein dekha (founder ke 2 photo, 17 Oct 03:06 PKT):** scroll theek (scrollbar aaya, neeche "No company addresses yet." poori dikhi); hero "Finish connecting probuyer.axonetis.com" + 3 qadam + "Connect probuyer.axonetis.com" + "Use a different domain" + cap note; Addresses ka locked card. **Founder ka sawal:** kya yeh duniya ka best UI hai? **Mera jawab (honest): nahi — achha professional SaaS level, ~7/10.** Wajahein: sirf copy-paste (registrar detect/ek-click DNS nahi), email page par dikhti nahi, harkat/skeleton kam, "Use a different domain" button jaisa nahi lagta, login address locked card ke neeche. Yeh #8a/#8b ke naam se blueprint mein TODO likhe. Photo se contrast pakka nahi parha (code mein button navy + near-white text hai, photo mein cyan/dhundla) — asli screenshot (Win+Shift+S) maangna.

**17 Oct 03:19 PKT — founder ki maang (is ke baad ka kaam):** (1) Domains ki kamzoriyan theek karo (#8a) aur registrar pehchanna (#8b); (2) UI itni advance ke Vercel se aage ho, tab hi dikhana; phir poori website ke liye "duniya ka best"; (3) "cinematic / cinema feel UI" kya hota hai samjhao; (4) **axonetis.com founder ka doosra project hai, sirf TEST domain** — ANEXOMAIL domain nahi bechta, maqsad hai "user business email kaise banaye"; (5) "repo mein sab code hai, server par sab hai, masla compact ke baad bhool jana hai — latest technology rule par ek hi baar mein theek karo".

**Ho gaya (17 Oct ~03:35 PKT, repo mein, READY):** `src/routes/app.domains.tsx` cinematic standard par dobara likha — hero mein "From: you@<domain>" mail preview, "Use a different domain" asli button, login address pehle, skeleton loader, stagger, registrar auto-pehchan (DNS-over-HTTPS se), step 3 ka jashn. **Asli UI sandbox mein dekhi gayi** (`docs/cursor-work/frontend/ui-harness/`: har state + 390 px screenshots). Standard + poori website ka rasta: `docs/cursor-work/frontend/cinematic-ui-standard.md`. Deploy ab 13.0 (13.6 ka purana block shamil). **Founder ke browser mein dekhna baqi — isliye #8/#8a READY, DONE nahi.**

**17 Oct 03:45 PKT — founder ka asli browser (page text paste): Domains v2 server par LIVE hai aur wizard qadam 1→2 chala.** Nateeja: "1 of 3 domain · Pro", step rail, "At your registrar…" copy, Namecheap/GoDaddy/Cloudflare/Other tabs + "Open Namecheap", 5 record cards (TXT `_anexomail-verify` value `e214…`, MX `@` → `mail.anexomail.com` prio 10, SPF `v=spf1 a:mail.anexomail.com ~all`, DKIM `anexo1._domainkey` "Key is being prepared", DMARC `_dmarc`), "I've added them — check now" / "Finish later", Addresses (login address pehle, locked preview). Yaani qadam 1–2 live DONE-nayi cheez; qadam 3 (live ticks/verified) aur asli DNS check baqi. **Do asli kamiyan mili:** (1) registrar auto-pehchan `probuyer.axonetis.com` par nahi chali (subdomain ke apne NS nahi hote — parent `axonetis.com` poochhna tha), (2) subdomain par agar DNS parent zone ka ho to Name lamba likhna parta hai (`@` → `probuyer`, `_dmarc` → `_dmarc.probuyer`) — page ne yeh nahi bataya. Dono repo mein theek (blueprint 8c, READY); manifest sha badla.

**17 Oct 03:54 PKT — 13.0 ASLI SERVER PAR GREEN (founder ka output):** `origin/main = b58694f`, "memory/docs: 4 file(s) taza", `wrote src/routes/app.domains.tsx`, build OK, `/health 200`, `/app/domains 200`, memory stamp server par `03:55 PKT` = repo. Backup `/root/i9/sync-20261016-224907`. Server ki dirty tree ki list mili (#10 survey): `M` = AGENTS.md, bun.lock, 3 docs index/plan files, `src/components/app/{AppShell,CommandPalette,compose/ComposeStudio,dashboard/Greeting,dashboard/Panels,mail/MailRail}.tsx`, `src/lib/{dashboard,mail,plan-surface,workspace-i18n}.ts`, `src/routeTree.gen.ts`, `src/routes/app.admin.addresses.tsx`, `src/routes/app.mail.$folder.tsx`; `??` = `.env` (secret, repo mein KABHI nahi), purani installer scripts (`e3/e7/e30/i8-*`), `t7/t16` scripts, `E27` SQL, `mail-identities-locked…md`. Kaun si `M` file server par repo se alag hai — agle pull.sh se khud dikhega (neeche `git diff --stat origin/main`).

**FOUNDER KA MAQSAD (17 Oct 03:54 PKT, locked):** "real user ko website ka best experience dena; test account se real user wali sab cheezein nahi ho sakti, lekin jitna ho sake **user ki tarah socho**." Is liye har screen ko **asli user ke 5 minute** ki nazar se dekho (kya sochega, kahan phansega, kya kho sakta hai), aur jo test se sabit nahi ho sakta (payment, asli registrar par DNS, bahar se aane wali mail, spam folder, asli phone) use alag "founder ko khud dekhna" list mein likho. Real-user khatre ki list: blueprint #8c+.

**17 Oct 04:20 PKT — #8c banaya (READY, sandbox mein dekha):** wizard qadam 2 ab domain ke MX/SPF DNS-over-HTTPS se dekhta hai; pehle se Google/Microsoft/Zoho… ho to warning ("is domain par mail pehle se hai, MX lagane se purane mailboxes band") aur SPF ka merged value + Copy. Subdomain (probuyer) par kuch nahi aata (uska apna MX nahi). Manifest sha ab `04b1b3542f4e9706`. pull.sh ab server-vs-repo ka `git diff --stat origin/main` bhi dikhata hai (dirty-tree survey khud). **Agla qadam wahi: 13.0 dobara + qadam 3 ka check (DNS badle bina).**

**FOUNDER KA HUKM (17 Oct 04:26 PKT, locked) — gaps sab se aage, Rust-first, har section CEO ki nazar se:**
1. Jo gaps mile (pehli mail ka test, IMAP/SMTP settings, IMAP import, dashboard checklist, Domain Connect, catch-all/forwarding/vacation) **latest technology par** theek karo aur **sab se aage** rakho (Domains ki aur polish se pehle).
2. **Backend hamesha Rust** (tRPC-style `/rpc`, QUIC, WebTransport, async Tokio). **Bun sirf emergency fallback.** Naya backend kaam Bun mein nahi. (Sach: abhi `mail.send`, `org.mailboxes.*` Rust se Bun ko "use_bun_fallback" bhejte hain — yeh Rust ki taraf jana hai, plan R1 neeche.)
3. **CEO ki nazar se har section** dekho — Dashboard, Mail, People, Calendar, Work, CRM, Domains — aur batao competitor se kaise aage nikalna hai. Jawab: `docs/cursor-work/founder/ceo-section-review-2026-10-17.md`.
4. **Sandbox ki had (sach):** yahan Rust compile nahi ho sakta (crates.io band, `cargo check` fail). Isliye Rust code **READY (compile baqi)** rehta hai jab tak server par `cargo build --release` green na ho; deploy hamesha restore-on-fail block se (purani binary wapas), phir `pm2 restart anexomail-rust --update-env && pm2 save`. Frontend ko harness mein dekha ja sakta hai.

**17 Oct 04:06 PKT — founder ne 13.0 (824ab3a) chalaya + 7 photo bheji: asli server par sab theek.** Step 2: "We found your DNS is at Namecheap" aaya (**axonetis.com ka DNS Namecheap par hai**), subdomain note, "If DNS zone is axonetis.com" ke lambe Name (`_anexomail-verify.probuyer`, `probuyer`, `anexo1._domainkey.probuyer`, `_dmarc.probuyer`), DKIM ki asli key (v=DKIM1; k=rsa; p=MIIB…) aa gayi. Step 3: "Checking probuyer.axonetis.com", 0/5 Waiting, countdown, "Checking…", Check now — asli backend par chal raha hai. (Photo mein button cyan/dhundla aur cards grey hain: laptop ki screen/camera ka asar lagta hai, harness mein navy + gehra; asli Win+Shift+S screenshot se pakka karna.) Pull output: server ki `M` files (AppShell, ComposeStudio, Greeting, mail.ts …) **repo ke BARABAR nikli** (`git diff --stat origin/main` mein sirf `bun.lock` 4 lines, `routeTree.gen.ts` 42 lines, aur untracked `domains.ts` / `app.domains.tsx`); yani server "dirty" sirf is liye ke server ka git HEAD purana hai.

**FOUNDER KA NAYA HUKM (17 Oct 04:06 PKT, locked):** CEO ki tarah socho; competitor **Google Workspace aur Zoho Mail**; pehle Zoho ka basic flow karo, phir ANEXOMAIL ko un se behtar banao. **Ho gaya:** `docs/cursor-work/founder/competitive-baseline-zoho-google-2026-10-17.md` (official pages se verify kiya hua baseline + ANEXOMAIL ki jagah + tarteeb); blueprint 8d–8m; **8g READY** ("Someone else manages your DNS?": email instructions + copy all, Zoho ke "Send to DNS admin" jaisa, bina server ke) aur **8h READY** (step 3: "aap ka inbox DNS ke intezar mein bhi chal raha hai" + Open your inbox) — sandbox mein dekha, manifest sha `d3c72ea4e9351247`. **Agle (tarteeb):** 8f pehli mail ka test → 8i IMAP/SMTP settings → 8j IMAP import → 8k dashboard checklist → 8l Domain Connect (founder decide) → 8m catch-all/forwarding/vacation. AI sab se aakhir (#41).

**17 Oct 05:00 PKT — founder ka asli output (2 hisse):**
1. **Deploy GREEN:** `origin/main = ced4a63`, manifest ki 14 files server par `same` (pehle hi lag chuki thin), memory stamp `04:54 PKT` = repo, `/health 200`, `/app/domains 200`. Mobile batch 1–3 ab server par hai; **founder ne abhi phone par dekha nahi — isliye READY, DONE nahi.**
2. **13.7 (IMAP/SMTP fact-finding) ka sach:** ports 25, 143, 465, 587, 993 sunn rahe hain (110/995 nahi). Dovecot: `protocols = imap lmtp`, `auth_mechanisms = plain login`. Postfix: `smtpd_sasl_type = dovecot`, `smtpd_sasl_path = private/auth`, `smtpd_tls_security_level = may`, cert `/etc/anexomail/mail-cert.pem` (CN `mail.anexomail.com`). `doveadm` hai, `imapsync` nahi.
   **Jo is output se SABIT NAHI hota (isliye 8i abhi nahi banta):** (a) `doveconf -n` mein koi passdb/userdb nahi dikha — pata nahi Dovecot asli user-login karata hai ya mail sirf Postgres mein hai; (b) `postconf -M` ne `submission`/`smtps` nahi dikhaye jabke 587/465 sunn rahe hain — kaun sa process sun raha hai (Postfix ya kuch aur) maloom nahi; (c) mail ka store Maildir hai ya Postgres, maloom nahi. 8i (settings page) / 8j (import) in teeno ke jawab ke baghair nahi — andaze se port/auth likhna user ko galat setting dega.
   **BARA LOOPHOLE (naya):** TLS cert `notAfter = 2 Nov 2026 21:05 GMT` — **16 din baad**. Agar yeh Let's Encrypt ka copy hai aur khud renew nahi hota to IMAP/SMTP TLS tootega. Renew ab tak nahi hua (30 din se kam bache hain) — shak. Check: 13.8.

**BATCH 3 + CEO REVIEW (04:54 PKT, READY):** (1) `docs/cursor-work/founder/ceo-section-review-2026-10-17.md` likha — viral loops (V1–V8, Hotmail wali "Sent with ANEXOMAIL" line founder ke faisle par), phone/tablet status, aur sab 7 sections (Dashboard, Mail, People, Calendar, Work, CRM, Domains): kya hai (code se), gap, competitor se aage kaise, tarteeb. (2) Touch: `Button` default 44px (touch par), `sm`/`icon` par `ax-hit` (nazar aane wala size wahi, hit-area 44px); calendar ke nav/view pills par `ax-hit`; `ax-hit` pehle se positioned (absolute/fixed/sticky/relative) element ko relative nahi banata (harness mein dekha). **Founder ke faisle:** V1 (mail ke neeche line, kis plan par), V8 referral, 8l Domain Connect. **Agla (tarteeb):** 8f pehli mail ka test -> 13.7 output aane par 8i/8j -> R1 Rust -> M5/M6 asli phone par.

**MOBILE/TABLET BATCH 2 BANA (04:53 PKT, READY, harness 390/820 dekha — blueprint M7, M10):** (1) **M10:** `AppShell` ka `<main>` ab zaroorat par khud scroll karta hai — jis page ka apna scroll dabba nahi (devices, movein …) woh Domains ki tarah neeche se kat jata tha; panel wale pages par asar nahi; naye page par upar se. (2) **M7:** `InstallHint` — sirf iPhone/iPad Safari par "Share -> Add to Home Screen" card (iOS mein install prompt hota hi nahi; Android chip pehle se hai). (3) Phone par setup checklist compact (progress patti + Next + button; poori list pehli screen kha jati thi). Funnel (landing/auth/onboarding/plans) ka static audit: pages pehle se responsive (`text-4xl md:text-6xl`, `max-w`, table `overflow-x-auto`); sirf global 16px input fix chahiye tha (ho gaya). **Funnel asli phone par dekhna baqi (M5).**

**MOBILE/TABLET BATCH 1 BANA (17 Oct 04:50 PKT, READY, harness 390/820/1440 par dekha — blueprint M1–M4, commit 3736efa):** audit mein asli gaps mile aur theek hue: (1) `AppShell` `h-screen` -> `h-dvh` + header safe-area + viewport `viewport-fit=cover, interactive-widget=resizes-content`; (2) phone ki bottom patti 7–14 items side-scroll karti thi (Domains/CRM chhup jate the) -> naya `MobileNav.tsx`: 4 tabs + More sheet + phone par workspace switch; (3) `ComposeOverlay` phone par chhota floating card tha -> poori screen (tablet/desktop par pehle jaisa); (4) global (`styles.css`): iOS 16px input (zoom band), tap delay band, panel scroll-chaining band, `ax-hit` 44px touch area (mail pills/back arrow par), shell mein pull-to-refresh band (draft na ude), sheet close 44px. Manifest mein 8 file. **Nahi dekha (sach):** asli `ComposeStudio` ka andar ka phone layout, safe-area (notch) asli iPhone par, asli keyboard. Agla: M5 funnel audit (landing/auth/onboarding/plans/checkout phone par), M6 har section, M7 iPhone install hint, M8/M9 viral + Urdu (founder decide) — blueprint mein.

**FOUNDER KA NAYA HUKM (17 Oct 04:43 PKT, locked — AGENTS.md Rule 19):** (1) **Mobile aur tablet users ke liye bhi website** — unki tadad bahut zyada hai, woh mobile se ANEXOMAIL use kar saken; har screen 1440 / 820 / 390 px par banti aur dekhi jati hai. (2) **Abhi ke abhi** jahan bhi CEO ko gap/loophole dikhe, theek karo — user ka dil aur dimagh ban kar. (3) Soch: yeh product poori duniya mein **viral** kaise hoga — deep thinking, gaps aur loopholes sab. Agent ka pehla qadam: poori app ka mobile/tablet audit (AppShell nav, har section), phir gaps ek ek theek, harness mein teen width par dekh kar. Neeche ki "8k BANA" baat is se pehle ki hai.

**8k BANA (17 Oct 04:35 PKT, READY, sandbox mein dekha):** Dashboard par `SetupChecklist` — Greeting ke neeche, WidgetGrid se pehle. 5 qadam asli data se tick: account ✔ / domain jura (`mail.domains.list`) / DNS verified / company address (`mail.addresses.list`) / pehli mail (`dashboard.analytics` sent>0; analytics na aaye to yeh qadam hi nahi). Kuch nahi dikhta jab: data load na ho, plan mein domains nahi (`domain_cap` 0), sab poora, ya user ne X dabaya (localStorage, sirf per-viewer). Files: `src/components/app/dashboard/SetupChecklist.tsx` (naya) + `src/routes/app.index.tsx` (3 line mount). Manifest sha `cfa23d242cfead4a` + `4f99897a191b92de`. Harness mein har state (dashA..E, cap0, noanalytics) desktop + 820 + 390 px dekhi; mobile par button heading par chadh raha tha — theek kiya. **Sach:** Pro/Basic 'personal' kind hain magar unke paas Domains hai (pro.buyer), isliye card `kind` se nahi, `domain_cap` se chhupta hai. **Founder ke liye:** 13.0 chalao, Ctrl+Shift+R, `pro.buyer` Dashboard par 'Finish setup' card (domain jura hai, DNS pending => 2/5, 'Continue' Domains par le jata hai). **Agla (tarteeb):** 8f pehli mail ka test -> 8i/8j (pehle server fact-finding block) -> 8m -> 8l (founder decide); saath mein CEO section review doc + Rust R1 plan.

Uske baad wizard ka proof (D) ek ek qadam: Connect → naam (suggestion chip) → 5 DNS records + Namecheap/GoDaddy/Cloudflare tabs + Copy buttons → live ticks. Phir E ka proof (Compose "Send from", Inbox address label, aane wali mail par bhi).

---

## 2. Founder ki maangen jo abhi khuli hain

- **D proof** — domain wizard founder ke browser mein dikhe aur kaam kare (backend server par green hai, browser ka dekhna baqi). `#8` isliye READY hai, DONE nahi.
- **E proof** — `#7`: Compose "From" mein company address, Inbox mein address ka label, aane wali mail dono par. Backend 15 Oct ko proven; browser ka proof baqi. `#7` READY.
- **Frontend UI/UX duniya ke level ka** (founder: "duniya ka advance Frontend UI UX", "Vercel se advance", poori website). Domains page cinematic standard par dobara likha gaya (READY, founder ka browser baqi). **Agli screens:** `docs/cursor-work/frontend/cinematic-ui-standard.md` ke "Poori website ka rasta" table ki tarteeb (Dashboard → Compose → Inbox → baqi). Har screen: harness screenshot (desktop + 390 px) → sha-guarded single-file block → founder ka asli screenshot. `src/lib/domains.ts` ke hooks na badlo, `vite.config.ts` / `package.json` / `bunfig.toml` na chhuo.
- **Founder workspace Rust-only (Rule 22)** — audit + ek ek call Rust par; **website/switch-journey assessment; 3D frontend; har package ka best experience** (19:34 PKT order).
- **Compact-chat masla** — yeh file + Rule 18 (17 Oct 2026 ko founder ke kehne par bani).

---

## 3. Locked tarteeb (founder, 14 Oct 2026)

1. **User side**, blueprint ke number se: #10, #13, #14–#35, #37–#39 (#7, #8 pehle browser se confirm hon).
2. **Founder side** (`[FOUNDER]` tag): #3a, #11, #12, #36, #36a.
3. **ANEXOChat** (#40, #40a) — Phase 32+ sirf founder ke paste par.
4. **Sab se aakhir** `ai.anexomail.com` (#41). AI ko haath nahi lagana.
5. Real test tarteeb (#20): Basic → Pro → Business → Business Pro.

Company addresses ka **ek unified inbox**; `hello@` ka kaam founder-side. **Ali (`alikhan@anexomail.com`) ko delete nahi karna.**

---

## 4. Founder ke saath kaam ke qaide (locked)

- **Zubaan:** Roman Urdu, "aap", "kero/chalao". Kabhi "tu/tera/kar" nahi. Jawab chhote.
- **Seedha sawal = seedha jawab chat mein.** Jawab ke liye repo mein mat jao, repo ki baat mat chhedo jab tak woh na kahe. Founder bohot jaldi gussa hota hai jab agent repo-centric ho jata hai ya lamba block deta hai.
- **Manual test = ek waqt mein ek cheez** ("jab ek dekh lo gay phir next").
- **Bina zaroorat sawal nahi.** Gate / "PASS PASS" scripts nahi. Asli output wale seedhe commands (curl code, grep, psql, pm2).
- **Rule 15:** server ka sach server par. Agent server par kuch nahi chala sakta; chat mein ek copy-paste block deta hai, founder chalata hai aur output paste karta hai. Output aane se pehle "DONE" nahi.
- **Rule 17:** test browser se nahi (SQL-seeded accounts, token, curl). Ab founder UI khud apne login se dekh raha hai, to browser sirf wahan jahan screen dekhni zaroori ho.
- **Har jawab jo repo badle, uske aakhir mein founder ko 13.0 ki EK pull command do** (founder, 17 Oct 03:39 PKT: "hamesha pull ki command do, pm2 restart hamesha"). Woh command `pull.sh` chalati hai: server ki memory file (yeh file), AGENTS.md aur docs taza karti hai, manifest ki code files sha-guard se lagati hai, aur **hamesha** `pm2 restart anexomail-web --update-env && pm2 save`. Code file badlo to `DEPLOY-MANIFEST.txt` mein uska sha usi commit mein badlo.
- **Har deploy/pull block mein `pm2 restart <app> --update-env && pm2 save` hamesha** (founder, 17 Oct 2026): web badla to `anexomail-web`, Rust badla to `anexomail-rust`, Brain badla to `anexomail-leo`. `polar-rust-payment` kabhi nahi.
- **Rule 5:** status sirf DONE (live verify) / READY / TODO.
- **Secrets repo ya chat mein nahi.** Test passwords sirf server par `/root/test-accounts/<handle>.pw`.
- **SQL fail** ho to usi file ko theek karo (`_v2` nahi). Naya SQL = E-series (`docs/cursor-work/sql/E<n>_….sql`); abhi tak E30 tak bana hai, agla E31.
- **Git:** force-push / amend / squash nahi. Har commit ke aakhir mein do trailers: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` aur `Claude-Session: <is chat ka session URL>` (URL har chat ka system-reminder deta hai).
- **Branding:** build-platform ka naam/logo repo ya UI copy mein nahi. NEXATECT sirf internal, public copy mein nahi.
- **Backend:** naya kaam Rust :3200 primary; Bun sirf fallback.
- **Kaam ka jo style founder ko pasand hai (19:34 PKT, "love you"):** har batch = (1) khud screenshots (390/820/1366/1440) se parkho, (2) theek karo, (3) **ek pull command** (pm2 restart+save), (4) sach wali Loophole ledger, (5) bina ruke agla batch, repo + yeh file taaza. Founder ke bheje live screenshots pehle padho. Passwords chat mein aayein to repo/memory mein kabhi nahi.
- **Mobile + tablet (Rule 19, 17 Oct):** har screen 1440 / 820 / 390 px par banao aur harness mein dekho; teeno theek hon tab hi READY. Nav mobile par drawer/bottom bar, `100dvh`, safe-area, 44 px touch, input 16 px.
- **Agent ke liye (17 Oct sabaq):** docs likhte waqt shell ke unquoted heredoc mein backtick mat rakho — shell unhein chala deta hai aur file kharab hoti hai. Write tool ya quoted heredoc (`<<'EOF'`) use karo.

---

## 5. System map (founder ka Hetzner server — asli system)

| Cheez | Jagah |
|---|---|
| Web (SSR, Bun) | `/opt/anexomail-web`, pm2 `anexomail-web`, :3000. Build `bun run build:bun`, output `.output/` |
| Brain (Bun, fallback) | `/opt/anexomail`, pm2 `anexomail-leo`, :3100 |
| Rust (primary) | `/opt/anexomail-rust`, pm2 `anexomail-rust`, :3200, `/rpc/<proc>` |
| Polar payment (Rust) | pm2 `polar-rust-payment`, :3400 — **NO TOUCH** |
| Mail | Postfix / Dovecot / OpenDKIM |
| DB | `. /etc/anexomail/sync.env && psql "$WORKING_URL"` |
| Env | `/opt/anexomail/.env` (`SUPABASE4_URL`, `SUPABASE4_ANON_KEY`), `/etc/anexomail/sync.env` |
| Test accounts | `/root/test-accounts/<handle>.pw` (chmod 700 folder) |
| Domain DKIM cron | `server/mail/e15c/sync-domains.sh`, har minute (domain add ke baad DKIM value ~1 min mein aati hai) |

Deploy ke baad hamesha `pm2 restart <app> --update-env && pm2 save`. `polar-rust-payment` ko restart bhi nahi.

---

## 6. Delivery ka tareeqa (agent → server)

- File badalni ho: chat mein ek block. Ya to **gzip+base64 + sha256 guard**, ya `git -C /opt/anexomail-web fetch` + `git show origin/main:<path>` + sha guard. Server par poora `git pull` nahi (Rule 14): sirf specific files, anchor-gated installer, backup + `restore.sh`, build fail ho to sab wapas.
- Installer generators: `docs/cursor-work/server/i8-build-installer.py` (#8), `e30-build-installer.py` (E30). Generator **commit se pehle** chalana hai (git HEAD vs worktree diff leta hai).
- SQL seedha server se `psql "$WORKING_URL"`.
- Agent ke sandbox mein `anexomail.com` nahi khulta (proxy 403), `node_modules` / registry nahi, to asli `tsc` nahi chalta (sirf `bun build --no-bundle` syntax check); asli build server par. Built-in browser / computer tools is chat se linked nahi — agent live site khud nahi dekh sakta, founder ke screenshot par chalta hai.

---

## 7. Test accounts (E28 SQL se, Business workspace; passwords sirf server par)

| Handle | Plan | Test domain |
|---|---|---|
| `basic.buyer@anexomail.com` | basic | `basicbuyer.axonetis.com` |
| `pro.buyer@anexomail.com` | pro | `probuyer.axonetis.com` |
| `business.buyer@anexomail.com` | business | `businessbuyer.axonetis.com` |
| `bpro.buyer@anexomail.com` | business_pro | `bprobuyer.axonetis.com` |

Ek block jo sab chaar ko seed/dekh leta hai (pm2 restart, public pages, har plan ki rail/dashboard/send-from/domains/addresses/gate, #10 survey): `docs/cursor-work/server/t16-accounts-look.sh`.

Plan table (live verify, Pro ki 16 Oct output): domain cap Basic 1 / Pro 3 / Business+ unlimited; mailbox cap Basic 3 / Pro 5 / Business 30 / Business Pro unlimited; Pro storage 10 GB × 5 mailbox = 50 GB; `work.tasks.list` Pro par 200, Basic par 403.

---

## 8. Status snapshot (Rule 5) — 17 Oct 2026

**DONE (live):** #1, #2, #3, #4, #5, #6, #7a (domains A/B/C), #9, #18a, #18b; U1 (backend), U2, **U3** (Pro rail text browser mein dekha).
**READY (repo/server mein, browser ya live verify baqi):** **#7** (Compose From + Inbox label), **#8** (Domains page), #10 (live-only Brain files), #15, #16, #17a, U4, U6 (Mail rail browser mein nahi dekha), E21, E22, E23, E24.
**TODO:** #11, #12, #13, #14, #17, #17b, #18, #18c, #19, #19a, #20 (real card), #20b, #20c, #21–#30a, #31–#41, U5, U7.

Detail aur har item ka text: blueprint ki list. Yeh snapshot sirf navigation ke liye hai — farq ho to **blueprint jeetta hai**.

---

## 9. Khule findings / founder ke faislay

- **axonetis.com sirf TEST domain hai** (founder, 17 Oct 03:19 PKT): founder ka doosra project; `probuyer.axonetis.com` jaise test domains. ANEXOMAIL domain bechta nahi — product ka maqsad: user apne domain par business email banaye. Agent kabhi "domain khareedo" jaisa flow ya copy na banaye.
- **Sandbox UI harness** (`docs/cursor-work/frontend/ui-harness/`, 17 Oct): asli `src/styles.css` + asli page code se screenshot. Yeh sabut **READY** deta hai, DONE nahi (stubs nakli, founder ka browser alag). Sandbox mein asli `tsc` nahi (npm registry band, `@types/react` nahi), sirf esbuild syntax + render.
- **Primary button ka rang:** founder ke photo mein Connect button cyan/dhundla text, repo CSS aur harness mein navy (`--primary`) + saaf near-white text. Photo ya live server ki CSS ka farq — asli screenshot (Win+Shift+S) se tay hoga.
- **Registrar auto-pehchan** browser se `cloudflare-dns.com` ko DoH call karti hai; Caddy par koi `connect-src` CSP lagi ho to lookup chup-chaap fail hoga (manual tabs rahenge). Repo mein CSP nahi, server ka Caddy dekha nahi.
- **Server tree ka asli sach (17 Oct 04:06):** 20 `M` files repo ke barabar hain; farq sirf stale git HEAD ka hai. Ek non-destructive ilaaj (sirf founder ke "haan" par): `cd /opt/anexomail-web && git reset --mixed origin/main` (HEAD aage, files jaisi hain waisi; purana HEAD reflog mein) — phir `git status` mein sirf `bun.lock`, `routeTree.gen.ts`, `.env` (secret, kabhi commit nahi) bachte hain aur Rule 1 ka seedha `git pull --rebase` dobara chal sakta hai. Abhi pull.sh isse bina bhi sahi chal raha hai.
- **Server ki git tree dirty hai** (17 Oct): Rule 1 ka `git pull --rebase` "unstaged changes" par ruk jata hai, kyunke installers ne files badli hain. Poora pull tab chalega jab `cd /opt/anexomail-web && git status --short` ka output dekh kar tay ho jaye ke kaun si files repo jaisi hain (commit karni hain) aur kaun si live-only (repo mein pehle aani hain). Tab tak single-file sha-guarded block.
- Basic/Pro par **storage ledger nahi banti** (`chat_ensure_workspace` `chat_not_entitled` deta hai, mail-worker `workspaceId` null par reserve/commit chhor deta hai) — yani Basic/Pro par quota enforce/record nahi hota. Founder decide.
- **U5** CRM Loop Pro par (numbers 1, 2, 5, 9 dikhte hain; 3/4/6/8 gayab) aur **U7** "Assigned to me" folder khali — dono founder decide.
- Dashboard par **"Send success 50%"** dikha (pro.buyer: 1 mail bheji, 1 receive). `mail_scheduled` ke sent/failed se aata hai; kya waqai ek failed hai — check baqi.
- Brain (`/opt/anexomail/src`) ke **live-only libs repo mein nahi** (#10) — jo import hote hain woh pehle repo mein aane hain (`lib/leo-brain.ts` wagairah; AI ko chhedna nahi). Live `anexochat.ts` repo se purani hai. Sab "repo update" par.
- Survey ke hisaab se missing: Delete for everyone, Voice notes, Permanent business search, one-click access revocation (abhi sirf device revoke), Support SLA code.
- **Service worker cache:** deploy ke baad users ko purani UI dikh sakti hai jab tak hard refresh na ho (`src/lib/pwa.ts`, `/sw.js`, `?sw=off` kill switch; VitePWA `registerType: "autoUpdate"`, `vite.config.ts` no-touch). Fix ka idea (abhi kiya nahi): `pwa.ts` mein update par `controllerchange` par reload. Founder decide.
- Ali ka personal account payment ke baad provisioning abhi test nahi hui. Test passwords rotate karne hain (F, founder).
- Bina payment ke Polar 100%-off discount se checkout test ka idea blueprint (E22) mein hai; real card test founder ka faisla.

---

## 10. Founder ka server par purana chat record

Founder ke mutabiq purani chats server par pehle se mehfooz hain, lekin **path unhe yaad nahi (17 Oct)**. Dhoondhne ke liye server par yeh chalao aur output yahan se parh kar path **is section mein likh do**:

```bash
find /root /home /srv /mnt /opt -maxdepth 4 \( -path '*/node_modules' -o -path '*/.git' -o -path /opt/anexomail-web -o -path /opt/anexomail -o -path /opt/anexomail-rust -o -path '*/.cache' -o -path '*/.npm' -o -path '*/.bun' \) -prune -o -type f \( -iname '*chat*' -o -iname '*session*' -o -iname '*transcript*' -o -iname '*context*' -o -iname '*handoff*' -o -iname '*record*' \) \( -iname '*.md' -o -iname '*.txt' -o -iname '*.jsonl' -o -iname '*.json' -o -iname '*.log' \) -printf '%TY-%Tm-%Td %TH:%TM  %s  %p\n' 2>/dev/null | sort -r | head -40; ls -lat /root | head -30
```

Path mila: `TODO — founder ka output chahiye` (abhi nahi mila).

Qaida: kachchi chat dump (transcript) repo mein **commit nahi** hoti (usmein secret ho sakte hain). Repo mein sirf yeh khulasa jata hai.

---

## 11. Rule 18 — is file ko kaise update karna hai

Har natije ke baad (server ka green/red output, founder ka screenshot ya faisla, naya finding, commit), usi turn mein:

1. **Section 1 (ABHI KA QADAM)** dobara likho — agla ek qadam kya hai.
2. **Section 8 (status)** badlo agar status badla (Rule 5: DONE sirf live verify par).
3. **Section 9** mein naya finding / faisla.
4. **Section 12 (log)** aur, agar naya server block diya gaya, **section 13 (aakhri commands)** mein ek line: tareekh, PKT waqt, kya hua.
5. Sirf docs ka commit (`handoff: …`), `main` par push. Force-push nahi.

Founder ne 17 Oct 2026 ko kaha: "her jo kaam hum kar rahe hain ya kiya hai woh repo mein update ho taake compact chat wala Claude context dekh sake." Is liye yeh standing order hai aur Rule 14 ke "push sirf 'repo update' par" wale jumle ko docs/records ke liye override karta hai. Server par asli badlav phir bhi Rule 15 ke tareeqe se (chat block) hota hai, repo us ki copy hai.

Chat compact hone se pehle (context bhar raha ho to) ek baar poori file taza karo.

---

## 12. Session log (naya upar)

- **23 Oct 02:36 PKT** — FOUNDER HAAN sab T-series (T1..T11) par; T8 latest technology (journald JSON, DSN). Blueprint docs/claude/T-SERIES-BLUEPRINT.md. Abhi kuch bana nahi. Agla: #5 event files (calendar tarteeb), web pull (871613d) founder ne chala diya + live dekha GREEN.

- **23 Oct 02:50 PKT** — FOUNDER: R5 jhoota 'gap' galti thi (R5 B4 GREEN hai; stale TECH-MAP lines theek). Technology audit: R3/R4/B8/R2/speed NOT BUILT -> NEXT-TASKS T-SERIES (T1 R4 -> T2 R3 -> T3 B8 -> T4 speed -> T5 R2) locked tarteeb ke baad. STANDING ROLE yaad: khud live dekho, galti/loophole mile to usi waqt theek karke green karo (aaj #4c mein 4 galtiyan khud theek ki, commit 871613d). Founder ko web pull baqi (871613d ke fixes): `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6` phir Chrome mein dobara live check. Phir #5 event files.

- **23 Oct 02:20 PKT** — #4c ICS subscribe GREEN LIVE (founder ke server commands + Chrome live saboot, DONE-DO-NOT-REPEAT mein detail). AGLA: #5 event par files.

- **23 Oct 02:05 PKT** — FOUNDER: (1) ZABAN RULE: hamesha Roman Urdu (AGENTS.md Rule 47). (2) compact ne yaad mita di thi: sab repo mein hai, yeh file + DONE-DO-NOT-REPEAT.md + NEXT-TASKS.md padho. HALAT: E72 (appeal 20,000 + evidence) GREEN server par. #4c ICS subscribe CODE READY aur push ho chuka (commit 0a52462): SQL E73 (proof ALL OK), Rust ics_core (64 tests) + ics_glue, installer module `ics`, Web Settings > Outside calendars + read-only events. SERVER PAR BAAQI (founder, alag alag, Rule 46): 1) SQL sql-run.sh 2) Rust installer 3) Rust restart+health 4) Web pull + Ctrl+Shift+R; phir Chrome mein asli ICS link daal kar check. AGLA: #5 event par files -> W3/W4/W5 -> founder account (command center) -> 6 identity live tests.

- **19 Oct 03:50 PKT** — Founder ke 'haan' par kaam shuru: Rust `manager` rank (G32) + nikale hue (revoked) member ko Rust ki 'user kis org ka' reads se bahar rakhne wala guard (G29: `membership_guard.py`, 5 tests, installer mein `GUARD=0` se band hone wala step); AI ki sirf ek pointer line sudhari (upar item 6). Test-account passwords chat mein dena theek, par repo/memory/script mein KABHI nahi store (script silent prompt leti hai). Agla: Business Pro login fix, G31, G30 migration worker, iMIP reply, Bun->Rust, Chat audit, Caddy/HTTP3 check.
- **19 Oct 04:10 PKT** — Business Pro login: `bizpro-login-fix.sh` + `E36_ensure_test_account.sql` (committed 1dbadd4): script server par password **chup-chaap poochti hai** (kahin store nahi), kharab account theek karti hai ya naya banati hai (`business_pro.test` + `bpro.test`, plan business_pro, seats >=5). G31 (seat limit + audit chain + work address) commit f882dfe: E34 SQL, Rust team_core/glue, Members + Join UI, screenshots 390/820/1366/1440. G30 shuru: founder faisla — app-password IMAP pehle, worker PRIMARY Rust, std-only IMAP + rustls/webpki-roots, likhna sirf walled garden mein (DB token), SHA-256 chain; password kabhi store nahi; napi nahi hui batein (30MB/50GB, throttle bypass, zero broken sessions) code/copy mein nahi.

- **18 Oct 03:57 PKT** — Personal package safai (`/plans` mix bug, Personal feature lists, dashboard/billing, "Pro+" naam), contacts import (parser + server + UI + Leads bar + Move to People), `calendar-invite-check.sh`, `brain-people-import-install.sh` (sandbox mein 3 raaste test: install / dobara / build-fail restore), manifest 75 entries. Tests 69 server + 26 frontend pass. L62–L67, G23–G25.
- **17 Oct 20:38 PKT** — Admin Center audit: tabs overlap, Audit/Export asli, Reports/Logs/Health phone fixes. **Security:** `/api/founder/*` founder-gate (index.ts), `org.ts` role+org scope, audit ledger scoped, phase64 SQL (asli PG16 par test), `brain-org-install.sh` (restore-on-fail), `org-authz-check.sh`. Ledger L53–L59, G21–G22, F7.
- **17 Oct 20:17 PKT** — CRM khaali book ka pehla qadam (3 tap-able raaste) — L52.
- **17 Oct 20:16 PKT** — Khaali Inbox ka asli welcome (address + copy/share + first email + /migration), filter-empty bug (L51). Harness `#inbox[?share=1]`.
- **17 Oct 20:14 PKT** — `server/checks-all.sh`: 6 read-only checks + repo==server (Rust main.rs sha, Brain routes live-only/differ) EK command mein, ek paste. Agla kaam in outputs par depend karta hai (G17/L32/L33 invites, G18 Rust, test accounts).
- **17 Oct 20:13 PKT** — Dashboard Quick actions: customer ko `/app/admin/*` (founder-only) par bhejna band; Business -> Org members, Basic/Pro -> Domains, Personal -> kuch nahi (L50). Org members mein invite UI abhi nahi => agla bada kaam: team invites (G17/L32/L33).
- **17 Oct 20:11 PKT** — Basic first-run: dashboard checklist/greeting/KPI fixes (L47–L49); Rust source repo mein mila (purani galti sudhari), founder procs 10/182 repo mein. Harness `#dashboard`.
- **17 Oct 20:03 PKT** — Plan-wise audit: plan-surface matrix; locked-page upsell card wrong-plan bug fixed (L44), Personal Safety copy (L45), 44px (L46). G20 opened.
- **17 Oct 19:58 PKT** — Calendar `.ics` import (parser + confirm/progress panel); header buttons 44px + aria-label. Ledger L43, G19 narrowed.
- **17 Oct 19:50 PKT** — /migration switch hub + 3D ConvergenceCanvas; LeadForm NEXATECT leak; get-started copy sach; founder-stack audit + 3 naye read-only scripts. Ledger L39–L42, G18, G19.
- **17 Oct 19:40 PKT** — Founder ki live tasveeron se: Install pill/scrollbar/People copy fix; P1 band (Business Pro 12h) + phase63 SQL (queue ab sach); `test-accounts-check.sh`; Rule 22 (founder Rust-only) + kaam ka style repo mein. Ledger L34–L38, F5/F5b. Agla: founder-stack audit, switch-journey assessment, 3D, Admin 9 pages + Chat.
- **17 Oct 18:59 PKT** — M6 part 3: Billing/Account/Admin-nav harness audit; relativeTime future bug; billing readability + dates + dead-end line; Account/Admin small fixes. Ledger L26–L30, G16. Agla: Admin 11 pages (sample data), Chat; founder ke check-script outputs.

- **17 Oct 18:55 PKT** — M6 part 2: CRM 9 pages harness audit; 3 orphan pages linked, Lost/Move-to, Relationships phone+scroll, text-clip fixes, 44px nav; server/routes/crm.ts tenant isolation fix (repo) + `crm-tenant-check.sh`. Ledger L20–L25, G14/G15. Agla: Billing/Account, Admin, Chat; founder ka check-script output.

- **17 Oct 18:44 PKT** — M6 (Calendar/People/Work) routes-harness audit: phone par detail panel kabhi nahi dikhta tha + Work ka Tasks board chhupa tha -> mobileVisible/back bar, agenda/month, phone tab switch, auto-fit grids. Ledger L15–L19, blueprint M6, manifest 27 file. Agla: CRM, Billing/Account, Admin, Chat audit; founder 13.11 output (facts v2) se 8i/8j.

- **17 Oct 18:34 PKT** — 13.10 ka natija (pull/expiry/Rust sab OK) + facts parhe; Rule 21 + ledger; M5a/M5b/table; facts v2; pull.sh server==repo saboot; 8u; TECH-MAP §10; blueprint 8t/8u/D1/D2. Agla: founder 13.11; phir facts v2 ke output se 8i/8j, G2 (M6 baqi), R0 scratch check.

- **17 Oct 06:31 PKT** — M5 audit: site harness (ENTRY=entry-site.tsx) + /auth stubs; auth login phone clip (AnexoMailField `w-0`) aur iPad header overflow (SiteNav md->lg) theek; M5a (plan list collapse, founder decide), M5b (hamburger 44px) likhe. Manifest 19 file. Agla: founder 13.10 command (facts -> pull -> expiry -> rust); phir 8i/8j facts ke baad, M6 baqi, R0.

- **17 Oct 07:05 PKT** — 8d/8e/8f/8r banaye (Domains), harness screenshot, manifest 17 file, blueprint statuses. Agla: 8i/8j ke liye server facts (13.7 baqi), M6 baqi sections, R0 server par scratch `cargo check`.

- **17 Oct 06:04 PKT** — Founder ne naya hukm diya (technology map + latest tech + plan-wise world-best experience + gaps ki tarteeb). Pehle likha: Rule 20 + TECH-MAP.md (banane mein).

- **17 Oct 05:55 PKT** — Screenshot review poora (harness, asli ComposeStudio, 390/820/1440). Domains phone gaps + Compose (44px, multi-recipient To, sticky Send bar) theek; Attach ka chupke se file chhodna pakda -> UI honest, blueprint 8p TODO. Manifest 17 file, blueprint M6 PARTIAL. Server par kuch lagaya nahi (READY).

- **17 Oct 05:40 PKT** — 8o: expiry-watch collector+timer+installer+selftest, Rust `founder.expiry.watch`, `rust-safe-deploy.sh` (3 raste sandbox mein test: build fail/ok/health fail), dashboard `ExpiryWatch` + harness screenshots (ok/warn/crit/unknown/stale/none/fail/non-founder; 1440/820/390), manifest 16 file. Command 13.10.

- **17 Oct 05:19 PKT** — Founder ne 13.9 chalaya: cert asli server par theek (1 Jan 2027), 993/587 live verify, timer, alert mail sent. 8n DONE. Naya hukm: 8o (dashboard tile + expiry watch), poora kaam screenshot se review, gaps hamesha ke liye theek.

- **17 Oct 05:09 PKT** — Cert monitor+timer+installer bana (`server/mail-cert/`), sandbox simulation (naya cert lagna, galat key reject, reload-fail restore, din mein ek alert, test alert) green; installer dry-run green; deploy-mail.sh mein comment. Command 13.9 founder ko.

- **17 Oct 05:06 PKT** — Founder ne 13.8 ka output bheja aur hukm diya: cert masla urgent, hamesha ke liye theek, alert founder ko. Root cause: deploy-mail.sh ne Caddy cert ek baar copy kiya (18 Sep), koi refresh nahi. Agent ne `mail-cert/` monitor+timer+installer likha (sandbox mein simulate), blueprint 8n.

- **17 Oct 05:00 PKT** — Founder ne pull (ced4a63: 14 file `same`, health 200, stamp 04:54) aur 13.7 ka output bheja. Mobile batch 1–3 server par. 13.7 se: ports/auth ka aadha sach mila, magar passdb/userdb, submission ka process aur mail store (Maildir/Postgres) abhi nahi dikha -> 8i/8j ruke; naya loophole: TLS cert 2 Nov ko expire (16 din) -> block 13.8.

- **17 Oct 04:54 PKT** — CEO section review doc + viral plan likha; Button/calendar touch targets; ax-hit positioned-element guard. Manifest 14 file.

- **17 Oct 04:53 PKT** — Mobile batch 2: main scroll safety net (M10), iPhone InstallHint (M7), compact setup checklist phone par; funnel static audit. Manifest 12 file.

- **17 Oct 04:50 PKT** — Rule 19 par pehla amal: phone/tablet audit (AppShell, mail, compose, global CSS) aur batch 1 (M1–M4) bana (3736efa), harness mein teen width par dekha, manifest 8 file, blueprint M1–M9. Server par deploy 13.0 se; founder ko phone se (ya Chrome DevTools phone mode) dekhna baqi — isliye READY.

- **17 Oct 04:50 PKT** — Founder ka hukm (04:43): mobile + tablet users ke liye bhi website (naya locked rule, AGENTS.md Rule 19), CEO ki nazar se har gap/loophole abhi theek karo, "viral kaise hoga" ki soch. Agent ne rule likha (AGENTS.md, cursor rule, UI standard, yeh file) aur mobile/tablet audit shuru kiya.

- **17 Oct 04:35 PKT** — Founder ke hukm (gaps sab se aage) ka pehla qadam: 8k dashboard setup checklist bana (`SetupChecklist.tsx`, app.index mount), harness mein 7 state + mobile dekhe, manifest sha badla. Status READY (founder ke browser mein dekhna baqi).

- **17 Oct 04:45 PKT** — Founder ka hukm (04:26): gaps sab se aage + latest technology, backend hamesha Rust (tRPC/QUIC/WebTransport/Tokio, Bun sirf emergency), aur har section (Dashboard, Mail, People, Calendar, Work, CRM, Domains) CEO ki nazar se. Agent ne yeh section 1 mein locked likha; sandbox mein cargo hai magar crates.io band (compile nahi ho sakta) — Rust code server par hi compile hoga.

- **17 Oct 04:35 PKT** — Founder ne 13.0 (824ab3a) ka asli output + 7 photo (step 2/3 asli backend par theek, Namecheap pehchana gaya, DKIM key aayi) bheje aur hukm diya: Google/Zoho se behtar, pehle Zoho ka basic. Agent ne Zoho/Google ke official pages parhe (WebFetch), `competitive-baseline-zoho-google-2026-10-17.md` likha, blueprint 8d–8m, aur 8g (IT wale ko instructions) + 8h (intezar mein inbox) banaye; sandbox mein dekhe. Server ki dirty tree = repo ke barabar (HEAD stale) — section 9.

- **17 Oct 04:20 PKT** — #8c (existing-mail guard) code + harness (Google Workspace scenario, desktop + 390 px) theek; pull.sh mein server-vs-repo diff stat; manifest sha badla. Founder ko 13.0 dobara.

- **17 Oct 04:05 PKT** — Founder ne 13.0 ka asli output paste kiya: green (b58694f, build OK, health 200, memory stamp barabar) + server ki dirty-tree list (section 1). Phir maqsad likha: real user ko best experience, test account ki had, "user ki tarah socho". Agent ne real-user lens se Domains par sab se bara khatra pakda: user ke domain par pehle se MX/SPF (Google/Microsoft) ho to hamara MX/SPF lagane se purani mail band ya SPF do ho jata hai — blueprint #8c (existing-mail guard) likha aur banaya.

- **17 Oct 03:55 PKT** — Founder ne wohi page-text dobara aur ek photo bheji (asli browser, step 2 theek). Do chats ek hi kaam par chal rahe the; 6ca2218 (subdomain fix) pehle push ho chuka tha. Agent ne harness mein subdomain scenario dekha (hint parent se, note, lamba Name) — theek. Section 1 ka "Agla" purana tha, naya likha. Founder ko 13.0 dobara aur step 3 ka check (DNS badle bina) diya.

- **17 Oct 03:48 PKT** — Founder ne Domains wizard qadam 2 ka page text paste kiya (asli browser): v2 live, qadam 1→2 sahi. Agent ne do kamiyan theek kin (subdomain par registrar-detect parent zone se; lamba Name "If DNS zone is axonetis.com"), harness mein dekha, manifest sha badla (blueprint 8c). 13.0 dobara chalana hai.

- **17 Oct 03:47 PKT** — Compact ke baad naya chat; founder (03:39): "context kabhi lose na ho, server par bhi update karo, hamesha pull command do, pm2 restart hamesha". Agent ne `docs/cursor-work/server/pull.sh` + `DEPLOY-MANIFEST.txt` likhe (dirty tree ke saath bhi chalta hai; memory/docs taza, code sha-guard, hamesha pm2 restart+save; nakli server par test: pehli bar, dobara, build-fail restore). Section 13.0 (EK command), section 15 (memory qaida: pehle likho phir kaam), AGENTS.md Rule 1 + Rule 18, cursor rule update. Asli server par abhi chala nahi.

- **17 Oct 03:35 PKT** — Founder ne 03:19 par kaha: Domains ki kamzoriyan theek karo, Vercel se aage UI banao tab hi dikhao, "cinematic" samjhao, axonetis sirf test domain hai, sab ek hi baar theek karo. Agent ne `app.domains.tsx` dobara likha (hero mail preview, outline "different domain", login address pehle, skeleton, stagger, registrar DoH detect, step 3 jashn), sandbox harness mein har state aur 390 px dekha, `cinematic-ui-standard.md` aur `ui-harness/README.md` likhe, blueprint #8a/#8b badla (READY). Deploy block 13.6. Browser dekhna baqi.

- **17 Oct 03:09 PKT** — Founder ke 2 photo: Domains page ka khali state theek (scroll, hero, locked addresses). Founder ne poochha "kya yeh duniya ka best UI hai?" — jawab: nahi, ~7/10; #8a (polish) aur #8b (registrar detect / ek-click DNS, founder decide) blueprint mein TODO. Wizard abhi dekha nahi.

- **17 Oct 03:03 PKT** — 13.1 (Domains page, sha `12fdbcdcb0d437e9`) founder ke server par green: build ok, pm2 restart + save, `/health` 200, `/app/domains` 200. Browser ka dekhna baqi; #8 READY.

- **17 Oct 03:03 PKT** — Founder ne Rule 1 ki pull command chalayi: git ne `cannot pull with rebase: You have unstaged changes` kehkar roka (kuch nahi badla). Founder ko 13.1 ka sha-guarded block dobara diya gaya. Khula kaam: server tree ki `git status --short` dekhna (live-only files, #10).

- **17 Oct 02:53 PKT** — Founder ne pull ki command maangi, kaha "pm2 restart hamesha karwaya karo", aur poochha "kya sab kaam latest technology par ho raha hai". Pull command section 13.4 mein; pm2 restart ka qaida section 4 mein. Jawab (chat mein): locked stack (React 19.2, TanStack Start, Vite 8.2, Tailwind 4.2, Bun, Rust primary) par; teen kamiyan: sandbox mein asli tsc/build nahi, live ticks polling se (WebTransport push E26 TODO), PWA cache purani UI dikhata hai.

- **17 Oct 02:49–03:35 PKT** — Founder ne claude.ai chat ka context paste kiya (Appendix A). File ka naam `SESSION-HANDOFF.md` se badal kar `CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md` kiya (git mv, ek hi file), upar founder ka rule likha ("pehle yeh padho, phir chat"), section 13 (aakhri commands) aur 14 (do chats ka rishta) jode. AGENTS.md top line + Rule 18, `.cursor/rules/founder-chat-context.mdc`, `docs/cursor-work/README.md` naye naam par.

- **17 Oct 02:37–03:10 PKT** — Founder ne Domains page ka screenshot bheja aur kaha "CEO ki nazar se dekho". Scroll bug + dashboard/Domains domain tazaad + sada empty state mila; `app.domains.tsx` dobara likha (section 1). Founder ko deploy block diya jata hai; browser dekhna baqi, isliye #8 abhi bhi READY.

- **17 Oct 02:29–02:50 PKT** — Founder ne compact-chat masla uthaya (context kho jata hai). Yeh `CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md`, AGENTS.md Rule 18, `.cursor/rules/session-handoff.mdc` aur `t16-accounts-look.sh` repo mein aaye. Blueprint U3 ko DONE kiya (founder screenshot). Founder ka server par chat-record path abhi nahi mila (section 10).
- **16 Oct 21:37 PKT** — Founder ka screenshot: pro.buyer ka rail aur naya Pro text theek; Domains rail mein hai. Agent ne pehla qadam diya: Domains kholo, screenshot bhejo. Founder ne D aur E ka proof maanga aur advanced UI/UX ki maang ki.
- **16 Oct ~20:00–21:30 PKT** — `#8` Domains installer server par chala (9 files, web build ok, `/health` 200, `/app/domains` 200); Rust domain flow green pro.buyer par (add → 5 records → verify → remove). Founder ne `anexomail-rust`, `anexomail-leo`, `anexomail-web` restart karaye (sab online). Test accounts basic/business/bpro bane (E28). #10 survey chali (live-only Brain libs ka natija section 9). Founder ne "repo ko chodo, accounts ek ek karke dekho" kaha.
- **16 Oct** — E30 live (Rust `dashboard.summary|analytics` aur Bun fallback dono sahi); U1/U2 DONE.
- **15 Oct** — E30 code (dashboard ki sachchai), pro.buyer ka UX review (U1–U7), `pro.buyer` account bana.
- **14 Oct** — AGENTS Rule 15 (server ka sach server par), Rule 16 (mail identities), Rule 17 (test ka tareeqa); E15–E28 ka bohot sa kaam (blueprint ke E-rows).
- Isse pehle ka sab: `docs/anexomail-blueprint.md` ("SESSION 18–21 SEP 2026" aur uske baad ke GREEN sections).

---

## 13. Aakhri commands (copy-paste ready, founder ke server ke liye)

**13.-2 — Brain security install (17 Oct, phase64 SQL PEHLE, phir Brain; dono restore/ON_ERROR_STOP wale):**
```bash
git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:sql/phase64_org_audit_ledger.sql > /tmp/phase64.sql && . /etc/anexomail/sync.env && psql "$WORKING_URL" -v ON_ERROR_STOP=1 -q -f /tmp/phase64.sql 2>&1 | grep -v NOTICE | tail -5; echo "SQL exit: ${PIPESTATUS[0]}"
bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-org-install.sh)
```
SQL: self-test andar hai (2 append + verify + edit-blocked, phir rollback) — fail ho to `phase64 FAILED:` likhta hai. Brain installer: pehle server par 51 tests, live `org.ts` repo ki purani version se alag ho to rukta hai (`FORCE=1`), `bun build` + `/health` fail => purani files wapas. Sandbox mein asli Postgres 16 ke liye: `su postgres -s /bin/bash -c "/usr/lib/postgresql/16/bin/initdb -D /tmp/pgtest16/data -A trust && /usr/lib/postgresql/16/bin/pg_ctl -D /tmp/pgtest16/data -o '-p 54329 -k /tmp/pgtest16' -w start"` (roles anon/authenticated/service_role khud banane hote hain).

**13.-3 — People import Brain install (18 Oct; pehle server par 18 tests live index.ts ki copy par, fail => kuch install nahi; build/health fail => purani files wapas):**
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-people-import-install.sh)
```
Aakhir mein teeno route bina login 401 dene chahiye (404 = mount nahi hua). Calendar-invite sawal ka jawab `checks-all.sh` (13.-1) ke aakhri hisse mein aata hai.

**13.-1 — EK command, SAB read-only checks (17 Oct 20:14 PKT; founder ek paste, agent ka agla kaam isi par):**
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/checks-all.sh)
```
Kya karta hai: (0) Rust `main.rs` live sha vs repo + Brain routes live-only/differ, pm2; (1) `rust-procs-check.sh`; (2) `test-accounts-check.sh`; (3) `workspace-api-check.sh`; (4) `switch-journey-check.sh`; (5) `crm-tenant-check.sh`. Kuch badalta nahi, secret print nahi. "PASTE FROM HERE" se "PASTE UP TO HERE" tak paste karein.

**13.0 — EK pull command (har jawab mein yahi do; founder ka hukm 17 Oct 03:39 PKT).** `git pull --rebase` server par refuse hota hai (tree dirty), isliye yeh script tree ko chhere bina: dirty files ki list dikhati hai, memory/docs taza karti hai, manifest ki code files sha-guard se lagati hai (build fail ho to purani wapas), phir **hamesha** `pm2 restart anexomail-web --update-env && pm2 save` aur health check. Script: `docs/cursor-work/server/pull.sh`, code list: `docs/cursor-work/server/DEPLOY-MANIFEST.txt`. Sirf web; Rust/Brain ke deploy alag block.

```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)
```
Aakhir mein `OK - memory taza, server taza` aaye aur `memory stamp:` wali line ka waqt is file ke "Aakhri update" se mile to server ki memory taza hai. Status: sandbox mein nakli server par test hua (dirty tree, dobara chalana, build fail par restore); **asli server par abhi chala nahi** (17 Oct 03:47 PKT).

Har naya block jo founder ko diya jaye woh yahan bhi likho (Rule 18). Neeche wale sab server par chalte hain, repo ya sandbox mein nahi.

**13.1 — Domains page deploy (commit `e4bf8a6`, 17 Oct 2026).** Sirf ek file (`src/routes/app.domains.tsx`), sha-guarded, backup `/root/i9/`, build fail ho to purani file wapas. Sha sirf is commit ki file ke liye hai; file badle to naya block do.

```bash
(
set -e -o pipefail
W=/opt/anexomail-web; F=src/routes/app.domains.tsx
mkdir -p /root/i9 && cd /root/i9
git -C $W fetch -q origin main
git -C $W show origin/main:$F > app.domains.new
[ "$(sha256sum app.domains.new | cut -c1-16)" = 12fdbcdcb0d437e9 ] || { echo "CHECKSUM MISMATCH - kuch nahi badla"; exit 9; }
cp $W/$F app.domains.bak
cp app.domains.new $W/$F
cd $W
if bun run build:bun > /root/i9/build.log 2>&1; then
  pm2 restart anexomail-web --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 4
  curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
  curl -s -o /dev/null -w "web /app/domains %{http_code}\n" --max-time 5 http://127.0.0.1:3000/app/domains
  echo "OK - ab browser mein Ctrl+Shift+R"
else
  tail -15 /root/i9/build.log
  cp /root/i9/app.domains.bak $W/$F
  bun run build:bun >/dev/null 2>&1
  echo "BUILD FAIL - purani file wapas rakh di"; exit 1
fi
)
```
Status (17 Oct 03:03 PKT, founder ka output): **chala, green** — `web /health 200`, `web /app/domains 200`, "OK". Build ke baad `pm2 restart anexomail-web --update-env` + `pm2 save` ho chuka. Backup `/root/i9/app.domains.bak`. Browser par dekhna baqi (isliye #8 READY).

**13.2 — Purani chat ka server par path dhoondna:** section 10 ka `find` command. Status: output abhi nahi aaya; path milte hi section 10 mein likho.

**13.3 — Chaar test accounts ek saath dekhna** (pm2 restart rust/leo/web, public pages, har plan ka rail/dashboard/send-from/domains/addresses/gate, #10 survey; password sirf server par):
```bash
git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/t16-accounts-look.sh | bash
```

**13.4 — Pull (AGENTS.md Rule 1, `--rebase` wala; founder ne 17 Oct 02:53 PKT ko maanga).** Server ki tree installers se badli hui ho sakti hai; us surat mein git `cannot pull with rebase: You have unstaged changes` kehkar **bina kuch badle** ruk jata hai (`&&` ki wajah se build/restart tak nahi pohanchta) — tab 13.1 jaisa sha-guarded single-file block chalao.
```bash
cd /opt/anexomail-web && git restore src/routeTree.gen.ts && git pull --rebase origin main && bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save && curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
```
Status (17 Oct 03:03 PKT, founder ka output): **refused** — `error: cannot pull with rebase: You have unstaged changes.` Kuch nahi badla (`&&` ne build/restart se pehle rok diya). Matlab server ki `/opt/anexomail-web` tree installers se dirty hai; poora pull tab tak nahi chalega jab tak `git status --short` ka output dekh kar tay na ho ke kaun si files live-only hain (#10 ka hissa). Tab tak sirf 13.1 jaisa sha-guarded single-file block.

**13.6 — (purana, ab zaroorat nahi: 13.0 isay shamil karta hai) Domains page v2 deploy (cinematic, 17 Oct 2026, sha `b49297b2f57ff586`).** Sirf `src/routes/app.domains.tsx`; sha-guarded; backup `/root/i9/`; build fail ho to purani file wapas; pm2 restart + save. (Commit push hone ke baad chalao: `git fetch` usi se file uthata hai.)

```bash
(
set -e -o pipefail
W=/opt/anexomail-web; F=src/routes/app.domains.tsx
mkdir -p /root/i9 && cd /root/i9
git -C $W fetch -q origin main
git -C $W show origin/main:$F > app.domains.v2.new
[ "$(sha256sum app.domains.v2.new | cut -c1-16)" = b49297b2f57ff586 ] || { echo "CHECKSUM MISMATCH - kuch nahi badla"; exit 9; }
cp $W/$F app.domains.v2.bak
cp app.domains.v2.new $W/$F
cd $W
if bun run build:bun > /root/i9/build.log 2>&1; then
  pm2 restart anexomail-web --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1; sleep 4
  curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
  curl -s -o /dev/null -w "web /app/domains %{http_code}\n" --max-time 5 http://127.0.0.1:3000/app/domains
  echo "OK - ab browser mein Ctrl+Shift+R"
else
  tail -15 /root/i9/build.log
  cp /root/i9/app.domains.v2.bak $W/$F
  bun run build:bun >/dev/null 2>&1
  pm2 restart anexomail-web --update-env >/dev/null 2>&1; pm2 save >/dev/null 2>&1
  echo "BUILD FAIL - purani file wapas rakh di"; exit 1
fi
)
```
Status: **founder ne abhi chalaya nahi** (17 Oct 03:47 PKT); 13.0 chalane par yeh file bhi lag jati hai (manifest). Natija aane par yahan likho.

**13.5 — DB ka chhota check (claude.ai chat se, 15–16 Oct; E30 ke baad theek nikla):**
```bash
. /etc/anexomail/sync.env && psql "$WORKING_URL" -c "select direction,count(*) from mail_messages group by 1"
```

---

## 15. Memory kabhi lose na ho — qaida (founder, 17 Oct 03:39 PKT)

Sach: Claude ki apni yaadasht ek chat se doosre chat mein nahi jati. **Yeh file hi memory hai.** Isliye:
1. **Pehle likho, phir kaam karo.** Founder naya hukm, faisla ya khabar de to agent kaam shuru karne SE PEHLE section 1/2 mein likh kar docs-only commit push kare (compact kisi bhi lamhe aa sakta hai).
2. **Har natije ke baad** section 1, 8, 9, 12, 13 (Rule 18). Lamba kaam chal raha ho to beech beech mein checkpoint.
3. **Compact / naya chat:** pehla kaam yeh poori file padhna, phir founder ko ek line: "abhi yahan hain: …" aur section 1 se seedha chalna.
4. **Server ki copy:** 13.0 har baar `/opt/anexomail-web/docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md` taza karta hai. Founder `memory stamp` se dekh sakta hai ke server wali copy repo ke barabar hai.
5. **Agent bhool jaye to?** Founder ek sawal poochh sakta hai: "section 1 ka stamp kab ka hai?" — purana ho to wohi nishani hai ke update chhoota. Phir agent pehle file update kare.

---

**13.7 — IMAP/SMTP fact-finding (sirf padhna, kuch badalta nahi; 17 Oct 2026, 8i/8j se pehle).** Maqsad: user ko phone/Outlook ke liye asli server/port/auth dikhane se pehle sach dekhna — ports ya auth main andaze se nahi likhta. Output mein password nahi aata (sirf paths/naam). Output paste karo, main 8i (settings page + app password) aur 8j (IMAP import) usi par banaunga.
```bash
echo "== listening mail ports"; ss -ltn | awk 'NR==1||/:(25|143|465|587|993|995|110)\s/'
echo "== dovecot"; doveconf -n 2>/dev/null | grep -E '^(protocols|auth_mechanisms|ssl_min_protocol|mail_location|disable_plaintext_auth)\b|^  *driver|^  *args' | sed -E 's#(password|pass)=[^ ]*#\1=***#g'
echo "== postfix submission/tls"; postconf -n 2>/dev/null | grep -E '^(smtpd_tls_security_level|smtpd_sasl_auth_enable|smtpd_sasl_type|smtpd_sasl_path|myhostname|smtpd_tls_cert_file) '; postconf -M 2>/dev/null | grep -E '^(submission|smtps)/'
echo "== import tools"; which imapsync doveadm 2>&1
echo "== tls cert host"; openssl s_client -connect 127.0.0.1:993 -servername mail.anexomail.com </dev/null 2>/dev/null | openssl x509 -noout -subject -enddate 2>&1
```
Phir (baad mein, jab 8i shuru ho): ek test mailbox se `openssl s_client -connect mail.anexomail.com:993` aur 587 par login, lekin password founder chat mein nahi, server par hi.

**13.8 — TLS cert renewal + mail store ka sach (sirf padhna; 17 Oct 2026).** Pehle cert (16 din), phir 8i/8j ke teen sawal. Output mein koi password nahi aata (redact lagaya hai).
```bash
echo "== cert file"; ls -l --time-style=long-iso /etc/anexomail/mail-cert.pem /etc/anexomail/mail-key.pem 2>&1 | sed 's#  *# #g'
echo "== cert dates / issuer"; openssl x509 -in /etc/anexomail/mail-cert.pem -noout -issuer -dates 2>&1
echo "== web cert (caddy) for comparison"; echo | openssl s_client -connect 127.0.0.1:443 -servername anexomail.com 2>/dev/null | openssl x509 -noout -issuer -dates 2>&1
echo "== who refreshes mail-cert"; grep -rIl "mail-cert" /etc/cron* /etc/letsencrypt /etc/systemd /etc/caddy /usr/local/bin /opt/anexomail* --include=* 2>/dev/null | head; systemctl list-timers 2>/dev/null | grep -iE 'certbot|acme|cert' 
echo "== who listens on submission ports"; ss -ltnp 2>/dev/null | awk '/:(587|465|993|143)\s/{print $4, $NF}' | sed 's/users:(("//; s/".*//'
echo "== master.cf submission"; grep -nE '^(submission|smtps)' /etc/postfix/master.cf 2>&1
echo "== dovecot auth (redacted)"; doveconf -n 2>/dev/null | grep -vE '^#' | sed -E 's#(password|pass|secret)=[^ ]*#\1=***#g' | head -70
echo "== users / store"; doveadm user '*' 2>&1 | wc -l; ls -ld /var/mail /var/vmail /home/vmail 2>&1 | head -3
echo "== IMAP + SMTP banners (no login)"; printf 'a1 CAPABILITY\r\na2 LOGOUT\r\n' | openssl s_client -quiet -connect 127.0.0.1:993 -servername mail.anexomail.com 2>/dev/null | head -3; printf 'EHLO t\r\nQUIT\r\n' | openssl s_client -starttls smtp -quiet -connect 127.0.0.1:587 2>/dev/null | head -12
```

**13.9 — MAIL TLS CERT FIX + ALERT (URGENT, founder ka hukm 17 Oct; ASLI SERVER PAR GREEN 17 Oct 05:19).** Ek command: monitor + systemd timer lagata hai, abhi ek baar sync chalata hai (Caddy ka taza cert ho to lag jata hai, postfix+dovecot reload, live 993/587 verify), aur founder inbox par test alert bhejta hai. Idempotent. Detail: `docs/cursor-work/server/mail-cert/README.md`.
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/mail-cert/install.sh)
```
Natija dekho: (1) "naya cert laga diya" + `993`/`587` ka notAfter naya, (2) `exit code: 0`, (3) founder inbox mein "[ANEXOMAIL] Test alert" aur "Mail TLS cert taza ho gaya". Agar "Caddy ke store mein ... cert nahi mila" ya cert naya nahi hua to output paste karo — tab Caddyfile ka `mail.anexomail.com` block dekhna padega (Caddy usi se renew karta hai). Bahar ke email par bhi alert: `echo 'ALERT_TO="aap@gmail.com"' > /etc/anexomail/alert.env`.

**13.10 — 8o: PULL + EXPIRY WATCH INSTALL + RUST BUILD (ek command; CHALA GAYA 17 Oct, output OK — upar 18:24 paragraph).** Teen cheezein tarteeb se, har ek apna restore-on-fail rakhti hai (ek fail ho to agli phir bhi chalti hai): (1) `pull.sh` (web: dashboard tile + Domains/ComposeStudio phone fixes + docs/memory; `pm2 restart anexomail-web`), (2) `expiry-watch/install.sh` (monitor + timer, abhi ek baar check, founder inbox mein pehla poora report email; Postfix/DNS/Caddy ko sirf padhta hai), (3) `rust-safe-deploy.sh` (Rust `main.rs` naya -> `cargo build --release` kuch minute; build fail => src wapas + error lines; health 200 na aaye => purani binary wapas; phir `pm2 restart anexomail-rust --update-env && pm2 save`; `polar-rust-payment` ko haath nahi lagta).
```bash
git -C /opt/anexomail-web fetch -q origin main && { bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/facts-tech-map.sh); bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh); bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/expiry-watch/install.sh); bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-safe-deploy.sh); }
```
**Naya (17 Oct 07:20): sab se pehle `facts-tech-map.sh` (sirf padhta hai, kuch nahi badalta, secret print nahi) — TECH-MAP ke LIVE dawe (versions, Cargo.lock, WebTransport UDP 3443, pm2), 8i/8j ke Dovecot/Postfix facts, aur MTA-STS/TLS-RPT/DMARC DNS.** Natija dekho: (0) facts ka output paste karo (Rust ka pehle wala haal, Dovecot passdb/userdb, mail store); (1) pull ke aakhir mein `OK - memory taza, server taza` + `/health 200`; (2) expiry install ki table (STATUS / KYA / DIN / DETAIL) — `mail-tls` ~76 din, web hosts, `domain:` ki taareekh, `dkim:` ok ya `unknown` (key table ka path alag ho to `/etc/anexomail/expiry-watch.env` mein `DKIM_KEYTABLE=`), aur "founder inbox mein Expiry watch email"; (3) Rust: `build OK`, `/rpc/health: 200`, `founder.expiry.watch (nakli token) ... HTTP 401 -> Rust ne proc pakda`. Phir browser mein founder login ke saath dashboard par **"EXPIRY WATCH — Mail TLS: N days"** tile (Ctrl+Shift+R). Agar `unknown` aaye (RDAP/DKIM/DNS) to output paste karo — wahi theek karunga. Build fail ho to `error` ke line paste karo.

**13.11 — PULL (web) + RUST 8u + FACTS v2 (ek command; READY, founder ne abhi nahi chalaya; 17 Oct 18:34).** `pull.sh` (web: plan cards "Show all N", /auth phone fix, iPad header, hamburger 44px, table sticky + docs/memory/ledger + **`pm2 restart anexomail-web --update-env && pm2 save` hamesha**; aakhir mein **server==repo saboot**), phir `rust-safe-deploy.sh` (sirf `wt_port` ek line; build fail => purani src/binary), phir `facts-tech-map.sh` v2 (read-only; Node/IMAP/mail queue/panic ginti). Natija: (1) `build : OK`, `web /health : 200`, `pm2 anexomail-web : online uptime=chhota`, **`server==repo: src same=N differ=0 missing=0`** (differ>0 ho to list paste karo), (2) Rust `build OK` + `/rpc/health` mein `"wt_port":3443`, (3) facts v2: pm2 `interp=` (Node kahan), `doveadm users`, mail store `files=`, `mail.log sent/deferred/bounced`, panic ginti.
```bash
git -C /opt/anexomail-web fetch -q origin main && { bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh); bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-safe-deploy.sh); bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/facts-tech-map.sh); }
```

## 14. Do chats ka rishta (context kahan se aata hai)

Founder do jagah Claude se kaam karta hai; dono ka context isi file mein jama hota hai:

1. **claude.ai ka Claude chat** — salah, CEO/user ki nazar se review, tarteeb ka mashwara. Wahan 15 Oct ko pro.buyer ke asli login ka review hua (U1–U7, blueprint "15 Oct 2026" section) aur mashwara diya gaya: pehle **#7 ka "Send from" check**, phir **#8 (domains)**, aur **U1 jald** (jhoote dashboard numbers har plan par). U1/U2 ab live DONE hain (16 Oct).
2. **Claude Code ka cloud session** (yeh repo, commits, server ke liye chat blocks). Yeh sandbox se `anexomail.com` ya founder ka server nahi dekh sakta; sab live sabut founder ke paste kiye output / screenshot se aata hai.

Jab founder purani chat ka text paste kare (jaise 17 Oct ko) to us ka kaam ka hissa yahan section 1/8/9/12 mein aata hai, aur khaas matn Appendix mein (sirf tab jab usmein secret na ho — paste karne se pehle parho).

---

## Appendix A — claude.ai chat ka paste kiya hua matn (founder ne 17 Oct 2026 ko paste kiya; secret nahi, parh liya gaya)

Yeh us chat ka pehla (CEO-review wala) hissa hai. Paste ka baqi hissa isi cloud session ke jawab the aur section 1–12 mein darj hain.

```text
“Command center” founder-side ka nahi hai. Yeh user Dashboard (/app) ka chhota heading hai, src/components/app/dashboard/Greeting.tsx mein. Founder wali cheezein (/app/founder, Admin, Speed) sirf founder host par dikhti hain, Pro ke rail mein nahi.

Ek user aur CEO ki nazar se: pehla taassur achha hai. Dark glass look saaf hai, rail mein sirf wohi cheezein hain jo is plan ko milti hain, aur mail bhejne ke kuch minute baad Mail mein dikhne lagi. Lekin pehli screen par kuch cheezein sach nahi hain. Paying buyer paanch minute mein bharosa kho sakta hai.

Yeh sab repo ke code aur schema se mile hain, abhi live server par check nahi hue:

Dashboard ke numbers galat hain. Ek mail gayi aur ek aayi, magar dashboard Received 0 / Sent 2 / Delivered 100% dikha raha hai. Code "inbound" dhoondta hai, jabke database mein in/out hota hai. Isliye har aane wali mail Sent mein ginti hai. Delivered hard-coded 100% hai, bounce hui mail bhi 100% ginti hai. Yeh fake success state hai.
Storage 30 GB dikha raha hai. Pro plan 10GB per mailbox, 5 mailbox deta hai. Dashboard plan nahi dekhta, ek flat default uthata hai.
Plan ki copy jhooti hai. Pro ke neeche likha hai “…and ANEXOChat”. Plan table mein ANEXOChat Business se shuru hota hai, aur Pro ke rail mein dikhta bhi nahi.
Business buyer ka pehla din. Pro 3 company address aur 5 mailbox ka wada karta hai, lekin rail mein domain ya address jodne ki koi screen nahi dikhti. Org sirf Business+ ko milta hai, aur Admin platform ka hai. Dashboard par setup checklist bhi nahi. Yeh #8 (domain wizard) hai. Pro ko bhi dikhna chahiye aur dashboard se link hona chahiye. Ek baat aur: dashboard “ANEXOMAIL hosted” dikha raha hai jabke is org ka domain probuyer.axonetis.com hai. Code ke hisaab se “Domain not verified” aana chahiye tha.
CRM Loop Pro par: 4 step dikhte hain, numbers 1, 2, 5, 9. Gaps toote hue lagte hain. Aap tay kero ke Pro ko kaun se steps milenge.
Chhoti cheezein: rail mein login address beech se toot jata hai (anexomail.c / om), aur ek hi address par “All addresses” aur “Unified inbox” dohrate hain.

Kuch theek nahi kiya. Rule 14 ke mutabiq sab pehle list mein likhe hain (U1 se U6, d321f46). Tarteeb aap tay karenge. Mera mashwara: #7 ka “Send from” check, phir #8, aur U1 jald (jhoote numbers sab plans par hain).

Do baatein live confirm karne ke liye, ek chhota command:

. /etc/anexomail/sync.env && psql "$WORKING_URL" -c "select direction,count(*) from mail_messages group by 1" -c "select slug,domain,domain_verified,storage_limit_bytes from organisations where slug like 'pro-buyer-test%'"

Output paste kero.
```

Is review ke har nukte ka anjaam: U1/U2 DONE (16 Oct live), U3 DONE (16 Oct browser), U4/U6 READY, U5/U7 founder ka faisla (section 9), #8 ab browser dekhne ke qareeb (section 1).
- **19 Oct 04:55 PKT** — G30 migration worker READY (commit 7f0d20a backend + frontend commit): E35 SQL, Rust mig_* modules (57 tests), `/app/admin/migrate` "Import mail" page. Page flows harness mein test (start, galat password, custom host, resume, stop dialog, receipts ok/broken/mismatch, off/err/no-mailbox, member vs owner). Harness fix: `stubs/query.ts` isLoading ab sirf pehli load par (asli TanStack jaisa). Naapa: 1 GB/20k mail ~6.5 MB peak (core), 20 MB mail ~105 MB peak. Khula: attachments copy nahi (live inbound bhi nahi), asli rustls build + live TLS server par pehli baar, port 993 outbound unverified, E35 live nahi chala, restart par copy ruk jati hai, OAuth baad mein. Install: E35 SQL -> `MODULES=mig` Rust installer -> web pull. Agla: G26 iMIP reply, Chat audit, Bun->Rust Business/Business Pro, Caddy read-only check script.
- **19 Oct 05:20 PKT** — Founder gussa (compact par context khona, 1 ghanta zaya). Do SQL fail: E34 (self-test mein live-mein-na-hone-wala role "viewer") aur E35 (`mail_threads.folder` enum `mail_folder`, text se compare) — dono usi file mein theek, local PG16 par pass (E34 28 checks, E35 54 checks), commit 5866900. Naya Rule 24 (AGENTS.md) + `founder/founder-commands.md`. Founder ne chat mein jo test password diya wo repo mein REDACTED. Server par abhi chalna baqi: E34, E35 SQL; phir `MODULES=mig` Rust; phir web pull.
- **19 Oct 05:54 PKT** — LIVE DONE: E35 SQL (COMMIT) + E36/Business Pro login (`business_pro.test` aur `bpro.test` LOGIN OK). Founder: dobara touch nahi. Rule 24: ek time par sirf 1–2 point — abhi: (1) E34 SQL live, (2) attachments (design sawal pehle). Detail: `founder/founder-commands.md`.
- **19 Oct 06:24 PKT** — LIVE DONE: E34 SQL (06:06), Rust cal+people+team+mig (06:16, build OK 1m43s, health 200, GUARD 2 reads, port 993 khula), Web pull db11a0b (06:16, /health 200). `mig-live-test.sh` ab bina password (service key se magic-link token; na chale to password prompt) — founder ko password prompt "stuck" lagta tha. Attachments = Option A locked (policy: `founder-commands.md` 06:16). Agla: live test output -> E37 attachments (org ke andar dedup, Storage Box path, quota) -> baqi queue tarteeb se.
- **19 Oct 06:27 PKT** — Import mail live test GREEN (asli imap.gmail.com se `auth_failed`, nakli login). Founder: queue ke codes (Attachments E37 -> Chat audit -> iMIP -> Bun->Rust -> Caddy check -> blueprint tarteeb) **SHAAM KO** likhne hain. Abhi koi naya code nahi. Detail `founder/founder-commands.md`.
- **19 Oct 06:29 PKT** — Founder ne `mig-live-test.sh` ka live output "bilkul accurate" confirm kiya; as-is `founder-commands.md` (06:29) + blueprint ke aakhir mein. Password founder ne khud type kiya (kahin save nahi). Import mail (G30) = LIVE DONE.
- **19 Oct 06:34 PKT** — Founder: technology-kahan table = LAW/Constitution/goal (AGENTS.md Rule 25, TECH-MAP section 0); goal = website + SQL likhna Bun se hata kar us technology (ya advance) par, ahista ahista. Version upgrades (tokio, axum 0.8, wtransport/quinn/rustls, rustc/edition 2024, Bun) = PRIORITY queue (TECH-MAP 0a) — shaam ko, sab se pehle.

**21 Oct 2026, 07:30 PKT — B4 READY (repo mein, server par chalna baqi; sandbox ASLI QUIC proof SAB PASS).** R5 event-driven live push, POORI website ke liye (har plan + family accounts: hub org-membership se chalta hai, plan se nahi). Files: `server/rust/events_core.rs` (std-only, 7 tests) + `events_glue.rs` (tokio tests) + `docs/cursor-work/server/events_patch.py` + `rust-events-install.sh` + `events-proof.py` (live: /internal/event 401/403/400/204, publish layer, UDP 3443, family_accounts har email ka org). Design: ek org = ek tokio broadcast hub; topics mail|calendar|crm|work|people|org; publishers = axum layer (har kamyab mutating /rpc/* POST) + `POST /internal/event` (EVENT_SECRET>=24, loopback only, proxy headers => 403) + ek reconcile task PER ACTIVE ORG (2 s, per-session poll nahi) jo bahar se aayi mail pakadta hai; EVENTS=off => purana 700 ms poll. Session: 25 s ping, 10 s write timeout, 5 min login re-check, max 64 listeners/org, 120 ms coalesce, legacy mode:'mail' client bhi chalta hai. Loophole band: reconcile baseline watch start par seed (pehle 2 s ke andar aayi mail miss hoti). `deliver_bin.rs` ab ingest ke baad best-effort hub ko batati hai (install: rust-deliver-install.sh dobara). Client: `src/lib/live-core.ts` (+5 tests) + `live.ts`; ek shared connection AppShell mein (`useLiveEvents`), reconnect backoff 1,2,4,8,16,30 s+jitter, visible hone par full resync; `useMailLive` ab usi par; mail/crm polling live hone par 60 s. Install order: Rust `rust-events-install.sh` -> Rust deliver `rust-deliver-install.sh` -> Web pull. Sandbox proof: `mail-sandbox-proof.py` section 8/9 (asli wtransport client `tests/events/wt_probe.rs`, 5 probes: owner/member/family/other-org/legacy). Dobara mat likho: events_core.rs, events_glue.rs, events_patch.py, live-core.ts, live.ts. Honest: mail topic ko reconcile milta hai; baqi topics ko publishers (Rust RPC + internal event); Bun-only routes ka data apne purane refetchInterval se aata hai jab tak B5/B8 unhe Rust par na laayen.

**21 Oct 2026, 06:50 PKT — GREEN-BOARD.** Founder ne kaha: docs + repo sab nikalo, compare karo kaun green, jo nahi woh alag folder. Bana: `docs/cursor-work/GREEN-BOARD/` (README ginti, 01-GREEN, 02 plan P1–P9 vs repo (68 items), 03 G1–G42, 04 technology+ops, 05 docs inventory (113 files), 06 repo inventory) + `GREEN-BOARD/NOT-GREEN/` (00-INDEX, 01 code-live-baqi, 02 todo, 03 partial, 04 founder, 05 stale-docs, 06 parked). Sach: MASTER-BUILD-PLAN ka STATUS BOARD purana (P2–P9 TODO likha, Basic par live hai). B4: events install FAIL hua (live main.rs router text alag) -> events_patch regex anchor push b18c4b9; deliver install OK; Web pull OK; baqi `rust-events-install.sh` dobara. A1/A2 ledger GREEN kiya. Dobara mat banao.

**21 Oct 2026, 06:50 PKT — B4 GREEN (server par chala, founder output).** `rust-events-install.sh`: events_core 7 tests, main.rs events judi, build OK, health 200, proof SAB PASS (UDP 3443 sun raha, /internal/event 401/403/400/204, publish layer 4xx not 5xx, FAMILY accounts 3/3 ka org hai). Deliver binary (hub push) 06:40 lag chuki, Web pull (live.ts/live-core.ts/AppShell/mail.ts/crm.ts) 06:35 lag chuka. Agla: B5 (G40, 19 Bun-only routes). Dobara mat likho.

**FOUNDER LOCK (21 Oct 06:49):** Migration technology ke jo bhi codes website par aate hain unki testing END par (sab B-batch ke baad); pehle technology POORI website ke liye secure ho — family accounts aur aane wale sab future accounts bhi (org-membership se, plan se nahi). GREEN-BOARD server par `pull.sh` se aata hai.

**21 Oct 06:55 — EK BLUEPRINT:** founder ne poocha 5 blueprint kyon; ab `docs/claude/FINAL-FOUNDER-BLUEPRINT.md` ek hi blueprint (identity, packages, tech, B-series, security, modules, rules, document map). Baqi files detail/history; security-blueprint founder-original (chhua nahi). Dobara alag blueprint mat banao.

**21 Oct 06:58:** ek blueprint ka naam/jagah founder ne tay ki: `docs/claude/FINAL-FOUNDER-BLUEPRINT.md` (folder `docs/claude/`). Status wahi update hoga.

**FOUNDER RULE (21 Oct 06:56, LOCKED): "file server par aa gayi aur wire hai = GREEN."** (Live Chrome click-test alag, baad mein.) GREEN-BOARD isi rule se dobara graded: live-dekha + server-par dono green; NOT-GREEN = jo server par aaya hi nahi (TODO/PARTIAL/FOUNDER). B5 = G40: founder pages ki 19 Bun-only calls (movein 5, release 7, revenue pipeline/lead 2, public status, ai chat, mail thread, outbox/send; mail.send B3 mein ho chuka) Rust `/rpc/*` par.

**21 Oct 07:09:** ops-ufw-passkey.sh founder output: ufw 3443/udp rule pehle se, passkey exempt marker live — dono GREEN. Agla: B5 code.

## 21 Oct 07:20 — B5 shuru. B4 GREEN. Ab: b5_core.rs/b5_glue.rs likhna (movein, release, revenue, status, outbox, thread, ai chat). Routes padh li: movein.ts (Supabase4 RPC movein_*), release.ts, revenue.ts. Memory: har step ke baad repo + /home/claude/sandbox-state update.

## STANDING ROLE (founder, 21 Oct 07:35): Main CEO-agent hoon. Mera kaam: advance-level code likhna; website ka mobile / tablet / laptop / computer user-experience aur frontend technology SAB dekhna; Lovable ya Cursor ne jo galat kiya ho use khud theek karna (fix) — founder se loophole list nahi maangni. Har batch mein: jo galti milti hai wahi fix + DONE-DO-NOT-REPEAT mein likhna.

## FOUNDER RULE 21 Oct 07:35 (STANDING) — CEO ka kaam
Mera (Claude) kaam as CEO: advance-level code likhna AUR website ka mobile / tablet / laptop / desktop user experience + frontend technology sab dekhna. Agar Lovable ya Cursor ne kuch GALAT kiya hai to usay mujhe khud theek/fix karna hai (founder ko loophole list nahi dena). Har batch ke saath frontend check (390/820/1440) + purani galtiyan fix; end-of-migration Chrome test mein bhi.
- 07:37 founder: frontend check HAMESHA, har batch mein, backend+frontend ka COMBO (B5 ke founder pages ka audit B6 ka intezar nahi karega — abhi).

**Aakhri update 22:05 (21 Oct 2026):** B6a (Polar control plane: muhar-band engine, billing.portal Rust b6, Bun fallback, Manage billing UI, Caddy lockdown script, installers) CODE LIKHA JA CHUKA, commit 0a32282, sandbox-proven, server par abhi nahi chala => GREEN nahi. Founder hukm: jo likh diya dobara mat likho, compact ke baad bhi. Install tarteeb: DONE-DO-NOT-REPEAT.md "B6a" section. Caddy kahin nahi jata; webhook/WAL ko haath nahi; checkout prewarm ke liye pehle founder ki ijazat.
**Aakhri update 23:55:** BootSplash (asli A logo, mobile) live-ready commit 17d9d32; /billing-policy; BILLING-PORTAL-BLUEPRINT.md likha (founder ki Hyper-Advanced list + CEO verdict: 421-SMTP grace nahi, ZKP => verifiable receipt, flat-price => what-if calculator, Polar PDF invoice legal). P1 caddy-billingportal.sh + portal/public placeholder. Founder ke 4 faisle baqi (discount, grace, auth, finance role). Sandbox mein ab bun install/tsc/vite build/Playwright mobile chalta hai.


## 22 Oct 2026 00:50 — B6a server progress (founder ka output dekha)
- Founder order: B6 poora GREEN pehle, phir portal/B7/B8. Discount kabhi nahi. Grace 3 din = countdown -> read-only + sending pause; inbound hamesha qabool; 421 nahi.
- GREEN: step 2 (polar-control-plane, muhar+kill switch+signed Polar probe) aur step 3 (Rust b6 billing.portal, nakli token 401). BAQI: step 4 brain-portal-install, step 5 caddy-polar-lockdown (plan->apply), step 6 asli Manage billing click.
- Loader: asli BrandMark A hero (generic silver 3D A hata diya, bc59368); WORKSPACE lockup Option 1/2 jawab baqi; favicon ek-source demo baqi.
- billingportal.anexomail.com Caddy par live (placeholder). Portal build B6 green ke BAAD.
- Yaad: pull.sh sirf manifest files; Rust sources git objects se; pkill -x; kabhi poori Caddyfile overwrite nahi.

## 22 Oct 2026 02:00 — SERVER PAR GREEN (founder ka output dekha)
- GREEN: Polar webhook fix (2 secrets, dono endpoints 200), Polar engine axum 0.8.9/edition 2024, engine non-root user 'polar' + .env 600 + pcp.key 640, Caddy lockdown, Brain portal route, Rust b6, billingportal placeholder, web pull (BrandLoader asli A har jagah, Command-center founder-only).
- B6a baqi: step 6 asli Manage billing click (Chrome, Pro login). Phir B6b/c (prewarm, tuning, alarms, Polar token scopes + reconcile check).
- Founder hukm: B6 poora green pehle; portal/B7/B8 uske baad; discount kabhi nahi; grace 3 din countdown->read-only+sending pause, inbound hamesha.

## 22 Oct 2026 02:45 — FOUNDER FAISLE (final)
- B6a GREEN/CLOSED (pending nahi). B6b/c DROPPED (zaroorat nahi). billing@anexomail.com UI se hata (portal banega). alikhan@anexomail.com = real-user test account, Claude login nahi karta.
- AGLA: B7 (calendar: iMIP reply G26 founder "haan" chahiye, recurrence G27, booking page, 2-way sync/CalDAV) -> B8 (Brain ~504 endpoints -> Rust) -> migration tests -> Basic + Pro package green -> billing portal P2-P8. Discount kabhi nahi; grace 3 din countdown->read-only+sending pause; inbound hamesha.

## 23 Oct 2026 02:50 — SESSION HISAAB (compaction se pehle)
- Rule 47: founder se SIRF Roman Urdu ("aap"). Commands har push ke saath per-technology inline (Rule 41/46).
- Calendar 11 mein se 8 GREEN (#0,#1,#2,#3,#4a,#4b,#4c,#9,#10). BAAQI 4: #5 event files (AGLA, shuru), #6 CalDAV, #7 Google (founder verification), #8 Rooms. World clock 2/6 green (W2 live check, W3, W4, W5 baaqi).
- Tarteeb: calendar #5->#8 + W3-W5 -> founder account -> 6 identity live tests + E72 appeal test (founder karta hai) -> M-series -> G16 billing portal. T-series T1-T11 founder "haan"; T12 (page auto-refresh, naya-version banner) naya, haan baaqi. T1 se pehle ek sawal: M-series se pehle ya baad.
- Aaj ka push: sirf docs (T12, ledger) — server/web par koi command zaroori nahi. Last code push: 871613d (#4c fixes), pull ho chuka.
- Founder ki ghalti-nishandahi: English jawab, commands na likhna, stale gap dohrana, Google holiday feed (Hindu observances) — dobara nahi.

- 23 Oct 03:10 — #5 event files CODE READY (E74 + Rust calfile + Web EventFiles). Calendar ab 8/11 green + #5 server run baaqi. Founder ne T-series sab "haan", T12 "haan"; tarteeb badli nahi.

- 23 Oct 03:20 — Founder ne E74/Rust/Web sab chala diye (sab OK). #5 GREEN LIVE. Calendar 9/11. Founder ka hukm: "audit karo, loophole khud fix, naya kaam mat lao, CEO + user mindset". Audit fixes: Greeting raat, Availability fake share link. Agla: W3, W4, W5.

## 23 Oct 2026 03:50 — SESSION HISAAB 2 (compaction se pehle; naya Claude PEHLE ye padhe)
- Rule 47 (sirf Roman Urdu "aap"), Rule 48 (founder ko sirf repo mein likhi tested commands; /opt/anexomail-web par kabhi merge/pull/checkout/reset — sirf fetch + `git show origin/main:<script>`), Rule 41/46 (har push ke saath per-technology commands), Rule 28 (manifest-sync + verify 0 bad pehle).
- GREEN LIVE: calendar #5 event files (E74 + Rust calfile + Web EventFiles; commit ac98d2d). Calendar 9/11. BAAQI: #6 CalDAV, #7 Google (founder verification), #8 Rooms. World clock 2/6 (W2 Focus Ring live check, W3 globe, W4, W5 baaqi).
- Audit fixes (0d022b5): raat 3 baje "Good morning" bug, Availability ka nakli share link hataya.
- Adaptive greeting (f63ef43, 1af6b62): raat 22:00-04:59, subah 05:00-11:59, dopahar 12:00-evening start, shaam evening start-21:59; evening start = sunset-60min (16:00..19:00, 5 min round, fallback 17:00); Settings ka time zone pehle, browser baad mein.
- Home city (0ce71d5): ~150 shehron ki offline list, "Detect my city" (geolocation sirf shehar save), Rust locale clean_home, web places.ts + HomePlace card.
- LIVE BUG pakda aur fix (60ded39, E75): Home city save "Could not save preference" — DB validator awam_ui_extra_ok ko `home` key nahi pata thi (meri chook, E61 wali dobara). SABAQ: pref.extra mein naya key = Rust clean_extra + DB awam_ui_extra_ok DONO, sandbox mein constraint ke saath test. Founder ko SIRF SQL command chalani hai: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)` (Rust/Web pehle live).
- FOUNDER KA STANDING HUKM (naya): test accounts real users se MIX na hon; real user/buyer workspace banaye to usay sab kuch naya, asli wiring, NO mock/demo data. Audit abhi BAAQI (code+SQL mein seed/demo/mock/founder-test special-casing grep karna).
- AGLA (is tarteeb se): founder SQL E75 chalaye -> Chrome re-test (Lahore, greeting, clock naam, phir test account se home city hatao) -> test-vs-real/no-mock audit + fix -> W3/W4/W5 -> #6 -> #7 -> #8 -> founder account -> identity tests (founder) -> M-series -> G16 -> T-series.
- Baaqi gaps: phone 390/820 check, guest-view event files live check, T12 implement, E55 grants-heal 30 Oct se pehle, Caddy cert renewal 12 Nov se pehle.

- 23 Oct 03:50 — Founder ne E75 chala di: sab OK (CHECK_E75 4/4, E65 sweep OK). Home city DB-side GREEN. AGLA: Chrome re-test (Lahore save, greeting, clock naam, phir home city hatao).

- 23 Oct 03:58 — HOME CITY GREEN LIVE (Chrome, Pro test account): Lahore save OK, reload ke baad persist, greeting 'Good night' (Karachi 03:5x), remove OK ('Home city removed'). Test account saaf. Chrome tab band. AGLA: test-vs-real/no-mock audit.

- 23 Oct 04:15 — AUDIT test-vs-real DONE (Rule 49 AGENTS.md mein): koi mock/demo data nahi; loophole = passkey chhoot naam-pattern par => E76 registry + Rust + Brain patch (code READY, server run BAAQI: SQL -> Rust -> Brain; founder-commands.md). Founder ne SQL E75 chala di thi (OK) aur home city live GREEN. AGLA: E76 server run, phir W3/W4/W5 -> #6 -> #7 -> #8.

- 23 Oct 04:30 — Home city card UI fix (overlap + alag design) code READY: SettingsScope 'after' prop, card ax-plane style. Web pull baaqi; phir Chrome screenshot se confirm. E76 (SQL->Rust->Brain) bhi baaqi. Founder hukm: CEO mindset, chat context har bade kaam par repo mein.

- 23 Oct 04:45 — E76 v2 advance (account class wall) READY, push ke baad founder SQL->Rust->Brain chalaye (founder-commands.md). Home city UI fix (ffc7464) Web pull baaqi.

- 23 Oct 04:55 — Founder ne E28 editor mein paste ki (\set error). E28/E36 psql-only; edit wapas; naya editor-ready tool sql/tools/create_test_account.sql (registry + mix-wall). Registry call bizpro-login-fix.sh + t7 script mein. Server run order wahi: SQL(E76) -> Rust -> Brain -> Web.

- 23 Oct 04:20 — Founder ne sab pull kar diya aur 'SQL green' bataya (E75, E76, Web). Calendar 9/11 GREEN (#5 live). AGLA: Chrome se Home city naya UI dekho, phir W3/W4/W5 -> #6 -> #7 -> #8.
- 23 Oct 04:25 — Home city UI fix live verify (Chrome) GREEN. Calendar 9/11, World clock 2/6. AGLA: W3 globe.

- 23 Oct 04:30 — CALENDAR GINTI SAHI: 10 GREEN / 13 hisse (#4a/#4b/#4c alag). Purani '11 mein se 8/9' ginti ghalat thi, mat dohrao. BAAQI 3: #6 CalDAV, #7 Google, #8 Rooms (+ World clock W3/W4/W5).

- 23 Oct 04:25 — Founder kehta hai Rust/Brain E76 chala diye (output paste nahi). Chrome se sirf itna dekha ja sakta hai ke Pro test account par passkey banner abhi bhi aata hai (asli-user behaviour theek); registry-exempt rasta sirf registered '*.test' account se dikhega. E76 SQL dobara dena safe (sha ledger: pehle se chali ho to skip, v2 ho to chale).

- 23 Oct 04:25 — Founder output: sql-run.sh 'koi nayi SQL nahi' => E75 + E76 v2 ledger mein pehle se chali hui (SQL DONE). CHECK_E76 ka output abhi nahi aaya (editor mein chalana baaqi).

- 23 Oct 04:35 — E76 GREEN likha (founder hukm). Chrome: asli-user passkey status theek. Baaqi sirf optional: CHECK_E76 7 rows output + registered .test account se live chhoot dekhna (founder jab login kare). AGLA: W3 globe.

- 23 Oct 04:35 — CHECK_E76 editor mein SUCCESS (founder). E76 SQL VERIFIED. AGLA: W3 globe.

- 23 Oct 04:40 — E76 SQL screenshot se VERIFIED (production). NEXT-TASKS.md ke upar naya RESUME HERE (04:40) block: green list, standing hukm, agli locked tarteeb (W3->W4->W5->W2 check->#6->#7->#8->Founder account->identity tests->M->G16->T).

- 23 Oct 04:43 — KHITAB: founder ko sirf 'Nauman bhai' bolo (poora naam nahi). Roman Urdu 'aap'.

## 23 Oct 2026 04:50 — SESSION KHULASA (compaction se pehle, Nauman bhai ka hukm)
- Khitab: sirf "Nauman bhai", Roman Urdu "aap". SQL SIRF server par (sql-run.sh, Rule 44); editor mein sirf CHECK_*. Commands per-technology, har push ke saath (Rule 41/46); sirf repo ki tested commands (Rule 48).
- GREEN aaj: #5 event files; adaptive greeting (Settings zone pehle); Home city (E75 + UI fix, live Chrome); E76 v2 account class wall (CHECK_E76 production screenshot true); Rule 49 (test vs asli kabhi mix nahi, mock data nahi) + audit; calendar 10/13 (#6 CalDAV, #7 Google [aap ki verification], #8 Rooms baaqi); World clock 2/6.
- Meri ghaltiyan aaj (dohrani nahi): git merge ff-only /opt (Rule 48); Home city SQL step "nahi" likha (E75 chahiye thi); E28 editor mein paste (psql file); calendar ginti 9/11 (sahi 10/13); card UI overlap (SettingsScope `after`).
- Calendar status server se: calendar-status.sh (founder-commands.md). Expected 10/13 DEPLOYED.
- AGLA (locked): W3 globe -> W4 -> W5 -> W2 Focus Ring check -> #6 -> #7 -> #8 -> Founder account -> identity tests (aap) -> M-series -> G16 -> T-series.
- Baaqi optional: registered *.test account se live passkey chhoot; Rust+Brain E76 ka output; phone 390/820; guest-view event files; E55 (30 Oct se pehle); Caddy cert (12 Nov se pehle).

- 23 Oct 04:55 — Server output se repo MATCH: calendar 10/13 DEPLOYED (server) == 10/13 GREEN (repo). calendar-status.sh ab web ka saboot src/ blob compare se deta hai (HEAD se nahi). Rust 200.

- 23 Oct 05:00 — SERVER==REPO PROVEN (founder output): calendar 10/13 DEPLOYED, web src same=541 differ=0 missing=0, Rust 200. AB KAAM: spec ke 3 chhote baaqi — collision warning at RSVP, LCP/INP measure, phone 390/820.

## 23 Oct 2026 05:45 — ABHI KYA KAAM HO RAHA HAI (compact se pehle, Nauman bhai ka hukm)
- Nauman bhai ne hukm diya: calendar spec ke 3 chhote baaqi KISI BHI TARAH poore karo: (1) collision warning RSVP par, (2) LCP 1.8s / INP 150ms naapna, (3) phone 390 + tablet 820 ka Chrome check.
- (1) COLLISION WARNING: CODE READY (E77 + Rust cal_glue + Web rsvp.tsx), sandbox/tsc/eslint green; server run BAAQI — commands founder-commands.md mein (SQL->Rust->restart->Web). Phir Chrome live check.
- (2) LCP/INP: Chrome se naapna baaqi (PerformanceObserver, public landing + app dashboard/calendar/settings). Nateeje DONE-DO-NOT-REPEAT + CALENDAR-ROADMAP mein likhne hain; khali claim nahi, sirf naapa hua.
- (3) PHONE/TABLET: HAMESHA har UI badlav ke baad 390 (phone), 820 (tablet), 1440 (laptop) — Rule 19/34. Package-wise: Basic/Pro/Business/Business Pro (UI universal, Rule 37, sirf capability ka farq). Chrome tareeqa: apna naya tab, window resize (founder ke tabs ko haath nahi); resize na ho to iframe/DevTools-device nahi — tab Nauman bhai ko batao. Chrome extension 05:30 par disconnected tha; reconnect ke baad karna.
- Standing: Roman Urdu, "Nauman bhai", SQL sirf server (Rule 44), Rule 48 (sirf repo ki commands), Rule 49 (test vs asli), calendar ginti 10/13, har bade kaam par repo + context update.
- AGLA (locked): spec ke 3 baaqi -> W3 globe -> W4 -> W5 -> #6 CalDAV -> #7 Google (founder verification) -> #8 Rooms -> Founder account -> identity tests (founder) -> M-series -> G16 -> T-series.

- 23 Oct 05:50 — Compact ke baad Nauman bhai ne kaha "repo read kero rules read kero". AGENTS.md (Rule 24/28/44/46/47/48/49), NEXT-TASKS RESUME HERE, founder-commands, yeh file dobara padhi. LCP NAAPA (live): landing 372-456 ms, /plans 520, /app 416-460 PASS; /app/calendar 2.7-2.8 s FAIL (session TTFB 1-1.7 s + rpc waterfall + duplicate locale.bundle/pref x3). Ab khud fix (CEO hukm: founder se mat poochho): duplicate locale calls dedupe, rpc parallel. Phir INP, phir 390/820/1440. E77 server run founder ka baaqi.
- 23 Oct 06:05 — INP naapa (asli clicks): handler 26-77 ms, script max 104 ms (<150 PASS); wall-time bade frames mein scripts=0 => automation artifact. LCP calendar fix 1 pushed 398c680. Chrome resize lagu nahi hua (window maximised) => 390/820 check Chrome se nahi ho saka; honest batana.

## 23 Oct 2026 05:58 — SESSION KHULASA #2 (Nauman bhai ka hukm: repo/sandbox mein likho ke kya kaam ho chuka, dobara nahi karna)
- HO CHUKA (repeat mat karo): E75, E76 v2, Home city UI, calendar 10/13 server==repo, E77 collision warning (code+sandbox+push 19c9a47), LCP/INP naapa, locale single-flight (398c680), docs 11af364.
- SERVER PAR BAAQI (founder): E77 = SQL -> Rust -> Rust restart+health -> Web; locale fix = Web. Poori commands founder-commands.md (E77 section) mein.
- BAAQI KAAM: calendar LCP dobara naapna (web pull ke baad) + session->rpc waterfall + Brain session latency; 390/820/1440 Chrome check (founder window chhoti kare ya screenshots); RSVP chip live check; phir W3 globe -> W4 -> W5 -> W2 -> #6 -> #7 -> #8 -> Founder account -> identity tests -> M -> G16 -> T-series.
- QAIDE: Roman Urdu "aap", sirf "Nauman bhai"; har push par poori technology-wise commands (Rule 41/46) jawab mein, file ka hawala nahi; Rule 48 sirf repo ki commands; SQL sirf server (Rule 44); manifest-sync <files> + verify 0 bad push se pehle (sync sirf wahi file re-hash karta hai jo naam se do).

- 23 Oct 06:15 — Founder ne E77 (SQL+Rust+restart+Web) chala diya: sab OK. E77 SERVER GREEN. Calendar LCP asal wajah auth/session 1-2 s (sessionResult serial hops) — locale dup fix live. AGLA calendar tarteeb: W3 globe -> W4 -> W5 -> W2 -> #6 -> #7 -> #8.
- 23 Oct 06:40 — W3 globe CODE READY (canvas-2D, lazy 23 KB gz, sandbox render sahi, 9 tests). Server: Web pull. Phir Chrome live check.
- 23 Oct 06:30 — W4 SHURU (founder hukm): F3b drift badge (Rust time.now + round-trip offset) -> F2 travelling opt-in (user-entered, quiet-hours shift, mail kabhi nahi rukti) -> F3 latency (opt-in, browser-measured RTT p50/p95, nextHopProtocol). Pehle repo/rules padhe, phir E78 SQL -> Rust -> Web. Compact ho to yahin se.

**23 Oct 2026, 07:30 PKT — W4 SERVER GREEN + LIVE (Chrome), TECHNOLOGY EK NAZAR MEIN (founder ne kaha: context repo mein rakho, frontend/backend technology map hamesha padho).**
TECHNOLOGY (asli sach: `docs/cursor-work/TECH-MAP.md` section 0d — kaam shuru karne se pehle HAMESHA padho): **Frontend** = React 19.2 + TanStack Start/Router/Query + Vite 8 + Tailwind 4 + Radix/shadcn; motion Framer Motion; landing scroll GSAP; 3D Three.js (r3f) sirf marked jagah; globe/clock ka canvas-2D (apna, library nahi); SSR host Bun (Nitro) sirf page render. **Backend** = Rust :3200 (Tokio, axum 0.8) PRIMARY — naya sab (RPC, files, attachments, inbound mail, calendar, people, team, locale/time); PostgreSQL (E-files `sql-run.sh`, RLS, atomic gates) = sach ka source; live push WebTransport/QUIC UDP 3443; attachments Hetzner Storage Box + clamd; mail transport Postfix/Dovecot/OpenDKIM; Bun sirf fallback + MIME/SMTP jodna (R1 tak) + passkey (G42 tak); Caddy (HTTP/3) sirf edge, kabhi nahi chhedna; Polar Rust :3400 NO-TOUCH. Web tests = `bun test`; Rust tests = `*_core.rs` standalone rustc.
W4: server output founder ne diya — SQL E78 + CHECK_E78 4/4, Rust install (time.now public {"ms"}) + health 200, Web differ=0 (553). Chrome live (Pro account, desktop): popover mein "Clock & connection" = "Device clock is in sync (± 94 ms), typical 190 ms · slowest 5% 198 ms"; Travelling: Tokyo trip save -> plane icon + Tokyo "trip" row (+4h sahi) + pink pin + dashed route + "In transit… lands 06:00 PM your time (10:00 PM there)… Reminder pop-ups wait until you land. Mail still arrives as usual."; reload ke baad bacha (server par save); Remove trip -> globe icon wapas. DO GHALTIYAN MILIN: (1) cd47cb5 mein `<TripCard>`/`<ClockHealth>` import the par render lines commit nahi (f7eeccc mein fix); (2) phone/tablet UX: zone ki 400 wali list hamesha khuli (cards neeche dhakeli), popover khulte hi input par focus (phone par keyboard), chhote buttons (Measure again 18x18, Add a trip/Face city 17 px) mein 44 px tap target nahi, 390 par popover screen ke kinare. FIX (agla push): list sirf type karne par, onOpenAutoFocus band, collisionPadding 8, ax-tap (coarse pointer par 44 px) 4 buttons par. Iframe sweep 390/820/1440: popover fit, page par horizontal scroll 0. QAIDA: push se pehle naye component ki `<Name` mount line grep karo.

**23 Oct 2026, 07:35 PKT — ABHI CURRENTLY KYA CHAL RAHA HAI (compact se pehle likha).** Commits pushed: cd47cb5 (W4), f7eeccc (cards render fix), 7312f6e (popover v2: X + drag + scroll), f055a28 (docs GREEN). **W3 globe + W4 + popover v2 = GREEN LIVE (Chrome 1440 + iframe 390/820; server SQL E78 + Rust + Web sab chale).** Baaqi sirf founder ke asli phone par: 44 px tap + touch-drag. **ABHI SHURU: W5** = (1) F4 billing deadline banner (asli subscription tareekh padhna, Polar ko haath NAHI), (2) F4b market open/closed chip default OFF (naya `market` key in awam_ui_pref.extra -> SQL E79 awam_ui_extra_ok + Rust clean_extra + web), (3) Lahore label-alias (Asia/Karachi ka naam), (4) l10n shehar-naam (Intl.DisplayNames, 4 zubanen). Plan file: docs/claude/WORLD-CLOCK-BLUEPRINT.md F4/F4b/W5. Qaida jo yaad rakho: naya `extra` key = Rust clean_extra + SQL awam_ui_extra_ok DONO (E61/E75/E78 sabak); component import != render (grep `<Name`); eslint --fix sirf apni files par (poori dir par nahi); manifest-sync mein files naam se; har push par Rule 46 ki poori commands founder ko. Uske baad: W2 Focus Ring live check -> #6 CalDAV -> #7 Google (founder ki verification) -> #8 Rooms -> Founder account -> identity tests -> M-series -> G16 -> T1..T12. Calendar LCP (/api/auth/session 1-2 s) T3/T4 mein.

**23 Oct 2026, 07:50 PKT — CHECKPOINT (compact se pehle).** SERVER PAR CHALA HUA + LIVE GREEN (dobara code NAHI likhna): W3 globe, W4 (clock badge, connection, Travelling; E78), popover v2 (X, drag, scroll), W5 (market chip default OFF + E79 + Rust clean_market; billing deadline card code server par, card tab dikhta hai jab asli renews_at ho — founder ke Pro account mein nahi, isliye chhupa). Latest pushed commit 1a1fb2a (web server==repo 558). **ABHI CHAL RAHA HAI: W2 Focus Ring ka Chrome live check (Find a time > New meeting).** Kaam code ka nahi, sirf dekhna. Baaqi (founder ke phone par): 44 px tap + touch-drag; billing card asli renews_at wale account par; Lahore label (Settings home=Lahore); W5b shehar-naam l10n (zubanon ka bundle). Phir: #6 CalDAV -> #7 Google (founder ki verification) -> #8 Rooms -> Founder account -> identity tests -> M-series -> G16 -> T1..T12. Qaida: SQL editor mein naya KHALI tab (purana text chhoot jaye to :'org' error aata hai); editor mein E28/E36 kabhi nahi (psql variable).

**23 Oct 2026, 07:55 PKT — FOUNDER NE #6 CalDAV PAR "HAAN" DIYA ("ceo tum ho toh haan hai meri").** Ab SHURU: #6 CalDAV (design -> E80 SQL app-password + ctag -> Rust caldav_core/glue -> tests -> Caddy surgical add commands). Caddy ka kaam bhi "haan" mein shamil (read-only check, backup, caddy validate, reload; HTTP/3 band nahi hona chahiye). Design file: docs/claude/CALDAV-BLUEPRINT.md (banane wali hai). Agar compact ho jaye: pehle us file + NEXT-TASKS padho. W2 Focus Ring GREEN (c99f951). Calendar baaqi: #6 (chal raha), #7 Google (founder ki verification), #8 Rooms.

**23 Oct 2026, 08:50 PKT — CalDAV #6 PROGRESS (compact se pehle).** Design file likhi: docs/claude/CALDAV-BLUEPRINT.md (C1 = sirf padhna, C2 = likhna; /dav/* + /.well-known/caldav usi host par; app password Basic auth; Caddy surgical). **E80 SQL BANA + sandbox GREEN** (2 clean runs, CHECK_E80 5/5, proof ALL OK, lint 0; server par CHALA NAHI). Agla: dav_core.rs (pure, tests) -> dav_glue.rs + installer module `dav` (route_add /dav, /dav/{*rest}) + RPC procs caldav.apppw.create|list|revoke + Settings UI + caddy-caldav.sh + founder-commands. Server par abhi kuch nahi chalana (SQL/Rust sab ek saath tab dunga jab code poora ho).

### Checkpoint 23 Oct 08:30 PKT — CalDAV C1 poora code repo mein
Bana: E80 SQL, dav_core.rs, dav_glue.rs, installer module `dav`, caddy-caldav.sh, Settings "Phone calendar" UI. Server par KUCH NAHI gaya. Agla: founder founder-commands.md ka "CalDAV #6 C1" section chalaye (SQL -> pepper -> Rust -> restart -> Caddy plan/apply -> Web), phir live curl PROPFIND + phone test. Phir C2 (likhna, If-Match, sync-collection) ya #7 Google.

### Checkpoint 23 Oct 08:15 PKT — POORI HALAT (compact ke baad yahin se shuru karna)
**Qaide (har baar):** Nauman bhai, Roman Urdu "aap"; kaam se pehle repo + rules (AGENTS.md, TECH-MAP, NEXT-TASKS, DONE-DO-NOT-REPEAT, founder-commands) padho; jo DONE hai dobara nahi likhna; live Chrome check khud; UI 390/820/1440; har push par per-technology commands (Rule 46: SQL -> Rust -> restart+health -> Caddy -> Web); manifest-sync sirf apni files ke naam se, phir verify 0 bad; eslint --fix sirf apni files par.
**Technology:** Frontend React 19.2 + TanStack Start/Router/Query + Vite 8 + Tailwind 4 + Radix/shadcn (Bun sirf SSR host). Backend: Rust :3200 (axum 0.8, primary), PostgreSQL E-files (sql-run.sh, RLS), WebTransport UDP 3443, Caddy HTTP/3 (kabhi na todna), Polar :3400 NO-TOUCH, Postfix/Dovecot mail.
**Locked order:** W0-W5 + W2 live GREEN -> #6 CalDAV (ABHI) -> #7 Google (founder ki Google Cloud verification chahiye) -> #8 Rooms -> Founder account -> identity live tests -> M-series -> G16 billing portal -> T1-T12.
**CalDAV C1 — repo mein (commit c357a84), SERVER PAR NAHI GAYA:**
- docs/claude/CALDAV-BLUEPRINT.md (design; NOTE: app password 30 akshar = 150 bit, blueprint mein "100 bit" likha hai — ghalat, sudharna hai)
- sql/E80_caldav_foundation.sql + CHECK_E80 + proofs/E80_proof.sql (sandbox GREEN)
- server/rust/dav_core.rs (pure, 14 tests) + dav_glue.rs (axum `handle` /dav, procs caldav.apppw.create|list|revoke; compile server par hoga)
- rust-engine-install.sh: module `dav` (need cal_core; routes /dav, /dav/, /dav/{*rest})
- docs/cursor-work/server/caddy-caldav.sh (plan default, MODE=apply, rollback)
- Web: src/lib/caldav.ts(+test), components/app/calendar/PhoneCalendar.tsx, CalSettings mein mount
- Env: CALDAV_PEPPER in /opt/anexomail-rust/.env (founder-commands step 2)
**Founder ko dene wali commands:** founder-commands.md ka section "CalDAV #6 C1" (6 step). Founder ne abhi KUCH nahi chalaya.
**Agla:** founder ke outputs -> curl PROPFIND live check -> phone test -> GREEN likhna. Phir C2 (PUT/DELETE, If-Match, sync-collection, recurring exceptions). Dhyan: dav_glue build fail ho to errors paste hongi, wahi fix.
**Baaki chhote:** W5b city-name l10n, billing card real renews_at par check, Lahore label, phone par 44px tap/drag check, calendar LCP (T3/T4), E55 grants-heal 30 Oct se pehle, Caddy cert renewal 12 Nov se pehle.

### Checkpoint 23 Oct 08:25 PKT — CalDAV C1 SERVER PAR LIVE (aadha GREEN)
**Founder ne chalaya aur dekha:** SQL E80 GREEN (CHECK_E80 5/5, CHECK_E65 6/6) | pepper laga (.env CALDAV_PEPPER) | Rust `dav` module: server par 14 tests pass, build OK 2m33s, health 200, pm2 sab online | Web pull: /health 200, PhoneCalendar server par (src same=561) | Caddy apply OK (backup /etc/caddy/Caddyfile.bak.caldav-20261023-032058): anexomail.com 200, /.well-known/caldav 301 -> /dav/, PROPFIND bina login 401 + `dav: 1, calendar-access` + WWW-Authenticate.
**Masla mila + fix:** OPTIONS /dav/ par DAV header nahi — Rust ka CORS layer OPTIONS ko hamare handler se PEHLE 200 de deta hai (seedha :3200 par bhi yehi). Fix commit 797b9eb: caddy-caldav.sh ab `handle @caldav` mein `header DAV` + `header Allow` lagata hai (purana laga block bhi UPGRADE). **Founder ko dena baaki:** `caddy-caldav.sh` plan phir `MODE=apply` (repo command founder-commands.md mein CalDAV section, step 5). Rust ko NAHI chhedna (Rule 35).
**Agla (is tarteeb se):** (1) Caddy re-apply -> OPTIONS mein `dav:` dikhe; (2) `caldav-check.sh` dobara; (3) founder Settings -> Phone calendar -> Create password; (4) mera live Chrome check (UI 390/820/1440) + founder ka phone test (iPhone/DAVx5) — tab GREEN; (5) phir C2 ya #7 Google.
**Sabaq:** Caddy script pehle validate error chhupati thi (temp path se validate fail) — ab asli folder mein validate + baseline; naya check script caldav-check.sh (read-only).
**Commits:** c357a84 (C1), ebb2af2 (caddy validate), 307cef1 (check script), 797b9eb (DAV header fix).

### Checkpoint 23 Oct 08:30 PKT — CalDAV server taraf GREEN
Caddy re-apply founder ne chalaya (backup /etc/caddy/Caddyfile.bak.caldav-20261023-032333): `OPTIONS /dav/ => dav: 1, calendar-access`, well-known 301, PROPFIND bina login 401, anexomail.com 200. SQL + Rust + Caddy + Web sab server par. **Baaki sirf asli use:** founder Settings -> Phone calendar -> Create password (password sirf ek baar dikhta hai; chat mein NA bheje) -> phone par CalDAV account (server anexomail.com, username email) -> events dikhein? Phir GREEN. Password mera kaam nahi (main password type nahi karta). C2 aur #7 Google uske baad.

### Checkpoint 23 Oct 08:50 PKT — POORI HALAT (compact ke baad SIRF yeh section padho, phir kaam)
**HO CHUKA (server par LIVE, dobara mat banana):** W0–W5 + W2 Focus Ring GREEN. CalDAV C1 SERVER PAR: SQL E80 GREEN (CHECK 5/5), pepper .env, Rust `dav` module (build OK, health 200), Caddy apply + DAV header upgrade (OPTIONS dav: 1, calendar-access; well-known 301; PROPFIND bina login 401), Web pull (PhoneCalendar UI server par).
**REPO MEIN PUSH, founder ne PULL NAHI KIYA (Web, sirf `pull.sh`):** (1) 39e89a7 Classic calendar rows wrap + Panel overflow-x-hidden; (2) 3a58fed mail thread crash hardening (`normalizeThread` + retry 401/5xx/network) — founder ka "mail kholne par Something went wrong, refresh par khulta hai" ka ASLI error abhi nahi mila (is Pro account par 5/5 threads theek, console saaf); (3) 17a9a19 Calendar PHONE toolbar redesign (≤640px: "⋯" menu, 44px targets, full-width Month/Week/Day). Commands: founder-commands.md ke 23 Oct sections (08:40, 08:55, 09:00).
**AB KA KAAM (is tarteeb se):** (a) founder Web pull chalaye -> phone screenshot (calendar + mail + People, 390 aur 820) -> mera live check, masla ho to usi turn fix; (b) mail "Something went wrong": agar pull ke baad bhi aaye to founder se screenshot + mail ka subject + account chahiye (guess nahi); (c) CalDAV: founder Settings -> Phone calendar -> Create password -> phone par CalDAV account (server anexomail.com, username email) -> events dikhein to C1 GREEN likhna; (d) phir C2 (PUT/DELETE, If-Match, sync-collection) ya #7 Google (founder ki Google Cloud verification chahiye) -> #8 Rooms.
**Founder ki nayi mobile/tablet taleem (23 Oct 08:42):** phone 390 px par content ~342–358, touch ≥44px, input 16px, koi horizontal scroll nahi, 100dvh, safe-area, EK column; tablet 820 par content ~772–788, do-column (rail + content), touch ≥44, text 14–16px; "mobile stretched" nahi, app jaisa. Laptop 1200–1440. Har screen pehle 60 second mein apna kaam dikhaye. Pinch-zoom allowed hai (viewport mein maximum-scale nahi) — alag zoom button nahi banaya; "text size/density" option founder maange to alag kaam.
**Sabaq:** (1) screenshot dekhne se pehle masla andaza nahi — phone ka bada font rows ko chauda kar deta hai (nowrap rows); (2) push reject ho (kisi aur session ne docs push ki) to `git pull --rebase` sirf apne UNPUSHED commits par, phir manifest dobara sync (doosre ki badli file bhi) ; (3) caddy script validate asli folder mein.
**Baaki chhote:** W5b city-name l10n, billing card real renews_at par check, Lahore label, calendar LCP (T3/T4), E55 grants-heal 30 Oct se pehle, Caddy cert renewal 12 Nov se pehle, blueprint mein app password "100 bit" ghalat (150 bit).

### Checkpoint 23 Oct 08:55 PKT — phone calendar toolbar GREEN (screenshot), panel-width fix push
Founder ne Web pull chalaya (src same=562) aur screenshot bheja: naya phone toolbar theek (⋯ menu, Meeting, nav 44px, Month/Week/Day poori chaudai). **Nayi galti mili + fix:** panel sirf ~70% chaudai par (dayin khali patta) — `overflow-x-hidden` ke baad ListPanel (non-wide) ko `w-full` nahi tha. Fix e04f078: Panel.tsx mein base `w-full`. **Founder ko dena baaki:** Web pull dobara (founder-commands.md 09:05 section) -> calendar + Mail screenshot. Mail "Something went wrong" ka asli error ABHI BHI nahi mila (hardening 3a58fed pull ho chuki); aaye to screenshot + subject + account.
**Agla:** founder ka naya screenshot dekh kar calendar GREEN; phir Mail/People phone par (390/820) wohi tehkeek; CalDAV phone test (Settings -> Phone calendar -> password); phir C2 / Google / Rooms.

### Checkpoint 23 Oct 09:15 PKT — mobile kaam ki poori halat (compact se pehle)
**Push ho chuka, founder ka Web pull BAAKI (ek hi command, pull.sh):** e04f078 ListPanel w-full; 8cc9ae1 PullRefresh (data-only, reload nahi); 1d45f3c Text size (Settings->Appearance 90/100/115/130/150%, lib/text-size.ts, html[data-ax-ts] css; px-literal text bhi scale), touch scrollbar css, pull-refresh pinch guard, docs/cursor-work/MOBILE-CONTRACT.md (mobile ke qaide + check list). Founder ke screenshot se GREEN: phone calendar toolbar (⋯ menu, 44px, full-width Month/Week/Day) aur panel poori chaudai.
**Faisle (CEO):** CSS `zoom` poore app par KABHI nahi (live test: popover khisak jata hai). Pinch-zoom native hamesha. **Founder ka 23 Oct 09:07 hukm: "zoom in/out jahan zaroorat hai wahan karo, jahan nahi wahan nahi"** => global Text size Settings mein rahe, par in-context zoom SIRF wahan jahan content dense/lamba hai: (1) Mail padhne ki body (A−/A+), (2) Calendar Week/Day time grid (ghante ki unchai +/−). Dashboard/lists/settings/forms par koi zoom control nahi.
**Mail "Something went wrong"**: asli error ab bhi nahi mila (hardening 3a58fed pull ho chuka). Aaye to screenshot + subject + account.
**CalDAV:** server par sab LIVE; baaki sirf founder ka phone test (Settings -> Phone calendar -> password).
**Agla:** founder Web pull -> phone screenshots; in-context zoom (mail body + calendar grid); phir CalDAV phone test GREEN; C2 / Google / Rooms.

### Checkpoint 23 Oct 09:30 PKT — in-context zoom BANA (push, founder pull baaki)
Founder ka hukm "zoom jahan zaroorat wahan" amal mein: mail body A−/A+ (READ_ZOOM 85–175%) + calendar Week/Day ghante ki unchai (GRID_HOUR 36/52/72/96) — `lib/zoom-prefs.ts`, `components/app/ZoomButtons.tsx`, SafeMailBody (iframe body zoom), TimeGrid (HOUR ab state), mail thread header. Qaida MOBILE-CONTRACT.md 5b. Web pull baaki: e04f078..is commit tak sab ek hi pull.sh se. Phir founder ke phone screenshots (calendar Week, mail thread, Settings->Appearance Text size).

### Checkpoint 23 Oct 10:00 PKT — pull-to-refresh asli reload (push, founder pull baaki)
Founder: "spin hota hai lekin refresh nahi hota". Fix: draft na ho to 300ms baad `location.reload()`; draft ho (textarea/contenteditable/dialog input mein text) to `refetchQueries + router.invalidate`. Tests 379 pass, tsc 0. Agla: founder Web pull -> pull test + phone screenshots (calendar Week, mail thread, Appearance Text size); phir CalDAV phone test, C2/Google/Rooms.

### Checkpoint 23 Oct 10:15 PKT — globe scroll fix (push, pull baaki)
Founder screenshot: World clocks popover, scroll upar nahi aata. Wajah GlobeView touch-none. Fix touch-pan-y. Agla: pull + pull-to-refresh/zoom screenshots, CalDAV phone test.

### Checkpoint 23 Oct 10:30 PKT — Settings slow fix (push, pull baaki)
Founder: settings center slow. Wajah mili: SettingsBits har row par useSettingHistory bina enabled => N+1. Fix enabled=open==="history". Agar ab bhi slow ho to DevTools Network (settings.list time) + server rust log dekhna.

### Checkpoint 23 Oct 10:45 PKT — touch scroll handle (push, pull baaki)
Founder: scroll bar stuck / pakad kar chalna chahiye (mobile+tablet). Bana: draggable handle right edge, scroller auto-pick (most overflow). Phone par test baaki; "stuck" ka asli sabab device par dekhna: agar Appearance par ab bhi atke to screenshot + kaun si jagah ungli thi.

### CONSOLIDATED STATE — 23 Oct 2026 09:50 PKT (compaction ke baad yahin se shuru karo)
**Founder:** Nauman bhai (solo, ANEXOMAIL, Asia/Karachi), Roman Urdu. Main CEO-agent hoon: pehle repo/rules/tech padho, kaam se pehle aur saath-saath yeh file + founder-commands.md + DONE-DO-NOT-REPEAT (dono copy) + manifest (sync -> verify 0 bad) update, har push ke saath poori deploy command. DONE kaam dobara nahi.
**Work order:** W0–W5+W2 done -> #6 CalDAV (C1 server live, phone test baaki) -> #7 Google (founder ki Google Cloud verification) -> #8 Rooms -> Founder account -> identity live tests -> M-series -> G16 billing portal -> T1–T12.
**Aaj (23 Oct) push hua, founder PULL baaki (sab ek hi pull.sh se):**
- e04f078 panel width fix; text size (Settings->Appearance) + touch scrollbar CSS; in-context zoom (mail body A−/A+, calendar hour height)
- c23f66b pull-to-refresh ASLI reload (draft ho to sirf refetch)
- dd4f841 World clocks globe touch-pan-y (scroll atakta tha)
- 5a67d85 Settings slow: per-row history N+1 hata (enabled only when open)
- dffe77d draggable TouchScrollbar (lib/touch-scroll.ts, components/app/TouchScrollbar.tsx)
**Founder ke phone par abhi verify hona baaki:** pull-to-refresh reload, Text size, scroll handle, Appearance 90% "stuck" (sabab code mein nahi mila — screenshot + ungli ki jagah chahiye), calendar Week, mail thread, panel width.
**Deploy commands:** Web `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6` (phir Ctrl+Shift+R); SQL `sql-run.sh`; Rust `rust-engine-install.sh` + `pm2 restart anexomail-rust --update-env && pm2 save`; Caddy `caddy-caldav.sh` (plan, phir MODE=apply).
**CalDAV C1:** read-only, live (SQL E80, Rust dav, Caddy). Founder test: Settings -> Phone calendar -> Create password, phone mein CalDAV account server anexomail.com. Phir C2 (PUT/DELETE, If-Match 412, sync-collection).
**Mail "Something went wrong":** reproduce nahi hua; hardening 3a58fed. Dobara aaye to screenshot + subject + account.
**Mobile qaida:** MOBILE-CONTRACT.md (390/820/1200–1440, touch>=44, input 16px, no h-scroll, 100dvh, safe-area). Poori app CSS `zoom` NAHI (popover toot'te hain); pinch native; zoom sirf jahan zaroorat.
**Khule purane items:** W5b city-name l10n; billing card real renews_at; Lahore label; calendar LCP (T3/T4); E55 grants-heal 30 Oct se pehle; Caddy cert renewal 12 Nov se pehle; blueprint "100 bit" -> 150 bit typo; Mail/People par 390/820 checks.
**Tooling:** bun test (./src/...), tsc --noEmit -p ., eslint --fix sirf apni files par, manifest-sync.py <files> + manifest-verify.py; push reject ho to sirf apne unpushed commits par git pull --rebase.

### Checkpoint 23 Oct 10:05 PKT — Appearance card squeeze fix; scroll "stuck" ka live test
Live (390px iframe, anexomail.com/app/settings/appearance): sirf EK scroller (inner div), JS se neeche->upar scroll bilkul theek (jump/atakna nahi) => "stuck" touch-specific hai, code-layout ka nahi. Kuch bhi mouse-only (use-drag-scroll) touch ko nahi chhoota. Draggable handle (dffe77d) wahi hal hai; pull ke baad phone par test. Agar phir bhi atke: screen recording ya batao ungli kahan thi.

### Checkpoint 23 Oct 10:20 PKT — Calendar settings -> "⋯" menu (push, pull baaki)
Founder hukm: slider icon hata do, Calendar settings "⋯" mein Meeting ke saath. CalSettingsButton ko optional label. Agla: founder pull -> CalDAV phone test (Create password) -> C2.

### Checkpoint 23 Oct 10:05 PKT — LIVE STATE + STANDING RULE
**Standing rule (founder):** HAR message ke baad yeh file + founder-commands + DONE ledger (dono) + manifest update, commit, push. Compact ka darr: pehle update, phir jawab.
**Push ho chuka, founder PULL baaki (ek hi pull.sh):** e04f078, c23f66b (pull-to-refresh asli reload), dd4f841 (globe scroll), 5a67d85 (Settings N+1 hata), dffe77d (draggable scroll handle), 3676c93 (Settings card text patti fix), 1ed46c8 (Calendar settings "⋯" menu mein, Meeting ke saath).
**Live dekha (anexomail.com, purani build):** Appearance par scroll JS se neeche/upar theek => "stuck" touch-specific; handle pull ke baad test. Calendar settings -> Phone calendar section khula hai (Device name + Create password). Key maine NAHI banayi — founder khud banaye (30 akshar, ek baar dikhti).
**Agla:** founder Web pull -> Calendar "⋯" -> Calendar settings -> Phone calendar -> Create password -> phone CalDAV (server anexomail.com, user hostflowaibuilder@gmail.com, password = key). GREEN to C2 (PUT/DELETE, If-Match 412, exceptions, sync-collection); phir #7 Google (founder verification), #8 Rooms.
**Dates:** E55 grants-heal 30 Oct se pehle; Caddy cert 12 Nov se pehle.

### Checkpoint 23 Oct 10:10 PKT — founder ne app password bana liya
Password mil gaya; usay samajh nahi aya ke ab kya karna hai. Samjhaya: yeh phone calendar app ke liye alag password hai (login password nahi); phone mein CalDAV account add karna hai. Agla: founder phone par account jode, result batae (events aaye ya nahi).

### Checkpoint 23 Oct 10:30 PKT — CalDAV user guide in app (push, pull baaki)
Founder ke paas password hai, Android; samajh nahi aya kya karna. /dav/ browser mein 401-text = server theek. Bana: HowTo guide in PhoneCalendar. Agla: founder pull -> DAVx5 se jode -> result (events aaye ya DAVx5 error screenshot). Honest: Android par DAVx5 chahiye (system calendar akela CalDAV nahi jodta).

### Checkpoint 23 Oct 10:40 PKT — DAVx5 paid issue
Founder: DAVx5 Rs1800, nahi lunga. Options diye: (A) F-Droid se free DAVx5, (B) Google Calendar "URL se jodo" secret feed (naya Rust route, no install, refresh slow), (C) kuch nahi. CEO sifarish: A abhi, B baad mein agar user-facing no-install chahiye. Guide text push kiya.

### Checkpoint 23 Oct 10:45 PKT — FOUNDER HUKM: Option A + B DONO (compact se pehle 3 bar update)
Founder faisla: user ko DO raaste do — **A** (DAVx5 free F-Droid, jo tech-savvy hain) aur **B** (bina app, Google Calendar "URL se jodein", baaki users). "Advance codes likho, review kero, SQL sab kero."
**B ka design (in progress):** secret read-only ICS feed `https://anexomail.com/dav/feed/<30-char key>.ics`. Token = wahi format (10 token_id + 20 secret, sha256(pepper||secret) DB mein, key sirf ek baar dikhti). Alag `kind='feed'` ya alag table (E81), revocable, last_used. Rust: dav_glue mein route, Caddy ka /dav/* handle already cover karta hai. Web: PhoneCalendar mein "Google Calendar (no app)" tab + Create link + copy. Caveat honest: Google 12-24h refresh, read-only, link = password (leak => revoke).
**Deploy order (founder):** SQL E81 -> Rust install + restart -> Web pull. Caddy change shayad na chahiye (/dav/* handle hai).
**Status:** design likha; code abhi shuru.

### Checkpoint 23 Oct 11:10 PKT — B (Calendar link) SQL TAYYAR + local proof GREEN
E81_caldav_feed_link.sql + CHECK_E81.sql + proofs/E81_proof.sql bane. `caldav_app_passwords.kind` ('dav'|'feed'); kind-ki-hifazat (feed chaabi CalDAV login nahi kholti, ulta bhi nahi); limits dav 10 / feed 5 alag; naya function caldav_feed_create/list/lookup; revoke wahi. Local Postgres 16: E80+E81 DO BAAR chala, CHECK_E80 5/5 + CHECK_E81 6/6 t, proof pass, mutation test (kind guard hataya => proof FAIL) bhi saabit. sql-editor-lint OK. Agla: Rust (dav_core Route::Feed + feed_ics, dav_glue feed handler + procs caldav.feed.create|list|revoke) cargo check scratch par, phir Web (PhoneFeed UI: "Google Calendar — bina app" default + "Calendar app" A option). Deploy order: SQL E81 -> Rust install + restart -> Web pull. Caddy badlav nahi (/dav/* pehle se).

### Checkpoint 23 Oct 11:40 PKT — B Rust TAYYAR + asli compile + handler harness GREEN
dav_core: Route::Feed, feed_ics (METHOD:PUBLISH, VTIMEZONE ek baar), feed_etag/etag_matches — 17 unit test pass. dav_glue: procs caldav.feed.create|list|revoke (revoke dono kind), GET/HEAD /dav/feed/<30>.ics (login nahi, ghalat/revoked = 404, If-None-Match 304, no-referrer/noindex), bad /dav/feed shape = 404 (401 nahi). SANDBOX MEIN CARGO HAI (offline registry): `cargo check --offline` stub crate par real compile ho gaya — pehle lifetime error pakda gaya (server par fail hota). Harness `docs/cursor-work/server/rust-harness/dav-feed-harness.sh` asli handler ko nakli backend se chalata hai: 200 + valid ICS, 304, HEAD, ghalat secret 404, POST/PUT/DELETE 405 — ALL PASSED. NOTE: purana "sandbox mein cargo nahi" ka note ab galat; glue ke liye bhi yehi tareeqa. Agla: Web UI (PhoneFeed), phir docs/commands, push.

### Checkpoint 23 Oct 11:55 PKT — B (Calendar link) POORA BANA, push; deploy founder ke haath mein
SQL E81 + Rust feed + Web PhoneFeed (tabs "No app (Google Calendar)" default / "Calendar app") + Caddy log_skip (URL hi chaabi hai). Tests: bun 385 pass, tsc 0, dav_core 17, local PG E80+E81 do baar + CHECK + proof + mutation, asli handler harness ALL PASSED, caddy script ka python edit logic (INSERT/UPGRADE/SAME) test. Review rounds: (1) compile ne lifetime bug pakda, (2) bad /dav/feed shape 401->404, (3) truncation newest-first (order desc). Khuli baatein: Google 12–24h refresh; revoke ke baad Google mein purane events dikhte hain jab tak calendar wahan se na hataye (UI mein likha); heavy user 2000 events cap (naye pehle). Deploy tarteeb founder-commands.md "23 Oct 11:55": SQL -> Rust -> Rust restart -> Caddy plan/apply -> Web. Agla: founder deploy + Google Calendar mein link test; phir C2 / #7 / #8.

### Checkpoint 23 Oct 12:20 PKT — B DEPLOY GREEN + cap fix
Founder ne SQL E81 (CHECK_E81 6 OK, E65 OK), Rust (dav 17 passed, build OK, restart, /rpc/health 200), Caddy (UPGRADE, log_skip, apply, 301/DAV/401 sahi), Web (server==repo differ=0) — SAB GREEN. Ab: load() paging fix (premium: har user ke saare meetings) push, founder ko sirf Rust + restart. Agla: founder Google Calendar mein link jodkar test (Create link -> Add to Google Calendar) aur batae; phir C2 / #7 / #8. Khuli baat: Google khud 12–24h mein refresh karta hai (hamare bas mein nahi); jaldi chahiye to A (app).

### Checkpoint 23 Oct 12:35 PKT — paging-fix Rust DEPLOY GREEN; ab Chrome live test
Founder ne paging-fix wala Rust (dav 17 passed, build OK, restart 126, /rpc/health 200) chala diya. SQL E81, Caddy log_skip, Web pehle se green. Ab main (CEO) Chrome mein founder ke logged-in session par: Settings -> Phone calendar -> "No app" -> Create link -> link ka asli .ics fetch check -> (founder ki ijazat se) Google Calendar "From URL". Link ka matn repo/chat mein KABHI nahi (secret). Agla: natija; phir C2 / #7 / #8.

### Checkpoint 23 Oct 12:55 PKT — B (Calendar link) LIVE GREEN (Chrome, founder ka session)
Settings -> Phone calendar -> "No app" -> Create link ("Google Calendar test") -> "Add to Google Calendar" -> Google ne "Add calendar? webcal://anexomail.com/dav/feed/…" dikhaya -> Add -> "Calendar created. Fetching events" -> Other calendars mein "ANEXOMAIL" aaya aur Thu 22 Oct ke dono "iMIP test" meeting dikhe (ANEXOMAIL calendar se match). Yani asli Google ne link fetch kiya aur ICS parse ki. Founder ki Google mein ab "ANEXOMAIL" subscribed hai (test link; Settings se Remove + Google se hatana ho to dono jagah). NOTE: tool ne secret URL ko JS se padhne se roka (theek) — link ka matn kahin save nahi. Baaqi: asli Android phone ka Google Calendar app (same account) sync — founder dekhe. Agla: C2 (A ke liye PUT/DELETE) ya #7 Google / #8 Rooms.

### Checkpoint 23 Oct 13:00 PKT — CALENDAR HISAAB: 11/13 GREEN
Founder: "calendar kitna kaam hai blueprint ke hisab se, green kero". CALENDAR-ROADMAP.md updated: #6 CalDAV GREEN (A server-live + B Google-link LIVE). Baaqi 2: #7 Google (founder ki Google Cloud verification chahiye — maine kaam nahi shuru kiya), #8 Rooms (ab shuru: SQL E82 -> Rust -> Web). Chhote: LCP 2.6s (T3/T4), INP, E55 30 Oct se pehle, A ka asli-app test (F-Droid DAVx5 ya iPhone).

## CHECKPOINT 23 Oct — #8 ROOMS (SQL tayar, local proof PASS)
- Design: room = pseudo-attendee `room-<12hex>@rooms.anexomail.com`; booking = attendee insert; conflict engine (calendar_busy) bina badle rooms dekhta hai. Race-safe: advisory lock per room.
- Files: sql/E82_calendar_rooms.sql (idempotent, 2 runs OK), sql/CHECK_E82.sql, sql/proofs/E82_proof.sql (ALL PASS + mutation test pakda gaya).
- Procs: calendar_room_create/list/archive/state/book/release/schedule (service_role only). Privacy: schedule mein sirf waqt+organiser.
- BAAKI (#8): Rust procs in dav/cal glue + invite-skip for @rooms.anexomail.com, Web settings manager + event composer picker, tests. E82 abhi server par DEPLOY NAHI hui.
- #7 Google sync abhi bhi Nauman ki Google Cloud verification par blocked.

## CHECKPOINT 23 Oct 14:30 — #8 ROOMS code POORA (deploy baaki)
- SQL E82 + CHECK_E82 (6 t) + proof (mutation pakda). Rust: rooms_core.rs (4 tests) + rooms_glue.rs (7 procs `calendar.rooms.*`), cal_glue invite-skip `@rooms.anexomail.com`, installer mein `rooms` module. Web: lib/rooms.ts (+2 tests), RoomsSettings (CalSettings mein), EventRoom (EventDetail mein). tsc saaf.
- Nauman ko deploy: SQL -> Rust -> restart -> Web (founder-commands.md 14:30). Deploy ke baad live test: room banao, do meeting overlap mein book karke busy dekhna.
- Calendar roadmap: #8 code-complete, live test baaki. #7 Google sync Nauman ki Google Cloud verification par blocked.

## CHECKPOINT 23 Oct 11:05 — CALENDAR GREEN
- Founder: #7 Google sync DROP abhi (na code, na testing; likha gaya to intact). #8 Rooms server par => GREEN. Roadmap update. Agla kaam locked order se: Founder account -> identity live tests -> M-series -> G16 -> T1–T12.

## CHECKPOINT 24 Oct 14:20 — #8 ROOMS DEPLOYED (server output dekha)
- SQL E82 + CHECK_E82 6/6 OK, Rust build OK (rooms 4 tests, sab modules), restart online, Web build OK server==repo. Rust installer ke live-saboot mein rooms ka probe nahi hai (sirf baqi modules); asli test: Settings -> Rooms & resources, phir meeting -> Room -> Book.
- Calendar GREEN. #7 Google parked. Agla: Founder account.

## >>> CALENDAR = GREEN, USER KO HANDOVER (24 Oct 14:25) — COMPACT SE PEHLE FINAL <<<
- Founder hukm: Calendar GREEN declare. 12 hisse GREEN + deployed; #7 Google sync founder ke faislay se deferred (bana nahi). Detail: CALENDAR-ROADMAP.md "CALENDAR = GREEN (HANDOVER)".
- Calendar par ab KOI kaam nahi (naya bug/feature founder maange tab hi). Rooms ka asli browser test founder kare to LIVE-verified likhna.
- AGLA (locked order): Founder account -> identity live tests -> M-series -> G16 billing portal -> T1–T12. Founder ne kaha: abhi Founder account SHURU NAHI karna, pehle green handover. Agla kaam founder ke hukm par.

## CHECKPOINT 24 Oct 14:30 — Rooms LIVE TEST (Chrome) + fix; RULE: har message ke baad context update
- Live (anexomail.com): room create OK, book OK (meeting par "Release" + jagah auto-set), release OK. Loophole mila: release ke baad jagah rehti thi -> E82 release fix (commit ae13b9c/20b1e70), local proof ALL PASS. Server par SIRF SQL chalani baaki (sql-run.sh); founder ne galti se mera message terminal mein paste kiya (kuch nahi bigda).
- Baaki: SQL chalne ke baad (a) Gmail test meeting par jagah "Test room" saaf karna (Book+Release), (b) overlap "Busy" live test (test meeting banani padegi, founder ki ijazat), (c) "Test room" founder rakhe ya hataye.
- RULE (founder 24 Oct 14:28): HAR message ke baad yeh context file update — bina poochhe, bina bhoole.

## CHECKPOINT 24 Oct 14:30 — Rooms LIVE-tested (Chrome, anexomail.com)
- Live: Settings -> Rooms & resources: "Test room" create OK. Meeting "iMIP test - Gmail Yes" -> Room -> Book OK (Release dikha), Release OK.
- Bug mila: Release ke baad meeting ki location "Test room" rehti thi. Fix: E82 release auto-location saaf (commit ae13b9c/20b1e70). Local proof ALL PASS. SERVER PAR SQL baaki: founder ko sql-run.sh chalana hai (founder-commands 14:35). Us meeting par purani "Test room" location ek baar Book+Release se saaf hogi.
- Abhi baaki: overlapping meeting par "Busy" ka live test (test meeting banani padegi, founder ki ijazat). "Test room" workspace mein maujood.
- Founder ka niyam: HAR message ke baad context/ledger/manifest update + push (compact se pehle). Founder account abhi shuru NAHI.

## CHECKPOINT 24 Oct 14:45 — Rooms live: Busy OK, 2 bug fix
- SQL fix (release location) server par CHALI (CHECK_E82 6/6). Live: "ZZ room busy test" overlapping meeting par room "Busy" dikha (GREEN proof); test meeting cancel kar di (koi guest nahi, mail nahi).
- Bug 2: room guest list/ginti mein dikhta tha -> Web fix withoutRooms (lib/rooms.ts), calendar.ts select + Guests.tsx. Founder ko Web pull (founder-commands 14:45). Gmail test meeting par abhi "Test room" booked hai — pull ke baad Release karke saaf karna (ya main).

## CHECKPOINT 24 Oct 15:05 — Rooms loophole sweep: DB guard E83
- Founder niyam: live testing mein jo loophole mile SAB fix, ek bhi nahi chhodna. Mile: (1) release location, (2) room guest ginti/list, (3) room double-book bypass (manual guest + reschedule). 1 server par; 2 Web pull baaki; 3 = E83 + cal_glue room_busy 409 (SQL -> Rust -> restart).
- E83: calendar_room_guard + 2 triggers; proof ALL PASS + mutation pakda; E82 proof ab bhi pass. Haad: repeat series sirf pehla slot.
- Chrome "Finding ... Failed" = meri find-tool ki khoj fail hui (page ka view badla tha: month/day), app ka bug nahi.
- Baaki live test: E83 deploy ke baad reschedule ko busy slot par dekhna.

## CHECKPOINT 24 Oct 15:30 — E83 live-verified + fix 4
- Server par SQL(E82 fix,E83)+Rust+Web chale. Chrome: guest ginti 2 (room ab guest nahi) OK. Manual room guest + overlap: DB ne roka (event nahi bana) — par jawab "Calendar failed" tha -> fix 4: Web room ko guest se hata deta + hint; Rust create/update par 409 room_busy / 400 no_room. Founder ko Rust+restart+Web (founder-commands 15:30). Phir live: reschedule busy slot + manual guest message dobara dekhna. Gmail test meeting par "Test room" abhi booked.

## CHECKPOINT 24 Oct 15:00 — ROOMS LIVE-VERIFIED (sab fix server par)
- Chrome live: (1) room address guest box mein -> hint "A room is not a guest..." dikha, meeting bani bina room guest ke; (2) booked meeting ko busy slot par reschedule -> "Could not move: A booked room is already taken at that time. Release the room or pick another time." (409, waqt nahi badla); (3) Release ke baad meeting ki location saaf (purana "Test room" gaya); (4) guest ginti 2. Test meetings (ZZ, ZZ3) cancel; "Test room" workspace mein, free.
- Room Rooms #8 = GREEN + LIVE-verified. Koi khula loophole nahi. Haad: repeat series sirf pehla slot check.
- Agla: Founder account (founder ke hukm par).

## CHECKPOINT 24 Oct 16:05 — E84 repeat-series room check + site sweep
- Founder: "ek bhi loophole nahi, puri website, pro package green". Kiya: cal_core::first_overlap (+test, cal 43 tests pass), cal_glue::room_series_clash (400 din, saare occurrences), rooms_glue book + cal_glue update(time/rrule) mein hook; installer rooms need_mods cal_core+cal_glue. Founder ko sirf Rust+restart (founder-commands 16:05). Compile cal_glue full stub mein nahi (missing crate stubs), isliye server build pehli asli compile.
- Site sweep (Web): tsc saaf, 388 tests pass; eslint 2174 errors = 2160 prettier formatting (purani, cosmetic) + 14 asli lint (api-refresh/mail-rpc/passkey-login tests `any`, history.ts control-regex, mail-attachments any, timeFormat.ts use12h "hook" naam rules-of-hooks). Live bug nahi; alag task.
- "Pro package green": scope Nauman se tay karna (kaunsa package/kya check) — abhi koi pro-package checklist repo se pakki nahi.

## RULE (24 Oct 15:17) — BOLNE KA ANDAAZ
Founder ne kaha: "tum/tumhare" nahi. HAMESHA "aap" aur "Nauman bhai" (izzat se). Roman Urdu, saaf. Purane messages mein "tum" aaya to ab nahi.

## >>> NAYA KAAM (24 Oct 15:25): PRO PACKAGE GREEN <<<
- Nauman bhai: package cards par jo offer hai, Pro mein woh SAB waisa hi milna chahiye (Basic isi tarah green kiya tha). Method: Chrome mein Pro package + plan doc dekho, match karo ke live user ko kya milta hai ("real buyer Pro kyon le ga"). Loophole mile to TURANT fix + dobara test. JAB TAK PRO GREEN DECLARE NA HO, AGLA KAAM (Founder account etc.) NAHI. Har step ke baad context update.
- Rooms E84 Rust server par chal gaya (Nauman bhai ne pull kiya); series live test baaki (chhota).

## PRO AUDIT — live findings (24 Oct 15:50, Chrome, pro.buyer@anexomail.com = Pro £46, 10GB, 1/1 seat)
Card (plans.ts Pro) vs live: ✓ plans page = billing cards = plans.ts; ✓ Domains cap 3 + mailboxes 0/5; ✓ billing 10GB £46; ✓ Compose: Insert template + Schedule send dikhte; ✓ Work: Tasks add (POST /api/work/tasks 200), Work chain Pro, Decision ledger Business+ (sahi gate); ✓ thread: Snooze/Done/Archive/Label/Meeting.
LOOPHOLES MILE + FIX (Web+Bun, push baaki): (1) "Email templates" — list khali, banane ka koi UI nahi => compose mein "Templates…" panel: Save as template + Remove, server POST validate (naam/body/50 limit) + DELETE route. (2) Domains "1 of 3 domain" => "domains". (3) "Notes" sirf meeting par thi, mail thread par nahi => ThreadNote (Pro+) NoteDoc thread par; server note 20k cap.
Abhi BAQI check: Snooze asli kaam, Schedule send asli, collision guard / shared inbox (verified domain chahiye), thread analytics (ThreadInsights 'Best time to send' dikha), 48h support text, "Everything in Basic" items, mobile 390/820, 'Boards' (TaskBoard 4 column dikha).

### 24 Oct 16:25 — PRO audit fix block 2
- Founder: "rust primary hai, jo technology use ho woh apply karo" -> fixes dono (Rust + Bun) mein.
- Snooze loophole FIXED: server ab folder="snoozed" nahi likhta; Rust `mail_query_threads` + Bun `queryThreads` inbox mein future-snoozed chhupate hain; virtual folder "snoozed" (ia.ts, MailRail) = inbox + snoozed_until > now.
- Bhi: templates UI, thread notes, domain plural, notes cap (pichla block).
- Baaki Pro audit: deploy ke baad live re-test (Snooze, templates, notes, domain), Schedule send, shared inbox collision (verified-domain account chahiye), thread analytics, 48h support text, Basic items, TaskBoard, mobile 390/820. Pro abhi GREEN declare NAHI.

### 24 Oct 16:45 — FOUNDER TECHNOLOGY RULE (locked, compaction ke baad dobara) + Pro fix block 3
- Puri website latest technology par migrate ho rahi hai. **Rust PRIMARY, Bun sirf FALLBACK.** Har naya/ठीक kiya endpoint pehle Rust proc (`/rpc/*`, `rpcOrRest`) mein, Bun `/api/*` sirf fallback mein. PostgreSQL = data store (Bun fallback ke sath), baqi latest tech apply karni hai.
- Technology map (pehle se LIVE, dobara poochna nahi): Tokio async 1.53.3 (har proc/worker/hub), axum 0.8.9 (HTTP /rpc/*), tRPC-style `/rpc/*` JSON (client `rpcOrRest`), QUIC via wtransport 0.7.2/quinn (events live push, B4). Baqi: B8 = tokio 1.54, Bun 1.4.3, Brain -> Rust. Kaun si tech kahan: request/response = axum+tRPC-style; background/queues/hub = tokio; live push (mail/calendar/crm) = WebTransport; DB = Postgres via PostgREST/sql-run.
- Pro = mobile 390, tablet 820, laptop/desktop 1440 par har cheez card se ek-ek word match hone tak GREEN nahi.
- AUDIT mein pakda: Snooze, Pro templates save/delete pehle SIRF Bun par thay (galat). Ab Rust PRIMARY: `mail.snooze`, `mail.templates.save`, `mail.templates.delete` (main.rs) + Bun fallback (bad_until 400 bhi). Client `useThreadAction` snooze, `useSaveTemplate`, `useDeleteTemplate` -> `rpcOrRest`.
- Abhi Bun-only (Pro): thread note (`work.notes.upsert` Rust par hai — check), labels/status/assign/move thread actions, templates LIST, snippets. Inhe bhi Rust par laana audit ka hissa (loophole).

### 24 Oct 17:05 — TECH AUDIT (full numbers in docs/cursor-work/TECH-AUDIT-24OCT-RUST-PRIMARY.md)
- Bun endpoints 511; Rust procs ~328; client: 142 Rust-first call sites, 76 Bun-only (61 unique); 23 refetchIntervals still poll. Repo 2,155 files (35,000 NAHI).
- PLAN Rust mein khud nahi jata: har proc mein gate likhna parta hai. Loophole mila+fixed: Snooze/Schedule send(>130s)/Templates save server par Pro-gated (Rust pro_plan_ok + Bun resolvePlan). Rust mail dispatcher ab validation tokens ko 400 aur feature_not_available ko 403 deta hai (pehle sab 500).
- Tech kahan: axum+tRPC-style = request/response; tokio = workers/timers/fan-out; WebTransport = live push (mail, snooze wapsi, scheduled status, calendar, crm, chat, calls) 23 polls ki jagah; Postgres = store; Bun = fallback.
- Agla: Pro ke baqi Bun-only actions Rust par (labels/status/assign/move, drafts, templates list, snippets), phir deploy ke baad live re-test, 390/820/1440.

### 24 Oct 17:30 — MIGRATION BATCH M1 (Rust PRIMARY, Bun fallback; website todna nahi chahiye)
- Founder hukm: puri website latest tech par, har endpoint, ek bhi loophole nahi, par site tootni nahi chahiye => har batch `rpcOrRest` (Rust 404/501/502/503 par Bun khud chalta hai), batch-by-batch, har batch ke baad live test.
- M1 done (repo): thread actions labels/status/move/assign/snooze ab Rust primary (`mail.labels.update`, `mail.status`, `mail.move`, `mail.assign`, `mail.snooze`) + Bun validation barabar (bad_status/bad_folder/bad_label). `mail.assign` ka naam/email lookup abhi Bun (Rust 501 => fallback). Rust "not_found" => 404.
- Agla M2: templates LIST, snippets, drafts, follow-up, handoff, send-confidence, thread-note; M3 contacts/companies/workspace/storage/billing state; M4 auth+trial; M5 org/crm/calendar; M6 chat, ai. Har M ke saath plan gate + Basic-user test + live re-test.

### 24 Oct 17:50 — MIGRATION PHASES locked (docs/cursor-work/MIGRATION-PHASES-24OCT.md)
- 11 phases (P0 done). Lanes alag, mix nahi: A = Basic/Pro/Business/Business Pro; B = Personal + Family; C = Founder (alag batch, founder.ts/release/admin/perf/revenue/glitch). Plan rules ek jagah (SQL resolve_plan canonical; Rust pro_plan_ok; Bun resolvePlan). Duplicate code nahi: shared helpers, proc Rust mein ek baar.
- Bun = hamesha EMERGENCY fallback (routes kabhi delete nahi); har phase ke end par fallback drill.
- Tarteeb: P1 crates+Bun 1.4.3 -> P2 M2 -> P3 M3 -> P4 M5 -> P5 Lane B -> P6 auth -> P7 Founder -> P8 chat+ai -> P9 WT live (23 polls) -> P10 sqlx/types/speed.
- Locked order (Calendar done -> Founder account -> identity tests -> M-series -> G16 -> T) ko founder ne Pro-green + migration ke liye aage kiya; Founder ACCOUNT (command centre) abhi bhi Pro green hone ke baad.

### 24 Oct 17:45 — MIGRATION PHASES locked (docs/cursor-work/MIGRATION-PHASES-RUST-PRIMARY.md)
- 8 phases: M1(done) M2 M3 M4 M5 L(WebTransport live) M6 F(FOUNDER alag batch) B8. Sab account kinds (basic/pro/business/business pro/personal/basic personal/family) EK hi code path: resolve_plan se gate, koi per-kind duplicate nahi. Founder routes kabhi buyer batch mein mix nahi. Bun hamesha emergency fallback.
- Per-technology commands: SQL / Rust(+restart) / Web — har batch ki entry batati hai kaun si lagti hain.

### 24 Oct 17:55 — FOUNDER ORDER (locked 16:12 PKT)
- PEHLE ~510 Bun endpoints latest technology par (jis kaam ke liye jo tech: axum+/rpc request/response, tokio workers/fan-out, WebTransport live push), PHIR packages GREEN: Pro -> Business -> Business Pro. Pro abhi GREEN nahi.
- Family accounts: lifetime plan mila hai par product mein REAL BUYER jaisa (wahi features/gates/limits, resolve_plan se). Code mein koi special-case nahi; tests mein har plan ka family account.
- Koi mixed code nahi. Pull command har batch ke saath technology ke hisaab se (SQL / Rust+restart / Web).

### 24 Oct 18:00 — M1 DEPLOYED by founder (Rust install + restart + Web pull, 16:16 PKT)
- Live test baaki (Pro account pro.buyer@anexomail.com, tab 1609160493): snooze + Snoozed view, labels/status/move/assign, templates save/remove (Basic-user 403 check), schedule send, thread note. Pass hone par M1 GREEN, phir M2.

### 24 Oct 18:20 — M1 LIVE TEST: bug pakda + fix (RULE: Rust procs sirf module se deploy hote hain)
- Live (Pro account): Snooze ab bhi "invalid input value for enum mail_folder" — /rpc/mail.snooze 404, Bun /api purana. Wajah: `rust-engine-install.sh` live main.rs REPLACE nahi karta, sirf `*_core/*_glue` module jodta hai => main.rs mein likhe naye procs kabhi deploy nahi hote. (Bun fallback bhi purana tha: web pull ke baad Bun restart/build check karna.)
- FIX: `server/rust/mailx_core.rs` (7 unit tests) + `mailx_glue.rs` (snooze/status/move/labels.update/assign+GoTrue lookup/templates save+delete/`mail.threads` wrapper: inbox hides future-snoozed, folder "snoozed") registered in installer CFG + probe. main.rs wapas a6507a5 jaisa (koi duplicate nahi). `mail_glue.rs`: schedule Pro gate (local helper). Stub-harness mein glue compile + 16 calls (400/403/200/threads filter) pass.
- RULE: naya Rust proc => module (core std-only tests + glue) + installer CFG; repo main.rs mein NAHI. Push se pehle stub harness (/tmp/rt3) mein compile+call.
- Deploy pending: rust-engine-install (mailx) + rust-mail-install (schedule gate) + restart. Phir live: snooze, Snoozed view, labels/status/move/assign, templates, Basic 403.
- 24 Oct 18:35 (live test #2): Bun /api live abhi PURANA hai (bad_folder => enum error, snooze `until:garbage` => process crash + 502 jab tak pm2 restart). Wajah: `pull.sh` sirf Web (anexomail-web) update karta hai; Bun routes Brain (/opt/anexomail/src, pm2 anexomail-leo) mein `brain-*-install.sh` se jate hain. FIX: `brain-pro-install.sh` + `brain_pro_patch.py` + `brain_pro_hunks.json` (3 files: mail.ts, mail-compose.ts, calendar.ts; hunks round-trip verified, idempotent, bun build pre-flight, restore-on-fail). Deploy order ab 4: Rust engine (mailx) -> Rust mail (schedule gate) -> restart -> Brain (brain-pro-install). RULE: Bun-side change = brain-installer; Rust-side = module installer; Web = pull.sh.
- Caution: live Bun par galat input (garbage date) mat bhejna jab tak brain-pro-install na lage (crash hota hai).

### 24 Oct 18:50 — FOUNDER: "bun fallback ki command kyun nahi dete?" + context update
- Sach: pehle ke batches (rooms fix, pro audit, M1) mein maine sirf Rust+Web commands diye kyunki galat maan liya tha ke `pull.sh` Bun (Brain) bhi update karta hai. Galat tha: Bun routes sirf `brain-*-install.sh` se jate hain. Ab HAR batch mein Bun command bhi di jayegi (jahan server/routes badla ho).
- Ab tak ke codes (is session): Rooms E82-E84 (Rust+SQL, live verified); Pro audit: templates UI+save/delete, thread notes, domain plural, notes 20000 cap, Snooze fix + Snoozed folder, Pro server gates (snooze/schedule/templates), thread actions Rust procs; migration docs (MIGRATION-PHASES, TECH-AUDIT); modules: mailx (Rust), brain-pro hunks (Bun). Deploy PENDING (founder): rust-engine-install (mailx) -> rust-mail-install -> pm2 restart -> brain-pro-install.
- Naya READ-ONLY check: `brain-drift-check.sh` — repo ki server/routes+lib vs live Brain, kaun si file alag (jo alag hai wo kabhi live nahi gayi). Founder se output lena; us ke baad har alag file ke liye brain installer.

### 24 Oct 19:20 — M1 LIVE RESULT (Pro, Chrome) + 2 loopholes
- GREEN live: mail.snooze (Rust 200), Inbox hides snoozed, Snoozed folder, status/move/labels, templates save/delete (50-cap, own-only), galat input 400, foreign thread 404, Bun validation (bad_folder) deployed, Brain alive.
- LOOPHOLE 1: assign (Pro "Shared inbox with collision guard") broken on Rust AND Bun (PGRST203, 2 overloads of mail_thread_assign). FIX = SQL E85 (+CHECK_E85, proofs/E85_proof.sql; local PG tested, idempotent): ek function (uuid,uuid|null,uuid), null clears, assignee must be active org member (pehle koi bhi user uuid). Rust mailx_glue + Bun (brain_pro2_hunks.json) null bhejte hain.
- LOOPHOLE 2: Snooze menu mein "Bring it back" sirf label tha, unsnooze ka button nahi. FIX: "Bring back now" item (ThreadHeaderActions, snoozedUntil prop) + heading "Snooze until".
- Brain installer ab 2 hunks files (brain_pro_hunks.json + brain_pro2_hunks.json): fresh aur already-patched dono par dry-run OK. Test debris live: label "ZZ-m1" (Pro workspace) — baad mein hatana; thread 0af789df snooze hata diya.
- Basic-user 403 live test baaki (Basic account ka login chahiye); Rust/Bun gate code tested in stub harness.
- Deploy pending (5 commands): SQL E85 -> Rust engine -> restart -> Brain -> Web. Phir live: assign, Bring back now. Phir M2.

### 24 Oct 20:10 PKT — M2 compose procs Rust primary (READY)
mailx module mein mail.drafts.save/versions, templates.list, snippets.list/save, signatures.list, confidence, followup.create/list. Bun hunks3 (draft columns to/cc/bcc/saved_at, user filter, bad remind_at 400). E86 SQL. Client compose.ts rpcOrRest. Deploy: SQL(E85+E86) -> Rust -> restart -> Brain -> Web. Agla: M2b handoff, M3.

### 24 Oct 22:00 — migration hisaab
Founder ne E83->E85 aur migration ki ginti poochi. Jawab: E84 Rust-only tha. Hisaab `docs/claude/MIGRATION-LEDGER-24OCT.md` (+CSV): 511 Bun endpoints, 132 client Rust-first, 379 baqi, 320 Rust procs. Chat 141 sab se bada baqi hissa. Agla: M2 deploy/live test, M2b handoff, M3.

### 24 Oct 22:30 — Rule 50
Founder ne 8-phase plan confirm kiya aur rule diya: phase table + ledger saath ke saath update (AGENTS.md Rule 50).

### 24 Oct 22:45 — E84 SQL
Founder: SQL ki tarteeb nahi tootni. E84_room_series_note.sql + CHECK_E84.sql banayi (E83 guard par comment, Rust series check ka note). Ab tarteeb E83, E84, E85, E86. sql-run bare command E84 bhi chalayegi.

### 24 Oct 23:15 — M2 live GREEN
Founder ne M2 deploy kar diya (SQL E84-E86, Rust, Brain, Web). Live test pro.buyer: drafts save v1/v2 + Version history UI, snippets, follow-up (bad date 400), send-confidence, schedule hold->cancel, 400s. Mobile 390/820 composer ok (no h-scroll). thread insights ab rpcOrRest ({id}). Founder ka hukm: Pro/Business/Business Pro green hone tak Founder account nahi. Pro baqi: shared-inbox collision guard (verified-domain Pro account), Basic-user 403 test, 48h support copy, phir M2b handoff + M3.

### 24 Oct 23:30 — founder live saboot
Nauman bhai ne composer se attachment ke saath email bheji; Gmail par mili. Send + attachment + undo-hold raasta live GREEN. Dobara test nahi karna.

### 24 Oct 23:59 — Pro green list (founder hukm) — halat
(1) M2b handoff + delete procs: READY (Rust mailx + Bun hunks4 + client rpcOrRest; composer autosave -> mail.handoff.save). (2) Basic-user 403: `basic-gate-probe.sh` (server par, password nahi) — founder chalaye, output bheje. (3) Shared-inbox collision guard: live test baqi (verified-domain Pro account ya doosra member). (4) Kachra saaf: delete procs deploy ke baad Chrome JS se (draft 198149dc..., snippet zzm2, followup ZZ fu), label ZZ-m1 + task ZZ pro audit task UI se. (5) M3-M5. Founder account: NAHI.

### 25 Oct 00:20 — collision guard
Live: assign/unassign/non-member 400 (E85) green. Loophole: owner chip raw UUID dikha raha tha -> `useAssigneeName` (You / naam / email). Web pull se live; phir Chrome pe dobara dekhna.

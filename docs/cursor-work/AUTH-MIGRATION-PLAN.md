# AUTH-MIGRATION-PLAN — sign-in Supabase GoTrue se latest technology (Rust) par (22 Oct 2026, founder)

## Founder ka hukm (verbatim, 22 Oct 2026 20:50 PKT)
"yeh hum wasiye bhi website ko bun se latest technology pe migrate ker rahay hain toh yeh bhi new technology pe jaye ga aur bun fall back hamesha rahay ga. bun hamesha emergency rahay ga. primary latest technology hogi. frontend bhi latest technology hoga. sql likhe jaye gay is ke jo ke as per rule super advance hogay aur advance codes likha jaye ga. abhi ek bhi user nahi hai is liye yeh kaam ker saktay hain lekin supabase vault ke rules hain ke user ka passkeys data jo bhi sensitive hai passkey ka fingerprint bhi vault main hoga. yeh rule footer main hai ke agar koi wrong activity main hoga toh woh account blocked hoga aur us ke fingerprint vault main safe hogay, is liye koi bhi dobara account banane ki try karay ga woh fingerprint match hogay vault se; agar vault ne bola hai ke yeh blacklisted hai toh yeh account user nahi bana sakay ga. yeh dekh lena policy privacy main likha hai"

## Faisla (locked)
- Primary = Rust (axum + tokio, HTTP/3 via Caddy). **Bun hamesha emergency fallback** — kabhi hataya nahi jata. Frontend bhi latest (React 19 / TanStack Start / Vite 8 / Tailwind 4).
- Sign-in WebTransport par NAHI (one-shot request/response; WebTransport streams ke liye hai).
- Har phase: SQL pehle (Rule 38/42/43/44, sql-run.sh), phir Rust, phir Web; differential test (Bun jawab == Rust jawab); canary pehle founder ke account; live verify ke baad hi aage. Sign-in ke A button (Rule 39) par koi asar nahi.

## Phases
| Phase | Kya | Risk |
|---|---|---|
| A | login / session / logout / MFA ke API Bun se Rust (`auth_glue.rs`), Rust GoTrue ko HTTP se call karta rahe. Rate limit + device binding wahin. | kam |
| B | Rust JWT local verify (JWKS, `jwt_core.rs`) — har request par GoTrue round-trip khatam | kam-darmiyana |
| C | passkeys poora Rust par (`passkey_core/glue`), passkey data vault mein (neeche), naye signups apne store mein | darmiyana |
| D | purane users login par lazy migrate (bcrypt verify -> argon2id), jab sab ho jayein GoTrue band | UCHA — alag founder "haan" |

## VAULT qaide (founder) — design requirements
1. Passkey ka sensitive data (credential id, public key, counter) vault mein: encrypted at rest (key server env, repo mein kabhi nahi), table par anon/authenticated ke koi haq nahi (RLS ON, Rule 43), sirf service_role. Abhi `webauthn_credentials` (phase63) par `grant select … to authenticated` hai — Phase C mein band hoga.
2. Wrong activity => account BLOCKED (ladder: ek likhit final warning, repeat = block, severe = ban list; privacy.tsx). Block hone par device record ka hash + account identifiers ka one-way hash vault ban list mein SAFE rehte hain (data 72 ghante export ke baad delete, sirf hash bachta hai).
3. Signup / dobara signup par `signup_device_gate` (E18/E42 `device_hash_v2` HMAC) vault se match karta hai: ban list mein ho to naya account NAHI banta.
4. Vault ka jawab "blacklisted" = signup refused, saaf wajah-code, koi andaza nahi.

## Policy/Privacy ke saath mel (audit 22 Oct) — sach jo likhna hai
| Policy ka wada (`privacy.tsx`) | Code ki halat | Gap / kaam |
|---|---|---|
| Paanch moti nishaniyan, hash, encrypted, deletion date | `device_hash_v2` HMAC, `device_vault`, `retain_until` 180 din | theek (PROMISES #1-5) |
| "No biometric fingerprinting" | sahi — yeh "device record" hai, biometric nahi; passkey ka biometric user ke device par rehta hai | lafz "fingerprint" UI/policy mein mat likho — "device record" |
| Severe pattern => device ban list, naye account nahi | `device_bans` + gate maujood | ban entries ki RETENTION policy mein likhi nahi (180 din wali deletion date ban list par kaise lagti hai?) — likhna hai |
| Blocked account ka data 72 ghante ke baad permanently delete | E45 purge + tombstones (email HMAC) | policy mein nahi likha ke sirf ek-tarfa hash ban list mein reh jata hai — likhna hai |
| Passkey vault mein | policy mein zikr nahi | Phase C par paragraph jodna: "passkey public key + credential id encrypted, private key / biometric kabhi nahi" |
| (founder) passkey fingerprint se dobara signup rokna | **TECHNICALLY kamzor**: passkey credential id har account/site par nayi banti hai, naye signup par wahi authenticator bhi NAYA id dega — isse returning banda pehchana nahi jata | asli rokna: device hash (E42) + email HMAC tombstone + recovery address hash. Passkey id sirf us account ko pehchanta hai |
Public legal copy (privacy.tsx / footer) founder ke "haan" ke baghair nahi badli jati — jo likhna hai woh upar gap column mein.

## Abhi ke users
Real awam user 0; test + family accounts hain (family/lifetime Rule 40). Isliye Phase A-C ab mumkin hain; D se pehle backup + founder "haan".

---
## IDENTITY VAULT — "ek insaan, ek account" (design locked 22 Oct 2026 21:10; SQL E66 + E67 READY)
Founder: user ek account par aaye; wrong activity => blacklist; dobara account banane par Gmail jaisa roke; passkey ka sensitive data vault mein.

### Sachai pehle (kya mumkin hai)
Koi bhi system "wohi insaan" 100% nahi pehchan sakta (Gmail bhi nahi — woh bhi phone, device, IP, behaviour ke ek jaal se rokta hai). Isliye ek nishani par bharosa nahi: **kai nishaniyan, mazboot aur kamzor alag**. Passkey ki credential id har account par nayi banti hai — woh sirf "yeh account" pehchanti hai, "yeh insaan" nahi; isliye passkey ko ban-key nahi banaya.

| Nishani | Kya hai | Taqat | Kaise bani |
|---|---|---|---|
| `device_key` | browser ka NON-EXTRACTABLE WebCrypto (ECDSA P-256) key; server har signup/login par challenge sign karwa ke tasdeeq karta hai (device-bound credential), hash = HMAC(pubkey) | MAZBOOT (us browser profile ke liye) | Web `device-key.ts` + Rust challenge-proof (Phase A) |
| `email` | anexomail address + recovery address ka canonical form (gmail dots/+tag hata kar) HMAC | MAZBOOT | Rust normalisation + HMAC |
| `recovery` | recovery email (Gmail/Apple/Outlook) HMAC | MAZBOOT | wahi |
| `payment` | Polar customer ka HMAC (billing email + country; card Polar ke paas rehta hai, hum kabhi nahi dekhte) | MAZBOOT (har paid account ke liye ek hi hota hai) | Polar webhook (Rust :3400 ko haath nahi — alag read) |
| `device_shape` | paanch moti nishaniyan (E42 `device_hash_v2`) | KAMZOR — bahut bekasoor log ek jaise hote hain | maujood |
| `network` | IP /24 (v4) ya /48 (v6) ka HMAC, sirf 30 din | KAMZOR | Rust |

### Faisla (SQL `identity_signup_check`)
- **DENY**: koi bhi mazboot nishani active ban se mile. Jawab mein hash/account kabhi nahi; "appealable" + wajah-code.
- **REVIEW**: do ya zyada kamzor milan, ya ek `device_key` 3+ accounts par. Account banta hai par insaan review karta hai (kisi ko ghalat ban nahi).
- **ALLOW**: baaqi.
- Wrong activity => ladder (privacy.tsx): ek likhit warning, dohra = block, severe = hamesha. `identity_ban_account` account ke sab nishan blacklist mein; account/data 72 ghante export ke baad delete, sirf ek-tarfa hash bacha. Appeal manzoor => `identity_ban_lift` (severe appealable nahi).
- Retention (policy table): ban 730 din (severe/fraud hamesha), device nishan 180 din, network 30 din; email/recovery/payment account ke saath. Account delete (bina ban) => signals CASCADE se mit jate hain.

### Passkey vault (E67)
AES-256-GCM blob (`enc`, Rust encrypt/decrypt, key server env) + HMAC blind index `cred_hmac`; plaintext credential id / public key DB mein nahi; `key_id` se rotation; counter atomic (clone detection); authenticated ka purani tables se SELECT band (E67 mein).

### Itna bhi mumkin nahi (sach)
Naya browser profile / storage saaf karne wala `device_key` badal sakta hai — isliye email/recovery/payment mazboot nishaniyan saath hain, aur kamzor milan review banata hai. Poori garanti nahi; kai parat se ghalat-istemal bahut mehnga.

### Privacy/footer copy — PROPOSED (founder ke "haan" par hi lagegi)
"We keep one-way (HMAC) hashes of a few signals — your browser's device key, e-mail and recovery address, payment customer, and coarse device and network shape — never the raw values, and never biometrics. If an account is blocked for confirmed abuse, those hashes (and nothing else) stay on a ban list for up to 2 years (permanently for fraud or severe patterns) so the same person cannot open new accounts; you can appeal. Passkey public keys are stored encrypted. When an account is deleted without a ban, its hashes are deleted with it."

### Kaam ki halat
| Hissa | Halat |
|---|---|
| E66 identity vault SQL (27/27 proof, CHECK 8) | READY — server par `sql-run.sh` (bare) |
| E67 passkey vault SQL (17/17 proof, CHECK 6) + authenticated select band | READY |
| E68 vault admin hook (Block/Release/Appeal -> ban/lift), signup appeals, overview, Bun enforcement, Web device-key | READY (Rust sign-in move = Phase A) |
| E69 mirror feed + health + payment sweep source + deny-after-signup flag; Bun mirror/outbox/guard; Rust vault_core.rs (pure, parity) | READY (22 Oct 22:20) — Phase A: vault_glue.rs + sign-in |
| Rust: HMAC/AES-GCM/normalisation (`vault_core.rs`) + `auth` glue + device-key challenge | TODO — Phase A/C (W2 ke baad) |
| Web: `device-key.ts` (WebCrypto non-extractable) + signup/login wiring | TODO — Phase A |
| Polar `payment` nishani | TODO — Polar webhook se (alag, payment no-touch) |
| Privacy/footer copy | founder ka "haan" |

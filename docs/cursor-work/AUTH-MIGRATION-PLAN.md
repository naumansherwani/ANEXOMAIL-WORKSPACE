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

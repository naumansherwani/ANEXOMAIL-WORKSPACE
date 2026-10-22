# HASHING — HMAC-SHA256 aur SHA-256: kab kaunsa, aur dono ek saath kaise (founder ka hukm 20 Oct 2026, Rule 29)

Faisla (CEO): **dono rakhte hain, alag alag kaam ke liye.** Ek saval se kaun sa chunna hai:
> "Kya input andaza lagaya ja sakta hai (email, device ki 5 nishaniyan, phone) ya hash sirf hamare liye chhupa raaz hai?" -> **HMAC-SHA256 (key ke saath)**.
> "Kya input khud lamba random raaz hai, ya hash ka maqsad hai ke KOI BHI (user/auditor) saboot parakh sake?" -> **SHA-256 (bina key)**.

## 1. HMAC-SHA256 — "kaun hai" (private, keyed)
- Kahan: device hash (`device_hash_v2`, E42), email jaisi andaza-yogya personal cheez ka hash (`email_hmac_v1`, E45 tombstone). Naye personal-data hash **hamesha** yehi.
- Kyun: sirf SHA-256 ho to koi bhi andaza lagakar (rainbow / brute force) wapas email/device pehchan sakta hai. Key ke baghair hash bekar.
- Banawat: `subkey = HMAC-SHA256(master_key, 'anexomail/<purpose>/v<n>')`, `hash = HMAC-SHA256(subkey, canon)`. Har maqsad ki alag subkey (domain separation): `device-hash/v2`, `email-hash/v1`. Version naam mein, taake badalna aasaan ho.
- Master key: server env `DEVICE_VAULT_KEY` (na ho to `anexomail-vault:<service-key ke aakhri 32>` — `server/routes/auth.ts vaultKey()`). **Key repo/DB/log mein kabhi nahi**; har call par server se `_key` parameter mein aati hai. Key badalna = naya `v<n>` + migrate function (jaisa `device_hash_migrate_v2`).
- Dual lookup (v1 SHA-256+pepper purana, v2 HMAC naya) migration ke dauran dono mein dhoondo, match par v2 mein badlo (lazy) + ek bar bulk (`device-hash-migrate.sh`).

## 2. SHA-256 (bina key) — "kya hai" (public, parakhne layak)
- **Lamba random raaz ke hash** (192-bit ticket, session/reset token): brute force namumkin, aur sirf DB se verify hona chahiye — `account_export_tickets.token_hash`.
- **Content ki sachchai**: export `manifest.json` ke har file ka sha256, `DEPLOY-MANIFEST.txt` (sha256-16), migration receipts, tamper-evident audit chain. Maqsad: user/auditor khud wahi hash nikaal kar mila sake — key hoti to woh mila nahi sakta.
- Recovery codes (60-bit, chhote): **bcrypt** (slow hash) — SHA-256 nahi (code chhota hai, tez hash par brute force ho jata).
- Passwords: Supabase Auth ka bcrypt. Hamare paas kabhi nahi.

## 3. Dono ek saath (layering)
| Cheez | Pehchan (kaun) | Saboot (kya) |
|---|---|---|
| Device record | HMAC-SHA256 `device_hash` | `sealed_signals` ka AES (pgp) — alag cheez, alag subkey ka irada (G34b) |
| Blocked account tombstone | `email_sha256` column mein **HMAC** (`email_hmac_v1`) | timeline jsonb + purge report |
| Data export | ticket: SHA-256(random 192-bit) | `manifest.json`: har file ka SHA-256 |
| Chain / ledger entry | record ka HMAC (kisne likha, chhupa) | `prev_hash` + SHA-256 chain (public parakh) |
Usool: **HMAC chhupata hai ke kaun; SHA-256 dikhata hai ke kya badla nahi.** Kabhi ek ki jagah doosra nahi, aur HMAC ka naam "sha256" column mein ho to comment mein likho.

## 4. Purana (legacy) jo abhi SHA-256 hai — rakha gaya, migrate list
- `account_deletions.email_hash` (E24): sirf service_role table, kabhi export/log mein nahi; **E46 mein HMAC** (email column se dobara bana kar) — queue mein.
- `device_hash_v1` (SHA-256+pepper): migrate ke baad v1 lookup band.
- Naya code in ko copy nahi karega.

## 5. Code review ka sawal (Rule 29 se pehle har PR)
Kya naya hash personal/guessable cheez ka hai? -> HMAC + subkey. Kya ticket/checksum/chain hai? -> SHA-256. Bcrypt sirf chhote secret ke liye.

## Identity vault (E66-E69)
Pepper wahi `DEVICE_VAULT_KEY` (fallback service-key-tail). Hash = HMAC(HMAC(key,"anexomail/identity/v1/<kind>"), canon). SQL (E68 identity_hmac_hex) = Bun (server/lib/identity-mirror.ts) = Rust (server/rust/vault_core.rs) — parity vectors CHECK_E69 + dono test files mein. **Pepper badalna = sab ban hash badalna** — pehle key_id v2 + migrate function; fallback (service-key-tail) par mat chhodein: DEVICE_VAULT_KEY set karein.

## E70 — fingerprint kinds (22-23 Oct 2026)
Five groups, each a client-side SHA-256 digest (never raw traits): fp_hw (cores, touch, platform, screen, gamut) · fp_gpu (WebGL limits/precision) · fp_font (~110-family probe) — these three are MACHINE traits, the same in any browser on the same computer — and fp_gfx (canvas, audio, WebGL strings, WebGPU, UA hints) · fp_env (time zone, languages, calendar) — BROWSER traits. The browser sends the digests to the Brain (`/api/auth/signup`), the Brain adds a server-only HMAC (pepper DEVICE_VAULT_KEY, never in the browser) and writes to Supabase through the service role. Storage: HMAC(HMAC(key,"anexomail/identity/v1/<kind>"), canon). A client can never write to the vault directly (RLS: no anon/authenticated rights).
Weak tier: a match never bans alone. >=3 of 5 groups match a banned person (fp_match_min) + one more weak signal => deny; 3 of 5 alone => HOLD (founder decides). Groups on >=25 accounts are ignored (crowd rule). Hidden fingerprint (fewer than 3 usable groups, or every group is crowd = Tor/RFP-style, or a script that sent none) => policy fp_evasion: allow | review (default) | hold. Farm: >=3 shared groups on >=4 accounts => review.
Parity vectors (key 'k'): fp_hw(a*64)=89ba8aec… fp_gfx(b*64)=4668add1… fp_env(c*64)=5208a079… fp_gpu(d*64)=ceb0b2ba… fp_font(e*64)=22b0028a… (full values in sql/proofs/E70_proof.sql). Rust vault_core parity = Auth Phase A. WASM would not add security (the client is untrusted either way); the server-side HMAC and the non-extractable device key are the real anchors.

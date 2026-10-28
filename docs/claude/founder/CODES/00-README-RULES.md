# FOUNDER CODES — ek folder, ek tarteeb (28 Oct 2026)
Yeh folder founder ke SAB code ka naqsha hai: files, endpoints, gates, mix, audit, tarteeb. Naya kaam shuru karne se pehle yahan parho.

## Faili
- 00 RULES (yeh) · 01 FILES · 02 ENDPOINTS · 03 GATES · 04 MIX-LEAKS · 05 DEEP-AUDIT · 06 ORDER

## Rules (FC = Founder Codes)
- FC1: Founder aur awam ALAG. Founder ka naya code sirf `server/founder` (Rust) + `founder-web` (React/Three) mein. Awam files mein naya founder code NAHI.
- FC2: Purani (Lovable) founder files bina founder ki ijazat ke delete/move nahi. Pehle naya founder us page ka kaam live (Chrome) dikhaye, phir purani hatao (F9 cutover).
- FC3: Founder pehchan sirf `founder_accounts` uid + local ES256 JWT (jwt_core.rs). Email-list se founder banna band; `FOUNDER_EMAILS` naye code mein kabhi nahi.
- FC4: Founder login awam login se ALAG (alag host + passkey + device approval). Awam `/auth/login` se founder access band hona hai — lekin `FOUNDER_PASSWORD` path TAB hatao jab founder passkey login live proof kar de (lock-out se bachao).
- FC5: Har founder write action = `founder_audit` hash-chain entry + wajah (>=8 akshar) + khatarnak par passkey + two-tap. Executor F8 tak 409.
- FC6: Koi dummy/mock/fake 0 nahi (Rule 63). Data na ho to `null`/`connected:false`.
- FC7: Data raasta: Supabase -> Rust (HMAC envelope) -> WebTransport/fetch -> WASM kernel -> React -> Three.js (Rule 52, 62).
- FC8: Ek waqt ek phase (Rule 64): server green + CHECK ok + Chrome live, phir agla.
- FC9: Har file badlo -> manifest-sync + verify 0 bad (Rule 28) -> push. Nayi SQL: super-advance + CHECK_<n> (Rule 38/44).
- FC10: Naya founder endpoint = sirf `/founder/v1/*` (Rust). Purane `/api/founder/*` Bun routes cutover tak sirf chalte rahenge, unmein naya feature nahi.
- FC11: Founder host sirf `founder.anexomail.com` (naya). Purana `founderworkspace.anexomail.com` cutover tak, phir band.

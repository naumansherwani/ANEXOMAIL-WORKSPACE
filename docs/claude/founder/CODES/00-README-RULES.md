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
- FC11 (BADLA 28 Oct 07:45, founder FINAL): founder host = `founderworkspace.anexomail.com`; Command Center host ke ROOT `/` par (address mein koi `/f/` NAHI — founder ko /f/ se nafrat). SPA assets `/_cc/`, API `/founder/v1/*`, login `/founderlogin`. Purana awam-app (`/app`, `/api`, `/auth`) usi host par F9 tak. `/f` aur `/f/` purane bookmark `/` par redirect.
- FC12 (founder 28 Oct 06:36): FEATURES TARTEEB SE. Har phase mein purani Lovable files ki feature list aur blueprint DONO saamne rakh kar chalna — pehle us page ki features nikalo (01-FILES, 02-ENDPOINTS), phir naye mein banao, phir Chrome live. Koi purani feature bina list ke na chhootay.
- FC13 (UI): CLUSTER NAHI. Aankhon ko aasan: ek screen = ek maqsad, kam cards, bari saaf likhai, kam rang, bohat khali jagah, ek waqt mein ek section. Admin mein SAB kuch ho (har purani feature) lekin darje se: pehle ek saaf landing/Bridge, baqi decks/menu ke peeche (progressive disclosure). 3D toggle hamesha.
- FC12 (28 Oct 06:37): Kaam hamesha purane Lovable code + blueprint dono ko saath rakh kar, features list ki tarteeb se. Koi purani feature bina "naye mein ghar" ke na choote.
- FC13: UI cluster-free: ek screen par kam cheez, bada saaf type, aankhon ko aasaan; sab kuch Admin mein (andar/search/deck), kuch gum nahi.
- FC14 (28 Oct 06:38): Jo purane code mein ACHHA hai woh intact rakho aur behtar banao (todo mat). Frontend duniya ki sab se advance technology par; sab kuch usi mein.
- FC15 (28 Oct 06:49, LOCKED): crypto/protocol design = FOUNDER-CRYPTO-FINAL-28OCT.md. Ed25519 (server->browser), HMAC-SHA256+HKDF (browser->server), SHA-256 (chain/Merkle/SRI), WASM kernel enforce. Is design se hat kar code nahi; badalna sirf founder ke likhit hukm se.
- FC16: founderworkspace host end-state mein sirf Rust (awam se zero connection). Naya code kabhi awam service/token/table-write se nahi judta.
- FC17 (28 Oct 07:14): har jawab ke aakhir mein technology ke hisaab se pull command (tail ke saath) — docs/claude/founder/PULL-COMMANDS.md se. Server par `git pull` kabhi nahi.

## FC18 (founder 28 Oct 2026 08:40) — COMMON FEATURES: user ka likha latest-technology code founder par LAGAO, lekin founder ke protocol ke andar; design alag
- Jo features user ke paas bhi hain aur founder ke paas bhi (mail, calendar, people, work, etc.) unka code latest technology par PEHLE se likha hai. Founder ke liye dobara naya nahi likhna: usay founder binary (`server/founder/`) + founder SPA (`founder-web/`) ke andar, FOUNDER PROTOCOL ke saath (founder gate, two-tap + reason + audit, metadata/rules) apply/port karo.
- MIX NAHI: founder ka design aur code user ke code se alag folder mein rahe. User/awam code (`src/`, `server/rust/`, `server/routes/`) mein founder ke liye kuch nahi badla jata (Rule 35 no-touch). Reuse ka tareeqa: pure/shared logic ko founder crate mein `#[path]` include (jaise `jwt_core.rs`) ya founder ke apne module mein port; awam file ko edit nahi.
- Founder ka look = maujooda app jaisa clean (Rule 68, FC14); 3D/cartoon nahi (28 Oct 08:34 radd).
- Har common feature ka founder-ghar blueprint 13z-c mein likha hai; banane se pehle us ka user-side code kahan hai (file/proc) pehle likho, phir port.
- FC19 (founder 28 Oct 08:56): existing + new features ek hi catalog mein, tarteeb se, har feature ka gate (G1/G2/G3) aur endpoint (/founder/v1/*) ke saath: docs/claude/FOUNDER-FEATURE-MAP-28OCT.md (generated from founder-web/src/catalog.js). Asli logo (BrandMark port) kabhi nahi hatana. Demo/design hamesha repo ke asli components se, apna banaya placeholder nahi.
- FC20 (founder 28 Oct 09:04): mojooda (purane) codes ko LATEST TECHNOLOGY par CONVERT karna hai, copy-paste nahi: Bun/express route -> Rust proc (/founder/v1/*), Lovable page -> React 19.2/Vite 8.2 SPA, polling -> push, HMAC/Ed25519/WASM kernel enforce. Har feature ka "purana kahan tha -> naya kahan" FOUNDER-FEATURE-MAP mein; purana tab hatao jab Rust==Bun saabit (Rule 56/59, FC2).
- FC21 (founder 28 Oct 09:04): AWAM implementation order (docs/claude/ONE-ORDER-27OCT.md, latest-technology migration + baaqi kaam) hamesha INTACT. Founder green hone ke baad 100% wapis wahin se: ONE-ORDER ki table mein pehla non-GREEN qadam (2b/3 deploys, phir 4, 5, 6, 7 ...). Founder kaam us tarteeb ko badalta nahi, sirf beech mein chalta hai.
- FC22 (founder 28 Oct 09:13): user ke features zyada tar founder ko BHI wohi milte hain (puri website ki cheezein same, codes pehle se likhe). Isliye founder ke liye kuch naya likhne se pehle user-side code dhundo (ONE-ORDER + ENDPOINT-PACKAGE-MAP + count-endpoints.py) aur usay TARTEEB se founder protocol mein lagao (server/founder + founder-web, `#[path]` include ya port). User wale code/design se MIX nahi: user files no-touch (Rule 35), founder ka alag folder, alag design, alag gate.
- FC23 (founder 28 Oct 09:14): PURI WEBSITE ka ek hi logo, ek hi style (same size 32px, wordmark 15px/800 platinum gradient, WORKSPACE 8px steel, same SVG gradients, Inter 400-800 font). founder-web Brand.jsx + styles.css `.wm` BrandMark.tsx / ax-platinum-text ke exact values; BrandMark badle to dono saath badlo.
- FC24 (founder 28 Oct 09:31): founder sidebar = awam sidebar ki wohi tarteeb (Dashboard, Mail, People, Calendar, Work, CRM, Org, Analytics, Safety, ANEXOChat, AI, Speed, Founder, Admin; links purane pages par), phir "COMMAND CENTER" group (Bridge, Finance, People, Mail Desk, AI, Release, Move-In, Systems, Control, Audit). Collapse button (icons-only, per-viewer localStorage). Awam ki tarteeb badle to yahan bhi saath badlo.

> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Go-to-market + capacity control (CEO, 26 Oct 2026 03:55 PKT) — docs-only, no code

Founder sawal: "user Google/Zoho chhod ke kyun aaye? main better deal kaise doon? kal 1000 org aaye to Hetzner blast na ho -- control bhi, compete bhi."

## 1. User kyun aaye — sach (honest math, landing par claim se pehle Google/Zoho ki live price verify karni hai)
- Per-user pricing: Google/Zoho per seat. Hamara flat: Basic £40/5 users (£8/user), Pro £105/20 (£5.25), Business £360/60 (£6), Business Pro £2,850/570 (£5), Business Premium unlimited. **Tiny team (1-3 log) par hum sasta NAHI -- jeet 15-570 users ki growing teams par.** Wedge = growing SME/agency/startup jo har naye bande par bill barhta dekh kar thak gaye.
- Predictable bill: users add karo, bill wohi. Overage hidden-but-fixed, bill-shock nahi.
- Bari attachment: 35/45/60/100 MB vs Gmail 25MB (Enterprise Plus 50MB), Zoho incoming 40MB. Roz ka dard.
- Shared storage pool (har bande ka alag cap nahi).
- Insaani support + Move-In migration service (one-off £568-3,350) -- switching ka dar sab se bara rukawat hai, isay hata do.
- Trust hooks (zaroori, warna koi nahi aata): full export "kabhi bhi chhodo", SPF/DKIM/DMARC auto, uptime page, "ek crash poori site nahi giraata".
- 3 claims hi landing par (Rule 51): bari file seedhi jaati, peak time par tez, ek crash poori site nahi giraata.

## 2. Hetzner ko blast hone se bachao -- asal khatre (bandwidth sab se kam)
1. **SMTP IP reputation / spam abuse** -- 1000 naye orgs mein 1-2 spammer poora IP blacklist kara dete hain. Control: signup verification, trial send caps, per-org outbound rate limit, warm-up, abuse auto-suspend.
2. **Hetzner mail policy** -- Cloud par port 25 default blocked ho sakta hai (unblock request chahiye) aur spam par account suspend ho sakta hai. VERIFY karna hai (action item) + dedicated IPs.
3. **CPU/DB spike** -- sab ek saath import/sync. Control: admission control (Tokio semaphore/backpressure), job queues, import ko throttle.
4. **Storage/bandwidth** -- sasta (~EUR 1/TB transfer, storage chhota kharcha). Hidden overage + plan caps kafi.

## 3. Controlled flood (control + compete ek saath)
- **Waves / invite-only**: har hafte N orgs (jaise 50). Capacity gate: server utilisation 70% par naye signup auto-pause ("waitlist"). Scarcity bhi hai = marketing.
- **Founding-member offer**: pehle 100-200 orgs ko price-lock (jaisa founder chahe) -- load bhi control, word-of-mouth bhi.
- **Trial caps**: storage/send/attachment/import chhote jab tak paid na ho.
- **Per-plan fair-use**: Basic/Pro throttle (overage nahi), Business+ overage bill-only.
- **Load test pehle** (k6, 1000 synthetic orgs) -- code/test ka hukm founder ka; Pro GREEN + M3 se pehle signup open NAHI (founder rule).
- **Capacity trigger rule**: DB CPU>60%, SMTP queue>N, disk>70% -> naya server order pehle, signup baad mein. Object storage app servers se alag.
- Monitoring/alerts har trigger par.

## 4. Open founder faisle
Founding-member price-lock kitna? Wave size? Move-In kya trial migration free? Google/Zoho live price landing par dikhana hai ya nahi (verify pehle)?

> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Founder vs awam Settings Center — side-by-side check (1 Nov 2026, 12:40 PKT)
Method: both accounts open in the founder's Chrome (awam https://anexomail.com/app/settings/*, founder https://founderworkspace.anexomail.com/#/settings), every tab read as text and looked at in a screenshot. Founder side was hard-reloaded (service worker + cache cleared) so the check is of the installed S1c/S1d build.

## Matches (no action)
All 15 awam rows exist on the founder side with Explain / Blast radius / History; Appearance has both blocks plus Ambient Studio; Time machine lists all 22 keys with human names; Drift measures 11 items (awam: 13 — different baselines by design); Schedule form offers all 14 schedulable keys. Real write test (Block tracking pixels on→off→on) saved, blast radius real, ledger entries proven in the browser.

## Mistakes found (each gets a fix in S1e)
| # | Where | What is wrong | Fix |
|---|---|---|---|
| M1 | Personal tab | Awam's FIRST row is "Display name" (with Explain / Blast radius / History). The founder Personal tab has no such row: the name is only editable on the separate Profile page, so Drift shows "Display name is set — Looser than baseline" while the profile shows a name (it comes from the account, not from the saved setting). | Display name row inside Personal (same door `personal.display_name`, same RowTools). |
| M2 | Settings left list | Item text starts at different x positions (Personal 383, Workspace 378, Appearance 380 …): the icon boxes shrink with the text. Looks unfinished next to the cinematic look. | Fixed icon box (flex 0 0 18px), text column aligned. |
| M3 | Live test limit | The browser tool cannot resize the real Chrome viewport (innerWidth stays 1536), so 820 / 390 are proven only in the local harness, not in the real browser. | Not a code bug. Stated honestly; the founder checks his phone / tablet, I do not claim it. |
| M4 | Drift list | Display name drift (M1) is the only non-aligned item, so the score shows 95. After M1 the founder can resolve it from Personal. | Follows from M1. |
| M5 | Founder's own account | My live write test left Animations = Reduced (his own toggle at 12:26) and Block tracking pixels toggled twice. Both are in the Time machine and undoable. | Reported, not touched. |

## Deliberate differences (not mistakes)
Founder left-list layout and cinematic look vs awam top tabs; AI settings placeholder (step 16, Rule 71); Ambient Studio; ledger entry + browser proof on every version; no Drift baseline for choices (undo window, retention, only-VIPs).

## Compare 2 — 1 Nov 13:25, live in Chrome (awam Business account tab + founder tab, dono logged in)
Founder order 13:19: "dono ke settings page side by side ek ek compare kero, jahan masla aye seedha fix kero, likh ke".
Read live (text + screenshot): awam Personal/Workspace/Notifications/Privacy/Health vs founder Personal/Workspace/Appearance/Notifications/Privacy/Time machine/Drift.
| # | Finding | Verdict |
|---|---|---|
| N1 | Rows, wording, order of the 7 tabs: awam == founder (Display name, Undo send, Send check, Home city; Retention, 2FA/passkey, external; Quiet hours, VIPs; Read receipts "Never sent", Block trackers). | MATCH, nothing to fix |
| N2 | Founder Drift shows 95/100, "1 looser": item title "Display name is set" with badge "Looser than baseline". The title states the TARGET, the badge says it is NOT met (his Display name is empty, the account name is used). Correct maths, confusing wording. | POLISH, not a bug: when state is loose the title should read "Display name is not set". UI-only (founder-web DriftCard text), next UI phase; founder can reach 100/100 by saving a Display name. |
| N3 | Founder Privacy tab has no passkey/hardware-key/recovery rows yet. | Known: phase 7-3 (after Rust 7-2). Not a defect. |
| N4 | Layout: awam = top tabs, founder = left sub-nav with one-line hints + "AI settings (founder only, step 16)". | Deliberate difference (Rule 35), kept. |
| N5 | The founder Chrome tab that was open on `/founderlogin` is the AWAM SPA login route (`src/routes/auth.tsx`) served on the founder host: it offers "Email me a sign-in link", "recovery code" and text "Rust + WebTransport · device-bound sessions". Awam WebTransport is real; but for the FOUNDER protocol a mailed link is not allowed (no OTP/link, phishing-resistant keys only) and device-bound sessions (DBSC) are 7b, not built. | NOTED for 7-4: the founder sign-in must become passkey-only and must not claim DBSC until 7b. No awam code touched (no order). |
No founder-side code changed in this compare: nothing broken was found, only N2 wording (queued) and N5 (queued for 7-4).

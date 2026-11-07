# FOUNDER PULL COMMANDS — technology/code ke hisaab se (Rule 66, founder 28 Oct 07:14)
Qaida: har jawab ke aakhir mein JIS code ka badlav hua, usi technology ki command, `| tail -N` ke saath. SERVER PAR `git pull` KABHI NAHI (working tree untracked => abort). Sab commands `fetch` + `origin/main` se.
Format: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:<SCRIPT>) 2>&1 | tail -N`

## Kaun si file badli -> kaun si command
| Code jo badla | Technology | Command (script) | tail |
|---|---|---|---|
| `docs/cursor-work/sql/E*.sql` (naya founder/DB) | **SQL** | 1) `docs/cursor-work/server/sql-run.sh` (bare = AUTO sirf naye E-files) 2) `… sql-run.sh) <E_naam> CHECK_<n>` | 25 |
| `server/founder/**` (Rust), `founder-web/**` (React/Vite SPA + dist) | **Rust founder + SPA** | `docs/cursor-work/server/founder-install.sh` (tests -> build -> SPA -> systemd -> saboot; fail = rollback) | 12 |
| `server/caddy/founder-host.sh`, `patch-founder-host.py` (founderworkspace host raaste) | **Caddy** | `server/caddy/founder-host.sh` | 12 |
| `src/**`, `server/routes/**` jo awam React app / Bun hain (jaise auth.tsx, FounderBar.tsx) | **Web (awam React + Brain)** | `docs/cursor-work/server/pull.sh` (pm2 restart khud) | 15 |
| `server/rust/**` (awam Rust engine :3200) | Rust awam engine | `docs/cursor-work/server/rust-engine-install.sh` | 15 |
| `polar-payment` | Polar | KABHI NAHI (no-touch) | — |

## ABHI PENDING (3 Nov 09:50): KOI NAHI. SQL E139, founder-install (x2) aur Web pull.sh teeno server par green hain (uske paste mile). Agla server command J6 live proof / K3 ke saath.

## Mukammal commands (copy-paste)
**SQL (bare, E-files auto):**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) 2>&1 | tail -25`
**SQL CHECK (E103 misaal):**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E103_founder_actions_english CHECK_E103 2>&1 | tail -25`
**Rust founder + SPA:**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
**Caddy (founder host):**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:server/caddy/founder-host.sh) 2>&1 | tail -12`
**Web (awam React/Brain):**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15`

## Tarteeb (agar ek hi batch mein kai technologies badli hon)
1) SQL  2) SQL CHECK  3) Rust founder + SPA  4) Web  5) Caddy (sirf jab host raaste badle).  Wajah: DB pehle (naya code naye table/column par), phir binary, phir web; Caddy aakhir. NOTE: founder SPA ka base badle to BUILD Caddy se PEHLE (28 Oct: `/_cc/` base).

## Har phase ke liye
Blueprint `FOUNDER-BUILD-PLAN-28OCT.md §11z` mein har phase ke agay technology + pull ka qism likha hai; yeh file command ka masdar hai.

## MEGA (founder 28 Oct 08:00): sab technologies ek command, tarteeb SQL -> Rust+SPA -> Caddy -> Web, fail par ruk jati hai
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/all-pull.sh) 2>&1 | tail -60`

## Rust awam cores — unit tests (28 Oct 2026, read-only, no install, no restart)
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-cores-test.sh) 2>&1 | tail -25`
Sandbox result: 40 cores ok, 619 tests passed, 1 SKIP (jwt_core needs engine crates). rust-engine-install.sh does NOT run cargo test; this script does.

| Polar read-only token (founder env, chat mein nahi) | **Polar token** | `bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-polar.sh)` (pehle fetch; token chhupa kar poochti hai; `off` se hata do) | 13 |
| `server/lib/founder-host-guard.ts`, `server/routes/auth.ts` (F1a-2) | **Awam web** + guard | 1) `pull.sh` 2) `…founder-hostguard.sh) probe` -> founder host par login -> `status` -> `enforce` | 14 |

## ABHI PENDING — copy-paste, is tarteeb se (28 Oct 2026 12:55, Settings S1 / E108; update har turn)
F2a server par LIVE hai (Chrome proof). Ab Settings S1:
1) **SQL (E108 auto):**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) 2>&1 | tail -25`
2) **SQL CHECK (6 rows true):**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E108_founder_settings CHECK_E108 2>&1 | tail -25`
3) **Rust + SPA:**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
4) **Host guard (agar baqi):** founderworkspace/founderlogin par ek baar login -> `…founder-hostguard.sh) status` -> `founder_host=true` par `enforce`.
5) **Polar Metrics token (sirf agar card "not connected" kahe):** `…founder-polar.sh) engine`
Polar webhook engine (:3400) par KUCH nahi chalta (no-touch).


## 28 Oct 12:30 — ABHI PENDING (is tarteeb se)
1. SQL (E108 dobara, purana version server par hai): sql-run.sh E108_founder_settings CHECK_E108
2. founder-install.sh (naya Settings UI + saaf error)


## 28 Oct 12:50 — ABHI PENDING (sirf 2, isi tarteeb se)
1. SQL: sql-run.sh E108_founder_settings CHECK_E108 (6 rows true)
2. founder-install.sh (naya UI + Trust + shortcuts)
(host guard / Polar token baad mein, in dono ke green hone ke baad)


## 28 Oct 13:00 — ABHI PENDING (sirf 2; poori line copy karein, 'git' se shuru)
1. SQL: sql-run.sh E108_founder_settings CHECK_E108 (6 rows true)
2. founder-install.sh (cinematic dashboard + clock wapis, naya shell)


## 28 Oct 13:20 — ABHI PENDING (1 point)
1. founder-install.sh (12-ghantay clock, label fix). E108 SQL agar abhi tak nahi chali to pehle wohi (sql-run.sh E108_founder_settings CHECK_E108).

## ABHI PENDING (28 Oct 13:25)
1. E108 dobara (fix): git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E108_founder_settings CHECK_E108 2>&1 | tail -25
2. Phir founder-install.sh.

## ABHI PENDING (28 Oct 13:30): KOI NAHI. E108 aur founder-install server par green hain. Agla server command F2b ke saath.

## ABHI PENDING (30 Oct 19:00) — 1 point
1. founder-install.sh (Settings ek jagah + Polar reject row 7-din): git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12

## ABHI PENDING (30 Oct 19:10): KOI NAHI. founder-install green. Agar Polar token dekhna ho: `...founder-polar.sh) status` (ab repo mein hai). Host guard: founderworkspace.anexomail.com/founderlogin par ek baar sign-in -> `...founder-hostguard.sh) status` (founder_host=true) -> `enforce`.

## ABHI PENDING (30 Oct 19:20) — 1 point
1. founder-install.sh (Bridge text sentence-case): git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12

## ABHI PENDING (30 Oct 19:50) — 1 point
1. founder-install.sh (T1: TypeScript + TanStack Router + Tailwind + shadcn, look wahi): git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12

## 30 Oct 19:30 — ABHI PENDING (sirf yeh ek)
Rust+SPA (L1 actions cache): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`

## 30 Oct 19:40 — ABHI PENDING (sirf yeh ek; Rust + SPA dono badle: L2, L3, Dashboard, L1)
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
Phir (founder step, L5): `/founderlogin` par ek baar login -> `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-hostguard.sh) status 2>&1 | tail -14` -> `founder_host=true` par `... enforce`.

## 30 Oct 19:50 — ABHI PENDING (sirf SPA badla: top bar)
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`

## PER TECHNOLOGY — SAB COMMANDS EK JAGAH (founder 30 Oct 19:43; Rule 66/70; har script repo mein maujood hai, 30 Oct ko check)
| Technology | Command | Abhi chalana? |
|---|---|---|
| SQL (Postgres, E-files) | `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) 2>&1 | tail -25` | NAHI (E108 green; agla E107 F2c ke saath) |
| SQL CHECK | `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E108_founder_settings CHECK_E108 2>&1 | tail -25` | NAHI (green ho chuka) |
| Rust founder + React SPA (UI + cinematic) | `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12` | **HAAN — top bar (7928c3a)** |
| Caddy (founder host) | `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:server/caddy/founder-host.sh) 2>&1 | tail -12` | NAHI (host raaste nahi badle) |
| Host guard (awam web + guard) | `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-hostguard.sh) status 2>&1 | tail -14` | HAAN, /founderlogin par login ke BAAD (L5); phir `enforce` |
| Polar token status | `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-polar.sh) status 2>&1 | tail -13` | NAHI (token SET, reader ON) |
| Awam web (React + Bun brain) | `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15` | NAHI (awam code nahi badla) |
| Awam Rust engine | `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -15` | NAHI |
| Rust cores tests (read-only) | `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-cores-test.sh) 2>&1 | tail -25` | NAHI (optional) |
| WASM kernel saboot (awam kernel, read-only) | `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | tail -10` | NAHI (founder ed25519 F2b abhi code mein nahi) |
| SAB EK SAATH (SQL -> Rust+SPA -> Caddy -> Web) | `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/all-pull.sh) 2>&1 | tail -60` | NAHI (sirf jab kai technologies badli hon) |

Naye E-file (E107 Merkle, probes, device map) aur F2b (web-wasm founder kernel) ki commands tab likhi jayengi jab unka code push hoga; abhi invent nahi (Rule 48). Server par `git pull` kabhi nahi.

## 30 Oct 20:05 — ABHI PENDING (Rust + SPA: refresh speed L11)
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`

## 30 Oct 20:25 — ABHI PENDING (F2b + font fix: Rust + SPA)
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
Agar F2b se data na dikhe (ghalti se hide): rollback = pichla commit 7928c3a ya 64956fa ka founder-install (hum Chrome mein pehle dekhte hain). Awam side (Rule 52 ek kernel): `public/kernel/anexo-kernel-0.5.0.wasm` + pin.gen.ts badle, awam `pull.sh` agli awam deploy par; E90 `kernel_release_publish('0.5.0', ...)` tab jab founder kahe (3 round).

## 30 Oct 20:35 — ABHI PENDING
1) Rust + SPA (Settings 8-tab list): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
2) L5 diagnosis (naya status: running process env + poori log files): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-hostguard.sh) status 2>&1 | tail -14`

## 30 Oct 20:45 — ABHI PENDING
1) Rust + SPA (naya Bridge icon): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
2) L5 read-only diag (kuch badalta nahi, koi secret nahi): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-hostguard.sh) diag 2>&1 | tail -20`

## 30 Oct 20:55 — L5 diag v2 (read-only)
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-hostguard.sh) diag 2>&1 | tail -24`
(logo wali founder-install pehle wali command abhi bhi pending agar nahi chali.)

## 30 Oct 21:05 — L5d status (log ka sahi ghar)
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-hostguard.sh) status 2>&1 | tail -10`
Agar [founder.host] line dikhe aur founder_host=true ho -> enforce command next (script khud lock-out se bachati hai).

## 30 Oct 21:15 — ABHI PENDING (is tarteeb se)
1) Rust+SPA (Dashboard front page + naya Bridge icon): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
2) Awam web (guard probe-log; Bun, pm2 restart khud): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15`
3) Phir /founderlogin par ek baar login, phir hostguard `status` (command upar 21:05 wali).

## 30 Oct 21:25 — ABHI PENDING (sirf yeh)
Rust+SPA (naam "Dashboard", sahi ms, Billing row, saaf tiles): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
(awam pull.sh aur founder-install 21:15 wale ho chuke. L5: ab /founderlogin par ek login, phir hostguard status.)

## 30 Oct 21:40 — ABHI PENDING
1) Rust+SPA (sidebar "User dashboard"): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
2) L5: NS menu > Sign out > /founderlogin login, phir hostguard status (21:05 wali command).

## 30 Oct 21:45 — ABHI PENDING (refresh speed + top bar + sidebar label)
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
Phir Chrome mein F5 (main naapunga). L5: Sign out > login > hostguard status (21:05 wali).

## 30 Oct 22:00 — ABHI PENDING (Rust + SPA: auth sharing, kernel early start, instant snapshot)
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
(Rust build server par hoti hai: founder-install.sh khud cargo build chalata hai; time lag sakta hai.) Phir F5 naap Chrome mein.

## 30 Oct 22:20 PKT — Dashboard plane look (UI + Cinematic CSS only; no Rust, no SQL)
founder-install.sh: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh)`

## 30 Oct 22:35 PKT — Splash loading screen (UI only)
founder-install.sh: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh)`

## 30 Oct 22:30 PKT — E109 founder live (SQL only)
1) `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) 2>&1 | tail -25`
2) `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E109_founder_live CHECK_E109 2>&1 | tail -25`

## 30 Oct 22:35 PKT — 3D layer + greeting v2 (UI only)
founder-install.sh: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh)`

## 30 Oct 22:42 PKT — profile mark fix (UI only): founder-install.sh (same command as above)

## 30 Oct 22:55 PKT — real logo + Founder blue (UI only): founder-install.sh (same command as above)

## 30 Oct 22:58 PKT — L5 v2 (4 pulls, in order)
1) SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) 2>&1 | tail -25` then `... sql-run.sh) E110_founder_host_proof CHECK_E110 2>&1 | tail -25`
2) WEB (awam): the usual `pull.sh` (restarts anexomail-web)
3) RUST+UI: founder-install.sh (command above)
4) status: `... founder-hostguard.sh) status 2>&1 | tail -20`

## 30 Oct 23:05 PKT — greeting v3 (UI only): founder-install.sh (same command as above)

## 1 Nov 05:10 PKT - greeting: NOTHING to pull (v3 reverted to v2, server already has v2). The 23:05 greeting-v3 install above is cancelled. Pending pulls are only the L5 v2 sequence (22:58 section).

## 1 Nov 05:25 PKT - UI only: founder-install.sh (same command as above) = top bar title removed, date under clock. L5 v2 steps 1,3 and 4 DONE by founder; only awam pull.sh then hostguard enforce remain.
- 1 Nov 05:30: install founder-install.sh once = top bar title removed + date under clock + g fix.
- 1 Nov 05:35: greeting/top-bar/g-fix installed by founder; nothing pending except L5 pull.sh + enforce.
## 1 Nov 05:55 PKT - N1 done by founder (pull.sh + enforce). Remaining proof = founder test at anexomail.com/auth + status. Next Claude build: 4b-1 after founder answers (tick 5 s? Dashboard first?).
## 1 Nov 05:55 PKT - L5 open (see SERVER-STATE). Repo has auth.tsx founder redirect; awam pull.sh needed. Do not tell founder L5 is green.
## 1 Nov 06:10 - NO pull for auth.ts: Brain needs its own brain-*-install.sh (not built yet).
## 1 Nov 06:35 PKT - 4b-1: founder-install.sh only (Rust /founder/v1/live + Dashboard 'Live feed' card). No SQL. Then Claude checks Chrome.
- 1 Nov 06:25: founder-install for 4b-1 DONE by founder. Nothing pending to pull.
- 1 Nov 06:30: nothing to pull. Next pull = founder-install.sh after 4b-2 code.
## 1 Nov 07:00 PKT - 4b-2: founder-install.sh only (Rust: live tick + /founder/v1/live/stream). No SQL, no UI change.
- 1 Nov 06:40: 4b-2 founder-install DONE by founder. Nothing pending to pull until 4b-3 code.
## 1 Nov 07:20 PKT - 4b-3 (UI + kernel verify of SSE frames): founder-install.sh only. No SQL, no Rust change.

## 1 Nov 08:30 PKT — 4b-3 + 4b-4 (SQL pehle, phir Rust+SPA). Founder ke liye 2 commands:
1) SQL (E111 + CHECK): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E111_founder_channels_telemetry CHECK_E111 2>&1 | tail -25`  (9 ok = t)
2) Rust + SPA: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh)`  (4b-3 UI + 4b-4 Rust/UI)
Rollback: env FOUNDER_TELEMETRY=off (telemetry writes band; registry + snapshot_v2 chalte rehte hain).

## 1 Nov 07:05 PKT — 4b-3 + 4b-4: SERVER PAR INSTALLED + Chrome GREEN. Pull: koi pending nahi. Agla pull step 5 ke baad.

## 1 Nov 07:50 PKT — 4d P1 (E112 SQL ready in repo; Rust+UI to follow). Pull order when complete: 1) sql-run.sh E112_founder_inbox CHECK_E112  2) founder-install.sh. Founder ko abhi kuch chalana nahi (code poora hone par ek message).

## 1 Nov 08:10 PKT — 4d P1 COMPLETE (E112 SQL + Rust inbox endpoints + Dashboard Inbox card + chip fix). Founder ke liye 2 commands, is tarteeb se:
1) SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E112_founder_inbox CHECK_E112 2>&1 | tail -25`  (10 ke 10 OK)
2) Rust + SPA: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh)`  (81 tests)

## 1 Nov 07:40 PKT — 4d P1 SERVER PAR INSTALLED + GREEN. Koi pull pending nahi. Agla pull P2 ke baad (sql-run E113 phir founder-install).

## 1 Nov 07:45 PKT — UI cleanup (user-app sidebar group + Stream health card removed, telemetry default off). Pull: sirf founder-install.sh: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh)`

## 1 Nov 07:50 PKT — copy fix (live numbers, no empty-state words). Pull: sirf founder-install.sh (same command as 07:45).

## 1 Nov 08:00 PKT — Founder Workspace sidebar group + bun.lock removed. Pull: sirf founder-install.sh (same command).

## 1 Nov 08:20 PKT — Mail (not Mail Desk) naming fix + docs. Pull: sirf founder-install.sh (same command).

## 1 Nov 08:30 PKT — real counts wording (Bridge "N of N checks passing", Channels "Wiring next: ..."). Pull: sirf founder-install.sh (same command).

## 1 Nov 08:50 PKT — E107 founder audit Merkle (step 5, SQL, 830 lines, idempotent). Pull: PEHLE SQL, phir kuch nahi (Rust/UI agla phase).
```
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E107_founder_audit_merkle CHECK_E107 2>&1 | tail -25
```
Kitni baar: sql-run.sh sha ledger mein likhta hai, wahi file dobara nahi chalti; file idempotent hai (dobara chale to bhi safe). Edit karna ho to nayi E-file.

## 1 Nov 08:45 PKT — PULL COMMANDS TABLE (har technology ki ek command; kab kaun si)
| # | Kab | Command (har ek `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/<script>)`) |
|---|---|---|
| 1 | Naya SQL (E-file) | `<script>` = `sql-run.sh` (bina naam = auto; ya `sql-run.sh) E107_founder_audit_merkle CHECK_E107`). Ek file ek baar (sha ledger), idempotent |
| 2 | FOUNDER side (Rust `anexomail-founder` + SPA) | `founder-install.sh` — YEH aap ki founder lane. Na pm2, na Bun/Node |
| 3 | AWAM Rust engine (pm2 `anexomail-rust` :3200) | `rust-engine-install.sh`; sirf jab awam Rust modules badlen. 1 Nov 08:40 paste: 32 modules OK, kuch nahi badla |
| 4 | AWAM Rust restart | `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health` — sirf jab #3 ne "build/restart" kaha |
| 5 | AWAM web | `pull.sh` — **BUN BANNED (founder 1 Nov 08:42): founder ko yeh command KABHI nahi di jaye gi.** Awam site abhi isi lane par chal rahi hai, isliye file repo mein hai; usay Bun/Node se nikalna ek alag migration phase hai (founder ke order se, master order mein jagah milne par). Tab tak awam par koi badlav nahi |
FOUNDER ke liye aaj sirf #1 aur #2. Step 5 (Merkle): SQL E107 DONE (green); Rust/kernel/UI phase = #2.

## 1 Nov 08:55 PKT — step 5 Rust + UI (5R + 5a): Merkle core, 5 routes, auto-seal, Dashboard "Ledger seal" card. Pull: sirf founder-install.sh (same command). E107 SQL pehle se green.

## 1 Nov 08:58 PKT — founder-install fix: merkle_core.rs ab installer stage karta hai. Pull: wahi founder-install.sh dobara.

## 1 Nov 09:00 PKT — step 5 GREEN (server + Chrome). Koi nayi pull command nahi. Agla phase 5K ke liye alag command aayegi.

## 1 Nov 09:32 PKT — 5K (kernel merkle@1 0.6.0 + Dashboard browser proof). Pull: sirf founder-install.sh. NOTE: awam site 0.5.0 par rahegi jab tak awam web pull (banned lane); kernel-check.sh us tak mismatch dikhaye = expected.

## 1 Nov 09:35 PKT — 5K server par GREEN. Koi nayi pull command nahi. Agla phase (step 6 S2): pehle design note, phir SQL (sql-run.sh) aur founder-install.sh.

## 1 Nov 09:50 PKT — N menu (Audit ledger hata, email poora). Pull: sirf founder-install.sh. (Optional read-only TLS check: openssl s_client line in FOUNDER-TECHNOLOGY-ADOPTION-30OCT.md)

## 1 Nov 10:00 — no new pull. This turn is docs only. Day-to-day remain sql-run.sh and founder-install.sh. pull.sh stays BANNED.


## 1 Nov 10:30 — E113 (step 6 SQL: Time machine, Drift, Scheduled changes). Technology: SQL only. Run:
```
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E113_founder_settings_timemachine CHECK_E113 2>&1 | tail -25
```
Expect: selftest OK, selftest2 OK, crosscheck OK, 14 rows all `t`. No restart, no pm2, no Bun.

## 1 Nov 10:35 — E113 RERUN (first run failed in my crosscheck, fixed; file is idempotent). Technology: SQL only, same command:
```
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E113_founder_settings_timemachine CHECK_E113 2>&1 | tail -25
```

## 1 Nov 10:45 — E113 RERUN #2 (selftest passed on the server; selftest2 failed: Supabase default ACL gave service_role full rights on the new tables; fixed with explicit revoke). SQL only, same command:
```
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E113_founder_settings_timemachine CHECK_E113 2>&1 | tail -25
```

## 1 Nov 10:55 — Step 6 Rust + UI (Settings S2). Technology: Rust (axum) + React-TS SPA. Run (E113 is already green):
```
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh)
```
Expect: tests 105 passed, build OK, saboot 4/4 OK. Then say "founder side kholo" and I check the Time machine and Drift & schedule tabs in Chrome.

## 1 Nov 11:00 — no new pull. Step 6 Rust+UI already installed (founder paste: 105 tests, 4/4). Next pull comes with S1b (SQL E114 via sql-run.sh, then founder-install.sh).

## 1 Nov 11:06 — SPA label fix (AI settings: "founder only, built last (step 16)"). Technology: React-TS SPA. It ships with the next founder-install.sh (S1b); no separate pull needed today.

## 1 Nov 11:15 — no new pull. Docs only (awam settings list) + E114 draft not yet ready to run. Next pull = sql-run.sh E114 when green locally.

## 1 Nov 11:40 — SQL E114 (S1b: registry + Appearance keys + Ambient Studio catalog). Technology: SQL. Run once, then paste the output:
```
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E114_founder_appearance_ambient CHECK_E114 2>&1 | tail -25
```
Expected: "E114 selftest OK", "E114 selftest2 OK", "E114 ambient looks in the catalog: 301989888000", CHECK_E114 = 14 rows all t. Needs E113 already run (it is). Rust + UI for S1b follow only after this is green.

## 1 Nov 11:26 — E114 DONE by the founder (green). No new pull until the S1b Rust + UI is ready (then founder-install.sh).

## 1 Nov ~12:00 — S1b Rust + SPA (technology: Rust axum + React/TS + CSS). One command (tests -> build -> SPA -> systemd -> saboot; fail = rollback):
```
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12
```
Expected: 116 tests OK, build OK, saboot OK. Then hard-reload the founder site -> Settings -> Appearance.

### S1b polish (SPA only)
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`

### S1b polish diagnosis (read-only)
`ls -la /opt/anexomail-founder/web/assets/; grep -o "index-[A-Za-z0-9_-]*\.\(js\|css\)" /opt/anexomail-founder/web/index.html; pm2 ls | grep -i founder`

### S1c (E115 + Rust + UI) — two commands, in this order
1. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E115_founder_settings_s1c CHECK_E115 2>&1 | tail -20`  (needs E114 already run: it is)
2. Rust + SPA: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`

### S1d (E116 + SPA) — two commands, in this order
1. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E116_founder_drift_value_rule CHECK_E116 2>&1 | tail -20`
2. SPA: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`

_(12:30 note: E116 was corrected after its first server run failed; run the S1d SQL command above again — the file on origin/main is the fixed one.)_

### S1e (SPA only: Display name row + nav alignment) — one command
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`

### Step 7 phase 7-1 (E117, SQL only) — one command
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E117_founder_passkey_stepup_recovery CHECK_E117 2>&1 | tail -20`

### Step 7 phase 7-1b (E118, SQL only) — one command
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E118_founder_chairman_protocol CHECK_E118 2>&1 | tail -20`

### Landing footer 'Built with' (Website / React, awam) — one command
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15`

### Read-only server check (changes nothing): awam wtransport/quinn version + TLS of the founder host — one command
`grep -A1 -E 'name = "(wtransport|quinn)"' /opt/anexomail-rust/Cargo.lock; echo ---; openssl s_client -connect founderworkspace.anexomail.com:443 -tls1_3 </dev/null 2>/dev/null | grep -E "Protocol|Cipher|Verification|Server Temp Key"`

### T256-0 read-only inventory (changes nothing) — one command
`ss -tulpn | grep -E ':(80|443|8443|3443)\b'; echo ---; haproxy -vv 2>/dev/null | head -3; echo ---; find / -type d -path '*caddy/certificates' 2>/dev/null | head -3`

### T256-1 (founder AES-256 terminator) — ONE command at a time, in this order
**1 — SQL (E119 posture ledger):**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E119_founder_tls_posture CHECK_E119 2>&1 | tail -20`
**2 — Rust (tls256 + prober + /founder/v1/tls), after 1 is green:**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -25`
**3 — Server ops (test port 8443; dry run first, nothing changes):**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-tls256.sh) 2>&1 | tail -25`

## 2 Nov 03:50 - G4 ledger gauge hardening (E120). ONE command at a time, in this order
**1 - SQL (E120):**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E120_founder_ledger_gauge_hardening CHECK_E120 2>&1 | tail -20`
**2 - Rust + SPA, after 1 is green (122 tests):**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -25`
**3 - Chrome:** Ctrl+Shift+R on the Dashboard. "Ledger seal" must show "full check ... entries intact" within ~2 minutes and "N of 7 entries proven in this browser".
**Awam files (W2):** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15`

## 2 Nov 04:50 - G5a consistency proofs (E121 + Rust 132 tests + kernel 0.7.0 merkle@2). ONE command at a time, in this order
(G4 first: the E120 command above must already be green, because G5a's browser check sits on the same gauge.)
**1 - SQL (E121):**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E121_founder_audit_consistency CHECK_E121 2>&1 | tail -20`
**2 - Rust + SPA + kernel 0.7.0, after 1 is green (132 tests):**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -25`
**3 - Chrome:** Ctrl+Shift+R. On the first visit after this the gauge pins the seal; after the next automatic seal (every 50 entries) it must say "the kernel proved the ledger up to entry N extends it unchanged (RFC 9162)".
Note: the awam site keeps serving kernel 0.6.0 until its own pull (Rule 52 pin follows, ONE-ORDER A9).

## 2 Nov 04:20 - FINAL order for G5a (review fixes included). G4 (E120) is already GREEN on the server (CHECK 4/4, 04:00). ONE command at a time:
**1 - SQL E121:** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E121_founder_audit_consistency CHECK_E121 2>&1 | tail -20`  -> 3 rows OK
**2 - Rust + SPA + kernel 0.7.0 (134 tests):** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -25`  -> "134 passed", "OK - founder service zinda"
**3 - awam (he runs it himself; brings kernel 0.7.0 + the pin):** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15`

## 2 Nov 04:20 — founder-install fix (G5a)
Rust-test ne `consistency_vectors.json` mangi, script copy nahi karta tha. Ab karta hai. Dobara chalayein:
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -25`

## 2 Nov 04:35 — awam pull dobara (kernel 0.7.0 wasm ab manifest mein)
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15`
Is baar `wrote  public/kernel/anexo-kernel-0.7.0.wasm` aani chahiye. Phir: `curl -sI https://anexomail.com/kernel/anexo-kernel-0.7.0.wasm | head -1` -> 200.

## 2 Nov 04:50 — E122 ADVANCED (seal har 20 entries YA 10 minute, seal-loop se mehfooz)
Footer ko maine haath nahi lagana, wapas kar diya; awam pull ki zaroorat nahi. Sirf yeh SQL (1 line):
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E122_founder_seal_interval CHECK_E122 2>&1 | tail -14`
Isme 4 `OK` rows aani chahiye. E107 aur E120 pehle se server par hain.

## 2 Nov 05:00 — founder-install (browser proof ka path theek, SPA naya)
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -25`
Isme 134 tests passed + "OK - founder service zinda". Awam pull ki zaroorat nahi. Footer ab pull se kabhi nahi badalta (manifest se nikal diya).

## 2 Nov 05:25 — G5a ko GREEN karne ke 2 commands (ek ek karke)
1) SQL (E122 edit hui, idempotent): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E122_founder_seal_interval CHECK_E122 2>&1 | grep -v "^$" | head -14`
2) Rust+SPA (Endpoints card hata, naya build): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -25`

## G5b part 1 (2 Nov 06:30) — signed checkpoints: SQL + Rust + kernel 0.8.0. Run IN THIS ORDER, one at a time, paste each output.
1) SQL (technology: SQL). Needs E107+E120+E122. Local PG16: selftest OK, CHECK 5/5 (advanced E123: one judge, live re-verify, vkey checked against Go, signing-lag alarm, rotation chain), E107 selftest still OK:
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E123_founder_signed_checkpoints CHECK_E123 2>&1 | grep -v "^$" | head -14`
2) Rust founder + new audit-log key file (technology: Rust). Do this AFTER step 1 is pasted:
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
3) Awam kernel 0.8.0 (technology: WASM kernel, awam pin). After step 2:
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15`
What you will see after 2: within ~2 minutes the sealer signs every seal (SQL: `select public.founder_audit_signed_pulse();` shows unsigned = 0 and the active key). The Dashboard shows NOTHING new yet (the gauge text is part 2). GREEN only with your paste + my Chrome look.
Part 2 (next phase, NOT written yet): UI gauge text + TOFU pin, real-wasm test, fuzz, independent reviewer.

- 2 Nov 06:40 E123 fixed (selftest bug). Re-run step 1 (the same SQL command); steps 2 and 3 unchanged.

- 2 Nov 06:45 awam pull.sh: re-run after the manifest hash fix (kernel 0.8.0).

- 2 Nov 06:45 live proof of signing (wait ~2 min after founder-install): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E123_founder_signed_checkpoints CHECK_G5B_LIVE 2>&1 | grep -v "^$" | head -8`

## G5b part 2 (2 Nov 07:00) — ONE command (Rust+SPA, includes founder kernel 0.8.0 copy and the new Dashboard sentence):
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
Then sign in again; the Ledger seal card should say "Seal #N is signed by the audit-log key (Ed25519, checked by the kernel in this browser)". Awam needs nothing new (kernel 0.8.0 already live).

## G5b reviewer fixes (2 Nov 07:20) — run these TWO, one after the other (SQL first):
1) `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E123_founder_signed_checkpoints CHECK_E123 2>&1 | grep -v "^$" | head -14`
2) `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
Then sign in to the founder site; I look at the Ledger seal card in Chrome.

## G5c (2 Nov 08:05) — in order
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E124_founder_time_anchors CHECK_E124 | tail -25`
2. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) | tail -20`
3. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -15`

## UI fix (2 Nov 07:55) — Gates card "checking…" instead of false "not answering"
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) | tail -8` then Ctrl+Shift+R.

## Personal packages removal, step 1 (2 Nov 08:45) — awam site only (UI + Bun billing), no SQL
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -15` then Ctrl+Shift+R on anexomail.com/plans (only 4 Business cards, no Personal toggle).

## Personal removal PX0 (2 Nov 08:55) — in this order, together
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -15`
2. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) CHECK_PX0_PERSONAL_LIST | tail -40`  (read-only list; paste it back, then E125)

## Personal removal E125 (2 Nov 09:10) — together, in this order
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E125_retire_personal_packages CHECK_E125 | tail -25`
2. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) CHECK_PX0B_TEST_FOOTPRINT | tail -40`  (read-only: what deleting basic.test@ and alikhan@ would remove; then the founder says haan, then E126)

## Personal copy audit (2 Nov 08:50) — web only, Rust string changed (main.rs:338)
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -15`
(the Rust chat-message string takes effect at the next Rust rebuild; no behaviour change)

## E126 test accounts + Masood to Business (2 Nov 08:58) — one command, no pull needed (SQL only)
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E126_delete_two_test_accounts_masood_business CHECK_E126 | tail -25`

## E127 country + phones (PX2a, 2 Nov 09:15) — SQL only, no pull
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E127_signup_country_phones CHECK_E127 | tail -25`

## PX2b signx + GEO1 (2 Nov 09:40, fixed 10:05: installer now copies vault_core.rs; commands are clean one-liners, NO notes after them) - in this order, one technology each
E128 SQL: DONE (his paste 09:34, CHECK_E128 3/3 + E65 OK).
2. Rust (only the new module, restore-on-fail):
`git -C /opt/anexomail-web fetch -q origin main && MODULES=signx bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -30`
3. Caddy country wall, PLAN only (reads, changes nothing; apply is the same command ending in `apply`, only after he has read the plan):
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:server/caddy/geoblock.sh) plan 2>&1 | tail -20`
4. Caddy post-quantum check (read-only; server has openssl 3.5.5, Caddy v2.11.4):
`openssl s_client -groups X25519MLKEM768 -connect anexomail.com:443 </dev/null 2>/dev/null | grep -i "negotiated tls1.3 group"`

## PX2c sign-up UI (2 Nov 09:50) — web only (React); Rust signx already live
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15`
Then Ctrl+Shift+R and open anexomail.com/auth?mode=signup (the Personal | Business screen must be gone; Country, Mobile, red/green name check appear).
Optional, only after he read the GEO1 plan: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:server/caddy/geoblock.sh) apply 2>&1 | tail -15`

## Optional company domain (2 Nov 09:55) — Rust (wsx) then web
1. Rust: `git -C /opt/anexomail-web fetch -q origin main && MODULES=wsx bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -25`
2. Web: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -12`

## PX4 + PX5 + PX6 (2 Nov 10:25): country search, organisation optional, E129 - in this order, one technology each
1. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E129_org_optional_hardening CHECK_E129 | tail -30`
2. Rust (default organisation name): `git -C /opt/anexomail-web fetch -q origin main && MODULES=wsx bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -25`
3. Web (CountryPicker + optional name + /signup address): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -25`

## E130 fix for E129 (2 Nov 10:16) - SQL, then the same CHECK
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E130_org_report_text_cast CHECK_E129 | tail -30`

## PX7-PX8-AX9b (2 Nov 11:05) - Rust x3 (Rule 46 order), then web. No SQL this time.
1. Rust wsx (friendly errors + country mandatory): `git -C /opt/anexomail-web fetch -q origin main && MODULES=wsx bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -25`
2. Rust latency (middleware): `git -C /opt/anexomail-web fetch -q origin main && MODULES=latency bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -25`
3. Rust passkey (no username): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-passkey-install.sh) 2>&1 | tail -25`
4. Web: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -25`

## RETRY + GEO1 + mailboxes (2 Nov 11:20) - in this order, one technology each
1. Rust latency (one anchor now): `git -C /opt/anexomail-web fetch -q origin main && MODULES=latency bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -25`
2. Rust wsx (country + friendly errors): `git -C /opt/anexomail-web fetch -q origin main && MODULES=wsx bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -25`
3. Rust passkey (proof account is picked automatically): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-passkey-install.sh) 2>&1 | tail -25`
4. Caddy GEO1 apply: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:server/caddy/geoblock.sh) apply 2>&1 | tail -15`
5. Mailboxes, PLAN first (read-only): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/mailbox-retire.sh) plan 2>&1 | tail -30`
6. Web (landing notice): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -25`

## E131 - G5d pin portability, SQL only (3 Nov 05:20) - one command, then paste the output
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E131_founder_portable_verify CHECK_E131 | tail -30`
Expect: "OK", then CHECK_E131 5 x OK, then the E65 sweep OK. (3 Nov 05:10: first run applied E131 fine; CHECK failed only because check 5 called the E124 selftest, which cannot pass while the live server holds dead anchoring jobs. Check 5 fixed, E131 itself unchanged.) Nothing else changes (additive).

## RULE (founder 3 Nov 05:00): "mujhe pull command hamesa sari do"
Every reply that touches the server lists ALL pull commands for that batch, in Rule-46 order: 1 SQL (+CHECK), 2 Rust+SPA (founder-install), 3 Caddy (only if routes changed), 4 Web (pull.sh). Mark the ones that have nothing new as "no change this time" instead of leaving them out.

## G5c repair + G5d, ALL commands by technology (3 Nov 05:30). Rule 46 order; "no change" slots are listed on purpose (founder 3 Nov 05:00)
1. **SQL** (new: E132, selftest repair): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E132_anchor_selftest_repair CHECK_E124 | tail -30`   (expect CHECK_E124 5 x OK, then the E65 sweep OK)
2. **SQL, G5d check again** (E131 is already GREEN on the server by his paste 05:20): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E131_founder_portable_verify CHECK_E131 | tail -30`
3. **Read-only probe of the outside services** (new script, writes nothing, paste ALL of it): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/anchor-probe.sh) 2>&1 | tail -80`
4. **Rust + SPA founder**: no change this time. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
5. **Rust awam / Brain**: no change this time.
6. **Web (awam)**: docs only, no change. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15`

(ran by him 3 Nov 05:49 PKT: E131 CHECK OK, E132 + CHECK_E124 OK, founder-install OK, pull.sh OK. NOT yet run: anchor-probe.sh.)

## G5c repair R1 (3 Nov 05:57 PKT) - ALL commands by technology, Rule 46 order. SQL FIRST, then Rust
1. **SQL** (new E133): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E133_anchor_pending_any_length CHECK_E133 | tail -30`   (expect 3 x OK, then E65 OK)
2. **Rust + SPA founder** (anchors.rs changed; the installer runs the 161 tests and rolls back on fail): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12`
3. **Rust awam + restart**: no change. 4. **Brain**: no change.
5. **Web (awam)**: docs only, no change. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15`
6. **Probe (still useful, read-only)**: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/anchor-probe.sh) 2>&1 | tail -80`

## RULE (founder 3 Nov 06:07): list every technology slot, but give a COMMAND only where that technology changed; write "no change" for the rest. Never repeat a SQL command when no SQL changed.

## G5c R2 (3 Nov 06:39 PKT) — only the changed technologies get a command (his rule)
SQL: no change.
Rust + SPA founder (cargo downloads p384/ecdsa on the server; 166 tests must pass):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12
Rust awam + restart: no change. Brain: no change.
Web (kernel 0.10.0 files + pins changed, so it builds):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15

## R1 proof (3 Nov 06:45 PKT) — SQL changed (E134, E135); nothing else new beyond the R2 commands above
SQL (bare = AUTO, runs E134 + E135 then CHECK_E134 + CHECK_E135):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) 2>&1 | tail -25
Order of the whole batch: SQL first, then Rust+SPA founder-install (R2), then Web pull.sh (kernel 0.10.0).

## Read the CHECK_E135 FAIL (3 Nov 06:52 PKT) — SQL read-only (CHECK_ANCHOR_JOBS lists every job that is not done + the last requeue/dead events); nothing else changed
SQL (reads only, writes nothing):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) CHECK_ANCHOR_JOBS 2>&1 | tail -40
Rust+SPA founder: no change. Rust awam: no change. Brain: no change. Web: no change.
(E134 note, 3 Nov 06:49: E134 changed after his first failed run; the bare sql-run he ran at 06:51 already applied the fixed file. Server-affecting E134 fix had no pull-commands entry at 3cd04dcd; this entry covers it.)

## R1 loophole fix (3 Nov 06:57 PKT) — SQL changed (E136, CHECK_E136); nothing else
SQL (bare = AUTO runs E136, then CHECK_E136 and the E65 sweep):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) 2>&1 | tail -25
Rust+SPA founder: no change (do NOT re-run it: it ends the browser session). Rust awam: no change. Brain: no change. Web: no change.

## R2 data step + FS1 session renewal (3 Nov 07:05 PKT) — two technologies changed
SQL (bare = AUTO runs E137, then CHECK_E137 + the E65 sweep):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) 2>&1 | tail -25
Rust + SPA founder (the SPA dist changed: session renewal; this restart ends your sign-in ONE last time - sign in again after it):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12
Rust awam: no change. Brain: no change. Web: no change.

## (3 Nov 07:14 PKT) nothing new to run: SQL no change, Rust+SPA no change (do not re-run), Rust awam no change, Brain no change, Web no change.

## G5d part 2 (3 Nov 07:36 PKT) — SQL + Rust+SPA founder changed; HELD until the FS1 renewal check (~07:55) is done
SQL (bare = AUTO runs E138, then CHECK_E138 + the E65 sweep):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) 2>&1 | tail -25
Rust + SPA founder (174 tests must pass; this is the ONE controlled restart for the FS1 test, I watch his Chrome while it runs):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12
Rust awam: no change. Brain: no change. Web: no change.

## G5d part 2 live proof (3 Nov 07:58 PKT) — SQL read-only; nothing else
SQL (reads only; run it 2-3 minutes after founder-install):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) CHECK_G5D_LIVE 2>&1 | tail -12
Rust+SPA founder: no change (already run 07:55). Rust awam: no change. Brain: no change. Web: no change.

## (3 Nov 08:00 PKT) docs only: SQL no change, Rust+SPA founder no change, Rust awam no change, Brain no change, Web no change. Nothing to run.

## G5d part 3 (3 Nov 08:15 PKT) — Rust+SPA founder and Web changed (kernel 0.11.0)
Rust + SPA founder (new wasm + vector files; tests must pass; one restart):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -12
Web (the awam site ships the same kernel pin):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15
SQL: no change. Rust awam: no change. Brain: no change.

## (3 Nov 08:17 PKT) docs only: SQL no change, Rust+SPA founder no change, Rust awam no change, Brain no change, Web no change. Nothing new to run (the two G5d part 3 commands from 08:15 still wait).

## (3 Nov 08:25 PKT) nothing new to run: both G5d part 3 commands were run by him at 08:21 (OK). SQL, Rust+SPA founder, Rust awam, Brain, Web: no change.

## (3 Nov 08:45 PKT) Rule 73 lanes + audit: docs/rules only. SQL, Rust+SPA founder, Rust awam, Brain: no change. Web: pull.sh (memory sync):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15

## (3 Nov 08:50 PKT) lovable-gold widened + migration plan: docs/tooling only. SQL, Rust+SPA founder, Rust awam, Brain: no change. Web: pull.sh (memory sync):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15

## (3 Nov 08:55 PKT) FOUNDER-INDEX (docs/tooling): SQL, Rust+SPA founder, Rust awam, Brain: no change. Web: pull.sh (memory sync):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15

## (3 Nov 08:58 PKT) I2 GREEN + Rule 74 + technology table: docs only. SQL, Rust+SPA founder, Rust awam, Brain: no change. Web: pull.sh (memory sync):
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15

<!-- 3 Nov 11:05: ABHI PENDING = none. J6 flare v2 is planned only (docs/claude/FOUNDER-FLARE-J6-RESEARCH-03NOV.md); the next pull comes with E140. -->

<!-- 3 Nov 11:25: E140 SQL is in the repo but NOT yet given to the founder as a command (comes with the Rust sender so SQL + founder-install go as one block). -->

## ABHI PENDING (3 Nov 11:50 PKT): J6 phone alerts (E140 + flare.rs + Phone alerts panel). Two points only (Rule 24).
1. SQL (E140 + CHECK_E140): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E140_founder_flare_push CHECK_E140 2>&1 | tail -14`
2. Rust + SPA (installer makes the P-256 VAPID key, starts the sender): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`
Web pull.sh is NOT needed for this.

## ABHI PENDING (3 Nov 11:40 PKT): J6 loophole fixes (E141 receipts + ack route + SSRF guard + iPhone manifest). Two points (Rule 24). E140 and the first founder-install are already GREEN on his server (his 11:30 paste).
1. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E141_founder_flare_receipts CHECK_E141 2>&1 | tail -12`
2. Rust + SPA: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`

## ABHI PENDING (3 Nov 11:58 PKT): founder-install only (1 point). SQL E141 is already GREEN (his paste 11:45). Why: the mobile/tablet CSS fix (dx.css) for the key and phone panels.
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`

## ABHI PENDING (3 Nov 12:00 PKT): none. E140, E141 and the founder-install with the mobile CSS are on his server (his pastes 11:30, 11:45, 11:57). Next pull comes with the next code (J8 lease or K3).

## ABHI PENDING (3 Nov 12:30 PKT): hardware toggle fix (E142 + readiness panel). Two points (Rule 24).
1. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E142_founder_hardware_truth CHECK_E142 2>&1 | tail -12`
2. Rust + SPA: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`

## ABHI PENDING (3 Nov 12:30 PKT): founder-install only (1 point). E142 is GREEN (his paste 12:17). Why: security headers (Permissions-Policy, X-Frame-Options, CSP manifest-src/worker-src) found missing in my live audit.
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`

## ABHI PENDING (3 Nov 12:35 PKT): two points (Rule 24). Detail: docs/claude/BLUEPRINT-LIVE-MATCH-03NOV.md. (No Polar token step: C1 is DROPPED, see 12:50 note.)
1. founder-install (header fix): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`
2. K3 (Chrome padlock), only if ufw is the firewall: `ufw allow 8443/tcp` and then I look at https://founderworkspace.anexomail.com:8443/ in Chrome.

## ABHI PENDING (3 Nov 12:45 PKT): same founder-install as the 12:35 block, now ALSO carries the J6 live-bug fix (service worker needed a Trusted Types policy). Still two points: 1 founder-install, 2 `ufw allow 8443/tcp` (K3). No Polar step: C1 was DROPPED by the founder.
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`

<!-- 3 Nov 12:50: C1 Polar token DROPPED (founder, three times). Polar goes through the existing webhook + ledger in letter O. Never offer founder-polar.sh again. -->

## ABHI PENDING (3 Nov 13:05 PKT): founder-install ONE more time (his 12:42 install is GREEN: headers + the Trusted Types fix are live, my Chrome 12:50). Why again: second J6 live bug (push worker 'no active Service Worker') fixed in Flare.tsx. K3 `ufw allow 8443/tcp` is still his second point.
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`

## ABHI PENDING (3 Nov 13:15 PKT): founder-install ONE more time (his 12:55 install is GREEN). Why: J6 live bug 3 (the door got an empty nonce: 'a field is missing or has the wrong shape') fixed in Flare.tsx + Keys.tsx. Then I click Add again and he touches his key. K3 `ufw allow 8443/tcp` is still his second point.
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`

<!-- 3 Nov 13:40: ANEXOChat chart code (phase61 SQL, plans.ts, landing text, awam main.rs ping) = AWAM side, parked: NO pull command now; it ships with the awam migration (SQL: phase13_15 then phase61 + CHECK_phase61; Rust+Web builds). Founder pending stays: ufw allow 8443/tcp (K3). -->

## ABHI PENDING (3 Nov 13:50 PKT): ANEXOChat chart (500MB / 1.5GB / 4GB + monthly quota), AWAM side, optional now (awam is parked). Rule 46 order. sql-run.sh now also finds `anexochat/sql/*.sql` (tested through the runner in a scratch DB: phase61 + CHECK_phase61 4 OK rows + E65 OK). phase61 REFUSES with a clear message if phase13_15 was never applied on that database.
1. SQL (phase61 + its CHECK): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) phase61_file_limits_quota CHECK_phase61 2>&1 | tail -14`
2. Web (plans.ts + landing text, awam site): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15`
(The awam Rust ping constant needs no build now. Founder side: K3 `ufw allow 8443/tcp` is still pending.)

## ABHI PENDING (3 Nov 13:55 PKT): ANEXOChat SQL (awam side, his Supabase), 2 points in this order. Why: phase13_15 now repairs foreign keys that point at a _legacy table and resets its policies (his 13:38 errors); phase61 has Premium capped at 21,000 users. Sandbox: fresh run, re-run and a broken-FK run all OK.
1. SQL (file engine first): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) phase13_15_file_engine 2>&1 | tail -14`
2. SQL (quota + its CHECK, 5 rows must be `t`): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) phase61_file_limits_quota CHECK_phase61 2>&1 | tail -14`
(Pasting the file in the Supabase editor works too: run phase13_15 first, then phase61. No Rust/Web pull needed for this. Founder side: K3 `ufw allow 8443/tcp` still pending.)

## ABHI PENDING (6 Nov 19:50 PKT): founder-install, THEN approve his phone. Why: (a) his desktop showed "Too many device attempts - try again in 15 minutes" because the limiter was one bucket per account and his waiting phone used up the 5 tries; now one bucket per device (Rust test + 208 tests pass). The install restarts the service, which also clears the current lock. (b) his phone (Android) shows the code 483C7C5A and waits for approval.
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`
2. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-device.sh) approve 483C7C5A 2>&1 | tail -8`  (then press "Check again" ONCE on the phone)

## ABHI PENDING (6 Nov 20:10 PKT): his install (19:42) is GREEN (token service ON, signature ENFORCED, healthz 200). The approve command stopped with "founder uid ek nahi mila" because founder-device.sh needed exactly ONE founder_accounts row. FIXED: approve/revoke now find the account from the device code. ONE point:
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-device.sh) approve 483C7C5A 2>&1 | tail -8`  (then press "Check again" ONCE on the phone)

## ABHI PENDING (6 Nov 20:25 PKT): his phone approve is OK (Chrome on Android approved 19:45). He asked for UC Browser / Opera / Firefox "sab ke liye allowed". There is no browser block in the code: EVERY browser works, each browser is its own device and is approved once with `founder-device.sh approve <CODE>`. New: the device list now names the real browser (UC Browser, Opera, Firefox, Samsung, Edge, Vivaldi...) instead of "Chrome". ONE point (SPA only):
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`

## ABHI PENDING (6 Nov 20:35 PKT): founder-install ONE more time. Why: his approved phone (screenshot 19:59) still showed "Too many device attempts" because the lock was checked BEFORE the approval; now a lock never blocks an approved device (Rust test, 209 pass). Same install also brings the real browser names (UC / Opera / Firefox...) in the device list. After it, reload the phone once; the red banner is gone and the J6 phone proof can start.
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`

## ABHI PENDING (6 Nov 20:55 PKT): founder-install ONE more time (SPA only). Why: mobile + tablet pass (his order 20:17 / 20:24): phone cards no longer cut off, settings tabs no longer overlap, Save stays in its card, 44 px touch targets on touch screens, switches keep their look. Then reload the phone and send screenshots of Home, Bridge, Settings (Personal + Appearance), Finance, People, Mail; I mark each in GREEN-LIST-06NOV.md.
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`

<!-- 6 Nov 20:45: his founder-install (mobile + tablet CSS) paste = OK. NO pull pending. His only task: reload the phone and send screenshots of Home, Bridge, Settings (Personal + Appearance), Finance, People, Mail. -->

## ABHI PENDING (6 Nov 21:15 PKT): founder-install ONE more time (SPA only), small: deck tabs (Finance, People, Mail...) become one scrolling strip on a phone (no orphan "Gates" on a 2nd row). Optional-cosmetic; his 6 phone screens are already GREEN without it.
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`

## ABHI PENDING (6 Nov 21:25 PKT): founder-install ONE more time (SPA only; this REPLACES the 21:15 block, one run brings both): deck tabs = one strip on a phone, and the device trust label ("Trusted" / "Review") is visible on a phone like on the laptop.
1. `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh) 2>&1 | tail -14`

- 6 Nov 21:30 founder UI parity: one `founder-install.sh` pull (SPA only).

**6 Nov 21:55 J8a SQL E143 (vault lease), 1 point, CHECK = 4 rows `t`:**
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E143_founder_vault_lease CHECK_E143 2>&1 | tail -14`

**6 Nov 22:10 J8a E143 v2 (replaces the 21:55 command; same command, now CHECK = 5 rows `t`):** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E143_founder_vault_lease CHECK_E143 2>&1 | tail -14`

**6 Nov 22:20 E143 re-run (upgrade fix, CHECK must be 5 rows OK):** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E143_founder_vault_lease CHECK_E143 2>&1 | tail -14`

**6 Nov 22:40 J8b Rust lease signer (1 point, Rust only, 215 tests):** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh)`
Proof after: `curl -s -o /dev/null -w '%{http_code}\n' -X POST https://founderworkspace.anexomail.com/founder/v1/vault/lease` must print 401 (door closed without token).

**6 Nov 22:50 J8a2 SQL E144 (1 point, CHECK = 4 rows OK; run AFTER E143, which is already on the server):** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E143_founder_vault_lease E144_founder_vault_lease_keysplit CHECK_E143 CHECK_E144 2>&1 | tail -16`

**6 Nov 23:00 (E143 guard fix, same single command as the 22:50 point; run it, it replaces the earlier E143 on the server):** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E143_founder_vault_lease E144_founder_vault_lease_keysplit CHECK_E143 CHECK_E144 2>&1 | tail -16`

**6 Nov 23:15 J8b2 Rust (1 point, Rust only; creates the vault master key file once; 220 tests):** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh)`
Proof after: output line `vault master: generated`, and `journalctl -u anexomail-founder -n 40 --no-pager | grep 'vault lease key'` must say ON. Never delete /etc/anexomail/founder-vault-master.key (losing it locks every vault).

**6 Nov 23:40 J8c WASM kernel 0.13.0 (lease@1), SPA only:** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh)` (one command; 220 Rust tests as before, SPA now serves anexo-kernel-0.13.0.wasm, bundle index-BAnjULmy.js).
Then the awam site must carry the SAME kernel (Rule 52, one kernel): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15` (awam keeps working on 0.12.0 until this is run; no awam screen changes).

(6 Nov 22:46 rule: shared-code changes always carry a separate awam pull.sh point; see AGENTS.md top.)

**6 Nov 23:20 AWAM point (shared kernel fix): the 0.13.0 wasm was missing from DEPLOY-MANIFEST so awam answered 404 for it (found in his Chrome). Fixed in the manifest (+ FeatureGate.tsx, app.storage.tsx from his 3 Nov order). He runs once:** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15` (expect: wrote public/kernel/anexo-kernel-0.13.0.wasm, FeatureGate.tsx, app.storage.tsx; differ=0). Founder side needs no new command.

**6 Nov 23:35 SQL point (E144 closes the issue core; CHECK_E143 5 + CHECK_E144 5 = 10 rows OK):** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E143_founder_vault_lease E144_founder_vault_lease_keysplit CHECK_E143 CHECK_E144 2>&1 | tail -18`
**AWAM point (shared kernel wasm + his 3 Nov plan text), same as 23:20, run it AFTER the SQL point:** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15`

(7 Nov 13:20: the 23:35 SQL point and the AWAM point were both run by him, outputs OK; nothing pending to pull until J8d is written.)

- 7 Nov 14:10: J8d vault lease UI written (SPA only). Command: founder-install.sh. Awam pull NOT needed. Not GREEN until live Chrome 390/820/1200+.

- 7 Nov 14:40: J8d panic lock (E145 SQL + Rust t3_execute arm + UI). Commands: sql-run.sh E143 E144 E145 (+CHECK_E145), then founder-install.sh. Awam pull NOT needed. Not GREEN until live Chrome 390/820/1200+.

- 7 Nov 15:00: his E143/E145 paste: E145 CHECK 4/4 OK, E143 selftest OK, SPA install OK (vault master exists). CHECK_E143 row 2 FAILED only because the raw panic is now (correctly) closed by E145 -> CHECK fixed. Row 5 FAIL on his DB only (sandbox passes): DIAG_E143_row5.sql asked. J8d NOT GREEN yet: row 5 + live Chrome 390/820/1200+.

- 7 Nov 15:10: CHECK_E143 row 5 FAIL cause found from his DIAG: his Postgres prints view option as security_invoker=on (my check wanted =true). Check fixed (accepts true/on/1); view itself was fine. Run CHECK_E143 again.

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

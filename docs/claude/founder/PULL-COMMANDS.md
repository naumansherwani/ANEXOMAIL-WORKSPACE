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

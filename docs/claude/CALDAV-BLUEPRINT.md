# CALDAV (#6) BLUEPRINT — founder "haan" 23 Oct 2026 07:55 PKT

**Maqsad:** user ke iPhone/Mac Calendar, Android (DAVx5), Thunderbird mein ANEXOMAIL calendar dikhe. Sach: iPhone/Mac mein CalDAV built-in hai; Android mein built-in nahi (DAVx5 jaisi app).

## Technology (TECH-MAP 0d ke mutabiq — is se bahar kuch nahi)
| Kaam | Kahan |
|---|---|
| CalDAV server (PROPFIND/REPORT/GET) | **Rust :3200** (axum 0.8, Tokio) — naya module `dav` (`dav_core.rs` pure + tests, `dav_glue.rs` axum handler) |
| app password, etag, ctag | **PostgreSQL** E80 (RLS on, service_role) |
| TLS / HTTP/3 / proxy | **Caddy** — sirf do `handle` (neeche), baaqi config ko haath nahi |
| Settings UI (app password banao/hatao) | Web (React) — sirf UI |
| Bun | is mein koi kaam nahi |

## URL map (usi host `anexomail.com`, naya host/DNS nahi)
- `/.well-known/caldav` -> 301 `/dav/` (Caddy)
- `/dav/` -> OPTIONS/PROPFIND = principal discovery
- `/dav/p/` current-user-principal; `/dav/p/home/` calendar-home-set
- `/dav/c/<calendar_key>/` ek calendar collection (calendar_key = user ke "alag calendars" E58; default `personal`)
- `/dav/c/<calendar_key>/<event_id>.ics` ek event

## Auth (iPhone/DAVx5 web login/passkey nahi kar sakte)
HTTP **Basic**: username = user ka email, password = **app password**. Format `xxxxx-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx` (base32 a-z2-7, 30 akshar = 10 token_id + 20 secret = 100 bit). DB mein sirf `token_id` + `sha256(pepper||secret)`; asli chaabi sirf ek baar dikhti hai. 10 chaabi/user, label, revoke, 8 ghalat = 15 min lock, har request par org_members.status='active' dobara (revoked member usi pal band). Constant-time compare. Koi plaintext log nahi.

## Phase C1 (ab) — sirf PADHNA (read-only)
OPTIONS, PROPFIND (depth 0/1), REPORT (calendar-query time-range, calendar-multiget), GET .ics. Recurring: master `RRULE` + `EXDATE` + exception rows (`RECURRENCE-ID`) — client khud expand karta hai. etag = `"<id>-<dav_rev>"`, ctag = `caldav_org_state.ctag`. PUT/DELETE/MKCOL/PROPPATCH = **405 + `Allow` header** (jhoota success kabhi nahi).
## Phase C2 (baad) — likhna
PUT/DELETE (If-Match etag, 412 conflict), recurring exception mapping, sync-collection (RFC 6578) + change feed, VTODO nahi. Pehle C1 live GREEN.

## Sach ke qaide
- Koi "native iOS/Android" ka daawa nahi: iOS/macOS built-in, Android DAVx5.
- Time zone: event ke `tz` (IANA) + VTIMEZONE (UTC offset wala, DST ke saath) — floating time nahi.
- Attendee/organiser: iTIP mail C1 mein nahi bheji jati (read-only).
- Private/hold events org ke ussi rule se jaise web calendar dikhata hai (events_between wali logic reuse).

## Caddy (founder "haan" mein shamil) — SURGICAL
`caddy-caldav.sh` (plan default / MODE=apply): backup -> `/.well-known/caldav` redirect + `handle /dav/*` -> `reverse_proxy 127.0.0.1:3200` ko `handle /rpc/*` se pehle jodna -> `caddy validate` -> reload -> test (`OPTIONS /dav/` = 200 + `DAV: 1, calendar-access`) -> fail par purani Caddyfile wapas. `protocols h1 h2 h3` ko chhua nahi jata.

## Test
Rust `dav_core` standalone tests (XML request parse, multistatus escape, etag, basic-auth parse, href parse, VEVENT/VTIMEZONE, time-range), SQL proof 31 asserts (E80_proof), live: `curl -X PROPFIND` + iPhone/DAVx5 (founder phone).

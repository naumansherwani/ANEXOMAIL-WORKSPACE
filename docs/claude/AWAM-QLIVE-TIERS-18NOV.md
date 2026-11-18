# AWAM SIDE: LIVE MAIL PACKAGE LIMITS, INCLUDING BUSINESS PREMIUM AND BUSINESS MAX (his 18 Nov 2026 06:4x order: "business premium aur business max ke codes awam side likhna hai")
THIS FILE IS AWAM BLUEPRINT ONLY. Founder and awam are NEVER mixed: the founder pull command (founder-install) and the awam pull command (pull.sh) are two separate commands, always given as separate numbered points; an awam file is frozen until the awam turn (docs/claude/FOUNDER-AWAM-SEPARATION-LAW-14NOV.md).

## 1. The numbers (one source of truth: SQL `fmail_tier_limits187`, E187; the founder Rust copy `stream_tier.rs` PARSES that SQL in a test, so it cannot drift; awam will copy the same pattern)
| Package | Live streams per account | Change log kept (days / rows) | Status |
|---|---|---|---|
| Basic | 1 | 3 / 2 000 | build first |
| PRO | 2 | 7 / 5 000 | build first |
| Business | 5 | 14 / 20 000 | build first |
| Business PRO | 10 | 14 / 20 000 | build first |
| Business Premium | 25 | 30 / 50 000 | CODE WRITTEN AND PRESERVED (built = false: admission refuses it with `tier_not_built` until the package is built) |
| Business MAX | 100 | 30 / 100 000 | CODE WRITTEN AND PRESERVED (built = false, same rule) |
Founder lane: 20 streams, 14 days / 20 000 (its own package, never an awam row).

## 2. What exists today (founder side, written 18 Nov 2026)
- SQL E187 table with all 7 rows (Premium and MAX with built = false), service_role read-only.
- Rust `stream_tier.rs`: `Tier` (all 7), `Limits`, per-ACCOUNT `Registry::admit` (RAII slot, idle account leaves no map entry), `Denied::{Limit, NotBuilt}`, 6 unit tests, one of which parses E187.
- Research behind it: Dovecot `mail_max_userip_connections` refuses a new login at the limit; Stalwart has per-account concurrent limits; Gmail caps IMAP at 15 per account. Lessons applied: per account (not global), refuse at admission with a clear reason, never evict behind the user's back (two tabs would fight in a reconnect loop), RAII release so a dead tab never leaks a slot, the refused browser keeps its 5 s read.

## 3. What the AWAM turn must do (its own numbers, gate and pull command; nothing is run now)
1. Its own SQL number (awam series, never an E-number of the founder lane): the same four things as E187 (per-mailbox hash-chained change log, doors, tier table, selftest) on the AWAM mailbox tables, with the awam packages as tier values.
2. Its own Rust admission: copy `stream_tier.rs` into the awam server crate with the tier read from the account's package (never from the browser), Premium and MAX flipped to built = true ONLY when those packages ship (a one-line change in the SQL row and the Rust table, caught by the parse test).
3. Browser: reuse the pure module `mail_change.ts` through the awam-inherits-founder-tech law (pure modules + awam glue); awam gets its own gate check, its own plan section and its own pull command.
4. Proof: the same simulation test (`founder-web/sim/mail_live.sim.test.ts` pattern) against the awam `live()`.
5. Business Premium / MAX extras to decide with him when those packages are built: higher stream caps are the only difference in this feature (25 and 100), the log keeps 30 days.

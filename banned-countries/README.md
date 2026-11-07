# banned-countries
ANEXOMAIL is not available in: **Afghanistan (AF, +93), Israel (IL, +972), North Korea (KP, +850), Syria (SY, +963)**. Founder order 7 Nov 2026.
`banned.json` is the single list. Copies that must match it (tests fail on drift): `server/rust/signx_core.rs`, `src/lib/countries.ts` (awam), `founder-web/src/banned.ts` (founder), `server/caddy/geoblock-gen.py` (network wall), `docs/cursor-work/sql/E146_founder_banned_countries.sql` (SQL decision for the founder alert number).
To add a country: edit `banned.json` first, then every copy above, then run the tests. Awam and founder keep their own copies (Rule 73: no shared imports between the two lanes).

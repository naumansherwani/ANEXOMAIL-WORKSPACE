- [ ] Implement actual Rust SFU media forwarding binary for Phase 31A
- [ ] Add AV1→VP9→H.264→VP8 codec ladder and 3-layer simulcast
- [ ] Add Opus DTX/FEC SDP settings
- [ ] Add truthful P2P/TURN relay badge UI
- [ ] Add Phase 31A features to Business, Business Pro, AI Pro, AI Business, AI Executive package cards
- [ ] Verify Phase 31A and re-check roadmap
- [ ] Phase 31B translation layer: wrap public site pages (landing, plans, security, ownership, move-in, anexochat, auth, footer) with t()
- [ ] Phase 31B: wrap /app/* workspace panels with t()
- [ ] Phase 31B: run server/i18n/translate.py on Hetzner for all 29 locales, review RTL output

## WIRE (sirf copy-paste — koi edit nahi)
- [x] docs/wire/01-sql-all.md — ek command se saari 59 SQL apply (`bash sql/apply-all.sh`)
- [x] docs/wire/02-sql-phase-by-phase.md — har phase ka apna copy-paste command
- [x] docs/wire/03-verify.md — DB verify (tables · functions · RLS · GRANT)
- [ ] SERVER: apply-all ka output GREEN=59 RED=0
- [ ] SERVER: verify.sh ka output — RLS OFF = 0, NO GRANT = 0
- [ ] NEXT: frontend + Caddy, founder side, ANEXOChat, ANEXOVideoCall — isi copy-paste format mein
- [ ] SQL runner: shared DB failure ko 59 jhoote RED ki bajaye preflight par rokna aur asli error foran dikhana


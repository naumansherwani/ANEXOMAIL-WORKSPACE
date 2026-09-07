# Roadmap

- [x] Keep existing anexomail.com Polar webhook untouched
- [x] Complete polarpayments.anexomail.com as a second independent ingress
- [x] Add HTTP/3 verification that works when local curl lacks HTTP/3
- [x] Restore every former aiemail founder surface inside founderworkspace in the original order
- [x] Verify routes and deployment instructions
- [x] Fix Polar self-test for both legacy and Standard Webhooks secrets
- [x] Correct payment diagnostic SQL and document exact Polar event selection

- [x] Accept separate Polar signing secrets for primary and backup webhook endpoints
- [x] anexovideocall.anexomail.com Caddy ingress (HTTPS 200) + repo-managed site blocks deploy script
- [x] Phase 13/14/15 file engine: versioning, chunk integrity, resumable 5GB (Rust primary + Bun fallback)
- [x] Phase 16/17/18 file truth + self-hosted safety (evidence chain, no external API)
- [x] Phase 19/20/21/22 device safety vault, device trust revoke, safety reporting queue, message→work execution chain
- [x] Phase 23 promise recovery engine (human-only recovery actions, append-only ledger) + device ban appeals
- [x] (non-phase guard, out of blueprint order) Account integrity: one-account ladder (flag -> written final warning -> human block), device-only bans, 72h export before purge
- [x] Phase 24 decision ledger + decision impact map (message provenance + body_hash, versioned history never overwritten, human-only impact links)

- [ ] anexomail.com 502 (frontend PM2) confirm green

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
- [ ] anexomail.com 502 (frontend PM2) confirm green

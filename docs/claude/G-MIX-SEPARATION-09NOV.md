# G-MIX: the awam app must never open on the founder host (09 Nov 2026 23:31 PKT)
Founder law (9 Nov 2026): founderworkspace.anexomail.com NEVER shows the old awam workspace; awam lives only on anexomail.com/auth.
FACT: the old Bun/Lovable app still answers the founder host for /founderlogin, /app*, /api/*, /assets/* (Caddy routes, and fproxy.rs when the Rust terminator owns :443). It is one SPA, so /app shows the awam dashboard.
## Stage 1 (CODED 09 Nov 2026 23:31 PKT, Rust fproxy.rs, 5 tests pass)
awam_redirect(): /app and /app/* -> 302 / (our Command Center); /auth* and /signup* -> 302 /founderlogin; Alt-Svc clear, no-store. Applies in the Rust terminator only.
Open question for the real host: who owns :443 for the founder host today, Caddy or the Rust terminator? Proof line: curl -sI https://founderworkspace.anexomail.com/app  (302 + Location: / = Rust, 200 = Caddy still routes /app: then a Caddy change via founder-host.sh, Caddy law + port red line).
## Stage 2 (NOT built)
Native founder sign-in inside founder-web + Rust (/founder/v1/login: password via the identity service, passkey step-up F1, recovery code, email link; token refresh /founder/v1/refresh replacing /api/auth/refresh). Then fproxy upstream removed from the founder host, the old app serves anexomail.com only. Needs: design, his go, rollback (the old login stays until the native one is proven GREEN on 390/820/1200).
## GREEN rule
G-MIX is GREEN only when: /app on the founder host never returns the awam dashboard (curl proof + my Chrome), AND after stage 2 the founder login works with no request to the old app.

# WEBSITE PROMISES (founder Nauman Sherwani, 17 Nov 2026 04:11): "what I write on the website, I deliver. It is my promise."
Rule: every security or technology sentence that appears on a page or footer is a PROMISE. It is written only with its proof, or it is listed here as OPEN with the exact work that closes it and nothing public says it before that. A promise is never deleted to hide a gap; it is closed by work.

| # | Sentence | Where | State | Proof / what closes it |
|---|---|---|---|---|
| P1 | Connection secured: TLS 1.3 only, AES-256-GCM only. | FOUNDER login page + footer (founder-web/src/tls_line.ts) | WRITTEN, delivered on founder :443 | E119 :443 rows (9 Nov 15:52): aes256_only=ok, aes128_only=refused; his install of this build + my live Chrome look still to be recorded |
| P2 | Same sentence, awam wording | AWAM login page + SiteFooter | OPEN PROMISE, not on the live site yet | needs K5b: awam on the Rust AES-256 terminator (today awam = Caddy HTTP/2); then his read-only openssl check (AES-128 refused, TLS 1.2 refused), then the line goes into src/routes/auth.tsx and SiteFooter.tsx, awam command given separately |

| P3 | Managed Move-In: GBP 568 / 1,670 / 2,210 / 3,350 one-off, priced by mailbox count 1-5, 6-15, 16-29, 30+. We move the whole company off your old provider and prove your domain is green. | AWAM landing page (his words 21 Nov 06:43; price CLOSED for ever 21 Nov 07:03: matches Polar) | OPEN PROMISE until R4 delivers it | R4 proof report: mailbox count, migration result, DNS green check, test send/receive, cutover time |
| P4 | Priority Support: GBP 790 / month. A named founder contact, a response within 2 business days, and a quarterly service and security review. | AWAM landing page | OPEN PROMISE until R4d | R4d mailbox + SLA clock (2 business days) + quarterly review record; terms (hours, emergency cover, included company/users) to be written first |

| P5 | Admin Desk login page: "Built on: Rust · Tokio · axum · Rust WASM kernel · WebAuthn passkeys · Three.js". | Admin Desk /adminlogin | PROVEN in code (server: admin-desk/server/src/main.rs Rust+Tokio+axum; page: DeskTelemetry kernel state, DeskSignIn WebAuthn detection, DeskScene Three.js); passkey ceremony itself arrives R3a2 (the page says only 'optional') | no HTTP/3, AES-256 or X25519MLKEM768 text on the Desk page until stage 2 + his openssl proof |
| P6 | Admin Desk motto: "Our engine runs in milliseconds; our support should too. Own the issue, fix the root, leave zero open loops." | Admin Desk landing + /adminlogin | OPEN PROMISE until R3f | R3f SLA engine: first-response clock, one owner per issue, an issue closes only with a root-cause note (no open loop); measured response times shown in the Desk |

When a new line is added to any page, add its row here in the same commit.

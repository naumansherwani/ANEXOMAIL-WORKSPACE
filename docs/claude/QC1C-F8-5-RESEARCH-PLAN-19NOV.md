# QC1c F8-5: loosen "send only if TLS" for a while (19 Nov 2026 12:45 PKT, his order 12:34)

His word: web research, features list, advance frontend + backend engine, codes, close the phase, then QC1e (discuss first).

## Research (sources checked 19 Nov 2026)
- RFC 8689 SMTP REQUIRETLS: TLS can be required per message and hop by hop; a mail marked "TLS-Required: No" is the only legal way to relax it. Our rule: the relax is NEVER per message and never silent, it is a timed, signed, ledgered founder act. (https://datatracker.ietf.org/doc/html/rfc8689)
- Exchange Online connectors now offer MTA-STS and DANE modes; Google Workspace has a per-domain "require TLS" rule. Both treat a validated policy (MTA-STS enforce, DANE) as stronger than any admin loosening. Ours does the same: hop_requires_tls keeps enforce/DANE TLS-only even when loosened. (https://mc.merill.net/message/MC1220759, https://knowledge.workspace.google.com/admin/gmail/advanced/send-email-over-a-secure-tls-connection)

## Feature list (all built in this step)
1. Strict by default, always on (F8-4, done).
2. Loosen 1/4/12/24 h, written reason 8-200, max 3 per 24 h, self-expiring.
3. The passkey SIGNS THE EXACT CHANGE (mailbox, hours, reason, nonce): begin/finish pair like D2b-5, kernel re-derives the digest before the key is touched (Rule 52).
4. Server dry run before the touch: refused early (limit reached, bad reason) so no wasted touch; a bad grant rolls back, a refusal never burns a grant (one transaction).
5. One tap "Make strict now" (tightening is safe, no touch), ledgered.
6. Live countdown + progress bar, honest state from the server (not a client timer), "MTA-STS/DANE domains stay strict" line.
7. Every state change is a hash-chained line (fmail_tlsx_log191) and a step-up ledger line.
8. Reduced motion respected, 44 px targets, one layout for 390/820/1200+.

## Technology
Backend: Rust + tokio + axum, WebAuthn assertion (passkey.rs), SQL E192 (SECURITY DEFINER doors, E118 step-up grants, tier mail.tls.loosen = T2). Frontend: React 19 + TypeScript, Rust WASM kernel actionCheck, existing SendSwitch area EXTENDED by a new file TlsLoosen.tsx and a one-line mount; SendSwitch.tsx itself is not edited.

## Loophole list
L1 grant reuse -> consumed once, fmail_tls_grant191 unique. L2 body smuggling another mailbox -> mailbox owner check in SQL. L3 ceremony replay -> ceremony_take single use. L4 other device/session -> state_ok. L5 browser changes hours after touch -> hash covers params, server holds payload. L6 4th loosen -> SQL count. L7 expiry race -> self-expiring, strict_for fails closed.

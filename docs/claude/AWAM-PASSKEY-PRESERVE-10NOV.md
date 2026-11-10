# Awam: what to carry over from the founder passkey sign-in (10 Nov 2026 20:58 PKT, founder order 20:54 "codes awam ke liye preserve kero")
Founder passkey sign-in works on his phone (his word 20:54 "ok now working"; ledger proof still to be read). The same ideas are kept here for the AWAM lane (26 Nov - 16 Dec). NOTHING in awam code was touched; founder binary never contains awam code (SEPARATION LAW). Awam gets NO 2FA: a passkey is a FIRST-step option beside the password, never a hidden second step.
Reusable parts (copy as a pattern into the awam Rust, do not import):
- Ceremony store: single-use, expiring, capped per network, fair eviction (TtlMap::put_fair, signin.rs).
- Assertion proof: crate::passkey::verify_assertion (origin + rp bound, user verification required, counter check), then SQL door (founder: E139 + E154 by_credential).
- Session minting after a proven key: identity admin generate_link + verify, nothing mailed (signin.rs mint), refused if the session carries a second factor.
- No account oracle: every refusal = same generic 401.
- LESSON (10 Nov 20:30): never read a key column directly; use a SQL door and prove the grants (E154 posture154). The awam SQL must copy the posture check.
- Speed work (10 Nov 20:55): keep database connections warm (pool 10 min + 30 s keepalive), run independent reads together (tokio::join!).
Awam order: remove TOTP/authenticator screens + "passkey with password" rule -> passkey first-step door -> same speed settings -> live proof 390/820/1200+.

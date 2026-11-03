# J3 research: the most advanced passkey technology today, and what the founder lane takes from it (3 Nov 2026 09:05 PKT)

Order (founder 3 Nov 08:58): research the world's most advanced technology for this phase, then super advanced code, SQL about 900 lines covering every case. Repo first (his 08:54 word): what already exists is listed in section 2, nothing is duplicated.

## 1. What the world has now (sources are links)
| Fact | Source |
|---|---|
| WebAuthn Level 3 is a W3C Recommendation since 25 Aug 2026: conditional create/get, BE/BS flags, Signal API, Related Origin Requests, PRF, AAGUID without attestation | [startwithidentity](https://startwithidentity.com/blog/2026-08-31-webauthn-level-3-becomes-a-w3c-recommendation/), [W3C WebAuthn-3](https://www.w3.org/TR/webauthn-3/) |
| Signal API: `signalUnknownCredential`, `signalAllAcceptedCredentials`, `signalCurrentUserDetails` (the site tells the credential manager what is still valid); `getClientCapabilities()`; `hints`; attestation formats packed, tpm, android-key, android-safetynet, fido-u2f, apple, none, compound | [W3C WebAuthn-3](https://www.w3.org/TR/webauthn-3/) |
| BE (backup eligible) is fixed at creation and never changes; BS (backup state) may change; an RP stores the latest BS; `uvInitialized` false to true needs an extra factor | [W3C WebAuthn-3](https://www.w3.org/TR/webauthn-3/) |
| signCount: synced passkeys report 0, so counter regression is a weak clone signal; enforce only for device-bound (BE=0) credentials with a non-zero counter, otherwise feed it into a risk decision | [mojoauth](https://mojoauth.com/blog/signcount-is-dead-why-passkey-clone-detection-doesnt-work-anymore) |
| FIDO Server Requirements (review draft, WebAuthn L3 + CTAP2.3): random challenge per request, validate UP/UV, packed/TPM/U2F attestation, FIDO Metadata Service (MDS) validation; ES256, EdDSA, RS256 | [FIDO server v2.3 RD](https://fidoalliance.org/specs/fidoserver/fido-server-v2.3-rd-20260226.html) |
| Post-quantum: ML-DSA-44/65/87 COSE ids requested -48/-49/-50 (not final in the draft), public key 1312/1952/2592 bytes, signature 2420/3309/4627 bytes; no hybrid defined | [IETF draft-vitap-ml-dsa-webauthn-04](https://www.ietf.org/archive/id/draft-vitap-ml-dsa-webauthn-04.html) |
| 1Password ships ML-DSA passkeys (8.12.44); creating them is not yet possible on iOS; few sites accept them; no upgrade path for old passkeys yet | [1Password](https://1password.com/blog/post-quantum-passkeys) |

## 2. What the repo already has (so nothing is repeated)
* SQL E117: `founder_passkeys` (credential, passkey jsonb, sign_count, revoke), single-use ceremonies (5 min), step-up grants, recovery codes and requests. E118: tiers T0-T3, AAGUID allow-list, hardware rule, T3 two-key window, mobile flare, canonical action hash (`founder_action_hash`).
* Rust: `server/rust/passkey_core.rs` (std-only: bounds-checked CBOR, COSE P-256 and RSA, authData parser, clientData check, counter check) + `passkey_glue.rs` (ring verify) already run the awam passkey login and are tested. `ring` is already in the founder crate.
* Not there: BE/BS/AAGUID/attestation facts per credential, a risk decision, an event ledger, FIDO MDS trust, the Signal API queue, a policy with Related Origins, a PQ readiness record, EdDSA.

## 3. Decisions (the repo is on the table, so these follow from it)
1. **SQL E139 (about 900 lines) is the brain**: policy, per-credential facts with immutable BE/AAGUID/algorithm, hash-chained event ledger, risk decision door, MDS trust, Signal queue, PQ readiness report, selftest, CHECK. It does not touch E117/E118 tables except one additive trigger on `founder_passkeys` that queues the Signal "accepted credentials" list.
2. **Rust J3**: a founder `passkey.rs` that reuses the SHARED `passkey_core.rs` through `#[path]` (like `merkle_core.rs`), adds EdDSA and the L3 flags on top, and calls the E139 doors. The awam file is read, never edited. The crate `webauthn-rs` is NOT used: it is not needed once the verified core exists, it cannot be built in this sandbox (crates.io index unreachable), and a second WebAuthn implementation would split the trust. (Decision recorded for the founder to overrule.)
3. **Clone rule**: device-bound (BE=0) credential with a non-zero counter that does not go up = revoke and ledger (as the F2d design says). Synced (BE=1): the same event is a risk signal (step-up), never an automatic lock-out.
4. **Post-quantum**: classical only today (ES256, EdDSA). ML-DSA ids stay OFF in the policy until the COSE ids are final and an authenticator the founder owns can make one; the PQ report states the real count (0) in words. No false claim.
5. **Kernel**: the action-hash parity (SQL == Rust == browser kernel) is J3-part-2; E139 only adds data and decisions.

## 4. Honest limits
Attestation chains are verified by Rust (not by SQL); MDS blob signature is verified by Rust before ingest; SQL stores and decides on the verified facts. Signal API calls happen in the browser and the server only queues them. A cloned synced passkey cannot be detected by any counter; the defence is the hardware-only rule (T2/T3) already in E118.

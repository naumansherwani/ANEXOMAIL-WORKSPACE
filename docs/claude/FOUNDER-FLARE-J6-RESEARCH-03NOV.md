# J6 — Founder FLARE v2: phone push alert + passkey approval (research 3 Nov 2026 11:00 PKT)

Founder order 11:00: "duniya ka sab se advance 2026 ... opt kero, research ker ke super advance pe leke jao". The old E118 flare = an SMS number confirmed by an inbound SMS reply. Repo check (3 Nov 10:58): the SMS sender and the inbound reply were never built (no provider code anywhere), only `founder_mobile_flare_set/confirm/remove` doors exist.

## Why not plain SMS
- SMS is the weakest channel left: SIM swap, SS7 interception, number recycling, delivery lies. A "flare" that an attacker who swapped the SIM can read AND answer is not a flare.
- It needs a paid third party, a secret, and a phone number the provider sees.

## What 2026 offers (sources opened/searched 3 Nov 2026)
| Piece | What it gives | Source |
|---|---|---|
| Web Push (RFC 8030 protocol, RFC 8291 message encryption `aes128gcm`, RFC 8292 VAPID) | An end-to-end encrypted alert from OUR server straight to the founder's phone browser, no third party sees the text, no phone number | IETF RFCs 8030 / 8291 / 8292 |
| **Declarative Web Push** (Safari, WWDC 2025) | The push payload itself is a JSON notification the OS shows, even with no service worker running; iOS/iPadOS home-screen web apps get reliable alerts with an approve/deny action | [WWDC25 Meet Declarative Web Push](https://developer.apple.com/br/videos/play/wwdc2025/235/), [summary](https://dev.to/arshtechpro/wwdc-2025-declarative-web-push) |
| Passkey on the phone (hybrid / platform) | The approval is a WebAuthn assertion with user verification, bound to the digest of the exact T3 request (E118 action hash, kernel `action@1` re-derives it) | E117/E118/E139, J3 |
| CAMARA SIM Swap / Device Swap / Number Verification (GSMA Open Gateway) | Operator-side proof that a SIM or device changed recently; usable as a RISK signal if SMS is ever added | [Telefonica Open Gateway SIM Swap](https://opengateway.telefonica.com/en/apis/sim-swap), [Device Swap](https://developers.opengateway.telefonica.com/v1/docs/deviceswap), [GSMA Open Gateway](https://www.gsma.com/solutions-and-impact/gsma-open-gateway/). Coverage is by operator and country; I did NOT find a source that confirms Pakistan operators, so it is a later option, never a dependency |

## Design (what J6 becomes)
1. **Subscribe** (T2 action `flare.push`, target = sha256 of the endpoint): the phone's browser/PWA gives an endpoint + p256dh + auth. SQL stores them; the endpoint host must be a known push service (FCM, Mozilla autopush, Apple web.push.apple.com, Windows WNS), https only, no IP, no credentials in the URL.
2. **Confirm** = the phone proves it is really the founder's: the push shows "Confirm this phone", opening the app runs a passkey assertion on THAT phone (challenge = digest of "flare.confirm"). No typed code, no SMS reply.
3. **Alert**: when a T3 request begins (and for other flare triggers: clone suspected, new device, recovery opened) SQL queues one outbox row (hash-chained, de-duplicated). Rust sends it with RFC 8291 encryption + VAPID (ES256), `Urgency: high`, `TTL` bounded; the payload contains only a code word and the request id (never the secret details; the app fetches details over the signed API).
4. **Approve / Deny** from the phone = passkey assertion over the T3 request digest. Deny cancels the request at once and is final; approve counts as the second key only if it is a different allow-listed hardware key (E118 rule stays).
5. **Honest limits**: a push service is a third party that sees metadata (that a message was sent, size, time), not the content; delivery is not guaranteed, so the flare is advice that raises the alarm and the T3 delay + cancel window stay the real protection; VAPID private key lives only on the founder server env; a founder who never subscribes a phone simply has no flare (status says so, never invented).

## Build order (letter J6, all founder lane)
E140 SQL (subscription, outbox, event chain, doors, selftest, CHECK) -> Rust `flare.rs` (RFC 8291 + VAPID with `ring` only, outbox sender, routes) -> installer creates the VAPID key -> founder-web service worker + "Phone alerts" panel -> founder install -> his phone, live.

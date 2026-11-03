# FOUNDER INDEX: go straight to the file (founder 3 Nov 2026 08:43 PKT: "seedha waha jaye gay, bina dhundna")

Founder work starts HERE. Find the feature, open the named files, do not grep the repo. Every file named in backticks is verified by `python3 lanes/lane-sync.py --check` (a missing or renamed file = FAIL), so this page cannot rot.
Roots: Rust `server/founder/src/` · UI `founder-web/src/` · SQL `docs/cursor-work/sql/` · kernel `web-wasm/src/` (+ the shared `merkle_core.rs`, `checkpoint_core.rs`, `anchor_core.rs` in `server/rust/`) · docs `docs/claude/founder/`, `docs/cursor-work/founder/`.
Founder code never imports awam code; the Lovable-era founder pages are frozen in `lovable-gold/founder/` and are NOT here.

## By feature (letter = BLUEPRINT-ABC-01NOV.md)
| Feature (letter) | SQL | CHECK | Rust | UI | UI tests |
|---|---|---|---|---|---|
| Device approval, actions, audit actions (A) | `E102_founder_audit_actions_devices.sql`, `E103_founder_actions_english.sql`, `E104_founder_device_approval.sql` | `CHECK_E102.sql`, `CHECK_E103.sql`, `CHECK_E104.sql` | `ftoken.rs`, `gate.rs`, `login.rs`, `actions.rs`, `audit.rs`, `sign.rs`, `authcache.rs` | `api.ts`, `Decks.tsx`, `Finance.tsx` | `routes.test.ts` |
| Session renewal (FS1) | none | none | `ftoken.rs`, `authcache.rs` | `session.ts`, `api.ts` | `session.test.ts` |
| Settings S1 and profile (B) | `E108_founder_settings.sql`, `E115_founder_settings_s1c.sql` | `CHECK_E108.sql`, `CHECK_E115.sql` | `settings.rs` | `Settings.tsx`, `Profile.tsx`, `city.ts`, `places.ts`, `greeting.ts`, `types.ts` | `routes.test.ts` |
| Settings S2: time machine, drift (H) | `E113_founder_settings_timemachine.sql`, `E116_founder_drift_value_rule.sql` | `CHECK_E113.sql`, `CHECK_E116.sql` | `settings_s2.rs` | `SettingsS2.tsx`, `s2lib.ts` | `settingsS2.test.ts` |
| Appearance and Ambient Studio (I) | `E114_founder_appearance_ambient.sql` | `CHECK_E114.sql` | `ambient.rs` | `AmbientStudio.tsx`, `ambient.ts`, `appearance.ts` | `appearance.test.ts` |
| Passkey, step-up, chairman protocol (J) | `E117_founder_passkey_stepup_recovery.sql`, `E118_founder_chairman_protocol.sql`, `docs/cursor-work/sql/E139_founder_webauthn_l3.sql`, `docs/cursor-work/sql/E140_founder_flare_push.sql`, `docs/cursor-work/sql/E141_founder_flare_receipts.sql` | `CHECK_E117.sql`, `CHECK_E118.sql`, `docs/cursor-work/sql/CHECK_E139.sql`, `docs/cursor-work/sql/CHECK_E140.sql`, `docs/cursor-work/sql/CHECK_E141.sql` | `server/founder/src/passkey.rs` (+ shared read-only `server/rust/passkey_core.rs`, routes + T2/T3 gate in `server/founder/src/main.rs`), `flare.rs` | `founder-web/src/Keys.tsx`, `founder-web/src/passkey.ts`, `founder-web/src/passkey_pure.ts`, `founder-web/src/Settings.tsx` (Privacy), `Flare.tsx`, `flare_pure.ts`, `public/flare-sw.js` | `server/founder/src/passkey.rs` tests, `founder-web/src/passkey.test.ts`, kernel `web-wasm/src/action.rs` + `server/rust/j3_action_vectors.json` |
| Transport posture, AES-256 (K) | `E119_founder_tls_posture.sql` | `CHECK_E119.sql` | `tls256.rs` | none | none |
| Dashboard, Bridge, Trust, palette, 3D | `E111_founder_channels_telemetry.sql` | `CHECK_E111.sql` | `bridge.rs`, `data.rs`, `main.rs` | `Surface.tsx`, `Bridge.tsx`, `Trust.tsx`, `Palette.tsx`, `Scene3D.tsx`, `Brand.tsx`, `catalog.ts`, `App.tsx`, `router.tsx`, `main.tsx` | `routes.test.ts` |
| Live data and SSE (4b) | `E109_founder_live.sql` | `CHECK_E109.sql` | `live.rs` | `livefeed.ts`, `sse.ts`, `Live.tsx` | `livefeed.test.ts` |
| Inbox (4d) | `E112_founder_inbox.sql` | `CHECK_E112.sql` | `inbox.rs` | `Bridge.tsx` | none |
| Host proof L5 | `E110_founder_host_proof.sql` | `CHECK_E110.sql` | `hostproof.rs` | none | none |
| Polar read-only (C1, O later) | `E105_founder_polar_pulse.sql`, `E106_founder_polar_rejects.sql` | `CHECK_E105.sql`, `CHECK_E106.sql` | `polar.rs` | `Finance.tsx` | none |
| Audit ledger and Merkle (G1, G2) | `E107_founder_audit_merkle.sql` | `CHECK_E107.sql` | `ledger.rs`, `audit.rs` | `Surface.tsx` | none |
| Ledger seal gauge (G4) | `E120_founder_ledger_gauge_hardening.sql` | `CHECK_E120.sql` | `ledger.rs` | `sealpin.ts` | `sealpin.test.ts` |
| Consistency proofs (G5a) | `E121_founder_audit_consistency.sql` | `CHECK_E121.sql` | `ledger.rs` | `kernel.ts`, `sealpin.ts` | `kernel.test.ts` |
| Signed checkpoints (G5b) | `E122_founder_seal_interval.sql`, `E123_founder_signed_checkpoints.sql` | `CHECK_E122.sql`, `CHECK_E123.sql`, `CHECK_G5B_LIVE.sql` | `signedcp.rs` | `sealpin.ts` | `sealpin.test.ts` |
| Time anchors (G5c) | `E124_founder_time_anchors.sql`, `E132_anchor_selftest_repair.sql`, `E133_anchor_pending_any_length.sql`, `E134_anchor_requeue_door.sql` | `CHECK_E124.sql`, `CHECK_E133.sql`, `CHECK_E134.sql` | `anchors.rs` | `anchorgauge.ts` | `anchorgauge.test.ts` |
| Portable pin (G5d) | `E131_founder_portable_verify.sql`, `E138_founder_portable_tick.sql` | `CHECK_E131.sql`, `CHECK_E138.sql`, `CHECK_G5D_LIVE.sql` | `portable.rs` | `portable.ts` | `portable.test.ts` |
| WASM kernel client (F) | none | none | none | `kernel.ts`, `kernel.worker.ts`, `kernel.pin.ts` | `kernel.test.ts` |
| WASM kernel itself (shared, one kernel) | none | none | none | `lib.rs`, `portable.rs`, `ed.rs`, `hash.rs`, `frame.rs` | `cargo test` in `web-wasm` |

## Cross-cutting
* Shared Rust cores the founder crate reads (shared lane): `server/rust/merkle_core.rs`, `jwt_core.rs`, `checkpoint_core.rs`, `anchor_core.rs`, vectors `g5b_vectors.json`, `g5c_tsa_vectors.json`, `g5d_bundle_vector.json`, `consistency_vectors.json`. The installer must copy each one (founder-install.sh).
* Styles: `cinema.css`, `dx.css`, `ui.css`, `styles.css`, `tailwind.css` (CINEMATIC look, never flatten). Components: `components/ui/button.tsx`, `components/ui/switch.tsx`.
* Run: SQL `sql-run.sh` (bare = AUTO, or a CHECK name) · Rust + SPA `founder-install.sh` · all at once `all-pull.sh` · web memory `pull.sh`.
* Before any commit: `lanes/lane-sync.py`, `manifest-sync.py`, `manifest-verify.py`, `rules-gate.py --staged` (read the output first).
* Order and proof live in: `docs/claude/BLUEPRINT-ABC-01NOV.md`, `docs/cursor-work/founder/founder-commands.md`, `docs/claude/founder/PULL-COMMANDS.md`, `docs/cursor-work/DONE-DO-NOT-REPEAT.md`.

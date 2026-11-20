# QC3 AUDIT, 20 Nov 2026 08:27 PKT (his order 08:20: fix loopholes, match phase technology, wire real, code = live Chrome)
Technology per phase (his law): Rust + Tokio + axum doors, signed envelope, Rust WASM kernel RPC (no raw fetch), HTTP/3, PostgreSQL RLS (E195 read-only security-definer doors). Test runner (bun) = my sandbox only, never a runtime.
LIVE MATCH (my Chrome on founderworkspace.anexomail.com, 20 Nov 2026 08:27 PKT):
- Live bundle index-DhaYIeTm.js = QC3-5 code (timeline, presets). Badges commit 7a3f1fa0 is NOT in it yet (needs his founder-install): repo build and live differ by exactly the badges.
- Doors closed without token: /mail/timeline 401, /mail/timeline/badges 401, /mail/delivery 401, /healthz 200 (read-only check, no data touched).
- Authenticated path proven live: Sent timeline on real mail (Queued .. Accepted) and compose presets.
LOOPHOLES FOUND:
1. Badges door authenticated path: not seen live (comes with install of 7a3f1fa0).
2. /mail/delivery door: no screen mounts it yet (board/list). Door exists, closed without token; UI mount = next QC3 gap.
3. Calm bar firing live: needs a recipient; I never risk a real send; sandbox-proven only.
4. 390/820 live: his order 08:20 = do it after the Q series, on his site; window resize does not change the viewport, so a phone screenshot or same-origin frame is needed.
5. Service worker stale bundle after install (SPA update after install): I clear anexo-assets-v1 in my Chrome; real fix still open.
6. Per-recipient delivery rows not stored (logged gap); attachment-word check (Q3).
No fake green: QC3 stays NOT green until 1-3 are seen live and he says the word.

## STATUS 20 Nov 2026 08:45 PKT
QC3 LOOPHOLE FIX (20 Nov 2026 08:45 PKT): #5 service worker stale bundle = CLOSED WITH PROOF (live headers: index /_cc/ no-store, early.js no-store, flare-sw.js no-store, hashed bundle immutable; flare-sw.js only handles push + 'anexo-flare' cache, never caches the bundle; 'anexo-assets-v1' does not exist in his Chrome; earlier staleness = an open tab not reloaded). #2 delivery board WRITTEN: delivery_pure.ts + 5 tests, MailDeliveryBoard.tsx (Systems > Mail health, one door via kernel RPC mail_api.delivery, 24h/7d/30d, 44px buttons, wraps), 1 additive line in MailHealth.tsx; tsc clean, pure-TS tests 460/0 (sandbox runner), vite build OK. NOT INSTALLED: his one founder-install installs badges + delivery board together; then my live look at Sent badges and Systems > Mail health.

<!--TECHLAW-->
# PHASE L PLAN (written 12 Nov 2026 18:05 PKT, founder order: technology plan + codes plan + SQL plan BEFORE code; compaction-proof)
Founder word 12 Nov 17:54: Safari/Firefox ML-DSA live proof is NOT needed (closed, never an open gap again). Order: plan first, then code, ONE install for the whole L.

## 1. TECHNOLOGY (blueprint L row + CLAUDE.md FOUNDER TECHNOLOGY LAW; a listed item missing from code = OPEN GAP, never green)
| Item | Version/standard | Where | Status 12 Nov |
|---|---|---|---|
| Three.js WebGPU renderer (lazy) | three 0.185, `three/webgpu` WebGPURenderer, TSL node materials (raw GLSL ShaderMaterial does NOT run there) | founder-web/src/scene_gpu.ts (new) + Scene3D.tsx useScene | L2 OPEN (gate L-webgpu fails 13 Nov) |
| WebGL2 fallback, then CSS fallback | existing GLSL path stays untouched | Scene3D.tsx | YES (unchanged) |
| GSAP (lazy chunk) | gsap 3.13 | Scene3D.tsx loadGsap | L1 written, commit 30e2b944 |
| Framer Motion | package `motion` 14 | SignIn, AuthCinema | YES |
| Reduced-motion + forced-colors | matchMedia | Scene3D.tsx, CSS | reduced YES, forced-colors L2 |
| @types/three | 0.185 | package.json | YES |
Renderer order: WebGPU (navigator.gpu + adapter) -> WebGL2 GLSL -> CSS fallback. Cinematic look stays PIXEL-EQUAL: same colours/TONE_HEX, same breathing, same halo; the TSL port reproduces the GLSL maths (hash noise n3, fresnel f=pow(1-max(dot(n,z),0),2.2), core/rim mix, halo additive back-side).

## 2. CODES PLAN (order, each step tested before the next)
1. scene_gpu.ts: `gpuAvailable()` (navigator.gpu.requestAdapter, cached, never throws) + `buildOrbGpu(TSL)` HealthOrb + halo as NodeMaterial (MeshBasicNodeMaterial with positionNode displacement + colorNode/opacityNode). Pure helpers (renderer choice, tone->params) in scene_pure.ts with bun tests (no GPU needed).
2. useScene: optional `buildGpu`; renderer chosen by `pickRenderer(gpu, forced)` ; `await renderer.init()` for WebGPURenderer; any throw -> fall to WebGL2 build, then CSS fallback (state "fail"). Settings > Graphics off / reduced-motion = one still frame (unchanged).
3. BridgeMap TSL port (particles lanes) the same way.
4. Forced-colors: `@media (forced-colors: active)` hides canvas, shows .orb-fallback with system colours.
5. `data-gfx` attribute on the host (webgpu | webgl | css) so the live look can READ which renderer ran (proof, not guess).
6. 390 / 820 / 1200+ sandbox harness (Playwright, chromium --enable-unsafe-webgpu, swiftshader) + his phone screenshots; live bundle hash = repo build.
7. Build, .gz files beside assets (repo convention), gate L-webgpu -> ok, records, ONE founder-install command.
Rules kept: three/gsap lazy (never first paint), loop stops when hidden/off screen, no mock data (tone/counts come only from verified answers), one build for all sizes.

## 3. SQL PLAN
No SQL is REQUIRED for L (graphics holds no user data). Optional E166 (only if he wants evidence on his own board): `founder_gfx_seen` append-only counter per (day, renderer in webgpu/webgl/css) with NO user id and NO device id (privacy), definer + pinned search_path, service_role only, CHECK_E166 + selftest. Default = NOT built unless he says so; next free SQL stays E166. Never reuse numbers.

## 4. SUPER-ADVANCED CODE RULES FOR L (so a compacted Claude does not downgrade)
- No `any` in new files, strict TS; pure logic in *_pure.ts with bun tests; GPU code isolated in scene_gpu.ts (lazy import, never imported statically).
- Every failure path degrades one step (webgpu -> webgl -> css), never a blank hole, never an uncaught throw.
- No new raw fetch/WebSocket; gate ratchet unchanged. Gate TECH-LAW-GATE.json L-webgpu must be flipped to ok ONLY when scene_gpu.ts contains WebGPURenderer and the live look shows data-gfx=webgpu.
- GREEN only with WIRED: YES / REAL: YES / TECH-LAW CHECKED + live Chrome (gfx attr, 390/820/1200+).

## 5. RESUME (for a compacted Claude)
1. `python3 docs/cursor-work/server/rules-read.py`. 2. This file. 3. docs/claude/tech-contracts/CURRENT.md (PHASE L CONTRACT). 4. Do the CODES PLAN in order; tick each here.
Progress: [x] contract [REVERTED 18:20 by his UI LAW: L1 GSAP] [PARKED in git stash: steps 1-5 WebGPU/TSL, sandbox pixel-equal; needs his haan] [ ] 1 scene_gpu [ ] 2 useScene [ ] 3 BridgeMap [ ] 4 forced-colors [ ] 5 data-gfx [ ] 6 harness [ ] 7 build+install
After L: S5 TanStack Start (gate 14 Nov), M MoQ (16 Nov), N..X, ClamAV/Hetzner (20 Nov). Safari/Firefox proof = CLOSED by his word.

## 6. UI LAW (his word 12 Nov 18:04/18:12): current orb + BridgeMap are INTACT. Nothing in founder-web/src changes without his explicit haan. New features = additive backend-fed info, proposed one by one (see chat 18:20). Repo founder-web == live build index-UQwzOKR3.

## 7. APPROVED ADDITIVE FEATURES (his "yeh sab banay gay", 12 Nov 18:21) - THE ORB AND THE BRIDGEMAP STAY INTACT, ONLY INFORMATION IS ADDED
Rule: Scene3D.tsx (orb + BridgeMap drawing code) is NOT edited. Features live in NEW files and wrap the existing components from OUTSIDE (Surface.tsx / Bridge.tsx get one-line mounts only). WebGPU/TSL stays PARKED (git stash). Each feature = contract row first, pure logic + bun tests, sandbox 390/820/1200+, his install, my Chrome look, then green.
FACT FOUND 12 Nov: the BridgeMap lanes are BUSINESS lanes (new leads, Polar events, subscriptions / mail waiting, webhook errors, rejected signatures), not network lanes; the orb tone comes from the trouble checks (t.items) + kernel verification (Surface.tsx orbTone). So network ideas (latency, H2-vs-QUIC per lane) do not fit the lanes; they live on the ORB line (LA-3) instead.
| # | Feature | Where (new file / mount) | Data (real only, never guessed) | Technology |
|---|---|---|---|---|
| LA-1 | "Why this colour" (hover / tap, 44 px target) | founder-web/src/orbwhy_pure.ts (+test) + OrbWhy.tsx; one mount in Surface.tsx beside the orb | t.items (name,state,detail) + kernel state ks; ok = "N of N checks fine", warn/fail = names of the checks that are not ok | React 19 TS, Radix Popover (shadcn), GSAP lazy chunk for the entrance (makes gate L-gsap TRUE without touching the orb), reduced-motion = instant |
| LA-5 | Screen-reader + forced-colors text (rides with LA-1) | OrbWhy.tsx (visually hidden live text), CSS @media (forced-colors: active) | same as LA-1 | aria-describedby, role=status, forced-colors CSS |
| LA-3 | One line under the orb: "HTTP/3 QUIC . Hardware key . ML-DSA-65", Settings on/off | founder-web/src/orbline_pure.ts + OrbLine.tsx; setting key in Settings > Graphics | deviceStatus() (mode, bound, psrc) + Path card transport; unknown = hidden, never a guess | React TS, existing dbsc_pure.pqLine |
| LA-4 | Alert mark (only when needed) | OrbAlert.tsx | /sessions/board 24 h events blocked / would_block (K7c enforce now ON) | React TS; nothing drawn when zero |
| LA-2 | BridgeMap lane tooltip: count + how long ago the last item came | BridgeLaneTip.tsx wrapper, lanes get an optional `last` | needs a data audit FIRST: which lane has a real last-event time (mail outbox oldest, webhook last event); a lane without one shows only the count. If a lane lacks it, SQL E166 (read-only view) is proposed to him, never built silently | React TS (+ maybe SQL E166) |
| LA-6 | Click a lane -> the ledger below filters to that lane | Bridge.tsx one handler (ledger rows already exist: subs past_due, rejects) | existing ledger rows | React TS |
| LA-7 | Idle lane dims (nothing for 10 min) | needs LA-2 last-event; the particles are drawn by Scene3D.tsx, so this needs HIS separate haan (touches the drawing) | LA-2 data | parked until LA-2 data exists and he says haan |
Order: LA-1+LA-5 -> LA-3 -> LA-4 -> LA-2 (data audit) -> LA-6 -> LA-7 (his extra haan). Gate: L-gsap is closed by LA-1 (GSAP really used, additive); L-webgpu stays open and needs HIS decision (keep WebGL2 as documented exception, or approve the parked TSL port after he sees old vs new side by side).
Pasted network ideas from his message (lane latency/throughput, H2 vs QUIC per lane, dropped packets, click-to-filter, idle dimming): only click-to-filter (LA-6) and idle dimming (LA-7) fit the business lanes; latency/protocol go to LA-3 on the orb; a per-lane network lane would need NEW backend data (not built, not promised).
Resume for a compacted Claude: rules-read.py -> this file -> CURRENT.md "PHASE L-A" row -> start at the first unchecked feature. Progress: [x live-looked 19:50, awaits phone 390/820] LA-1+LA-5 [x written 19:50, awaits install + live look] LA-3 [ ] LA-4 [ ] LA-2 [ ] LA-6 [ ] LA-7

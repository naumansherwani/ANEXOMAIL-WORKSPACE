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
Progress: [x] contract [x] L1 GSAP [ ] 1 scene_gpu [ ] 2 useScene [ ] 3 BridgeMap [ ] 4 forced-colors [ ] 5 data-gfx [ ] 6 harness [ ] 7 build+install
After L: S5 TanStack Start (gate 14 Nov), M MoQ (16 Nov), N..X, ClamAV/Hetzner (20 Nov). Safari/Firefox proof = CLOSED by his word.

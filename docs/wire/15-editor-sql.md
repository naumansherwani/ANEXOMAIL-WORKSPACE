> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# WIRE 15 — SIRF SQL EDITOR SE CHALNE WALI PHASES

Yeh do phases terminal runner (`sql/apply-all.sh`) se nikal di gayi hain —
ab woh RED nahi karti. Inko sirf database ke **SQL editor** mein chalana hai.

| Phase | Repo file | Kahan run |
|---|---|---|
| 38 · Move-In hardening | `sql/editor/phase38_movein_hardening.sql` | SQL editor |
| ANEXOChat 01 · Foundation | `sql/editor/anexochat_phase01_foundation.sql` | SQL editor |
| 53 · Legacy tables RLS lock | `sql/editor/phase53_legacy_rls_lock.sql` | SQL editor |


## Tareeqa (dono ke liye same)

1. Repo mein file kholo, **poora** content copy karo (kuch edit nahi).
2. Database dashboard → SQL editor → paste → **Run**.
3. `Success` aane par phase DONE. Error aaye to poora error text bhejo.

Dono files idempotent hain: purani shape wali table `_legacy` rename hoti hai,
data delete kabhi nahi hota, dobara run karna safe hai.

## Baqi sab

Terminal wali saari phases pehle ki tarah:

```bash
cd /opt/anexomail-web && git checkout -- . && git pull && bash sql/apply-all.sh
```

Ab is list mein 38 aur foundation shamil nahi — expected `RED=0`.

> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# WIRE 16 — HETZNER STORAGE BOX 1TB (copy-paste)

Rule: **Supabase = truth · Storage Box = weight · Hetzner = egress (free)**.
Mail body local NVMe par (fast), attachments Box par (sasta).

## A · Robot panel (aap ka hissa, 2 toggle)

Storage Box → Settings → **SSH support = ON**, **External reachability = ON**.
Issued username: `u659696`.

## B · key + mount (server terminal, ek command)

```bash
cd /opt/anexomail-web && git pull && bash server/storage/mount-box.sh u659696
```

Script khud: sshfs install → key banata (`/root/.ssh/storagebox`) → key Box par install
→ systemd mount `/mnt/anexomail-box` (reboot-safe) → `attachments/` folder → `df -h` reading.
Pehli dafa key install par Box ka password ek dafa poochha jayega (kahin save nahi hota).

## C · volume register (Supabase = truth)

```bash
cd /opt/anexomail-web && bash server/storage/register-box.sh u659696
```

Koi Founder JWT nahi chahiye. Script protected `SUPABASE4_*` server env se direct
service RPC karti hai; credential terminal par print nahi hota.

Purana `server2-local` volume `accepts_new=false` ho jata hai — naye attachments Box par,
purana data jahan hai wahin readable. Zero migration.

## D · gate

```bash
cd /opt/anexomail-web && bash server/gates/storage-gate.sh
```

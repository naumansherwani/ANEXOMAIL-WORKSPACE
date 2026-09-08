# WIRE 09 — ANEXOVideoCall (signaling · ICE · relay · recording) — sirf copy-paste

## A · relay + host ingress (coturn cert copy Caddy se, ports khud khulte hain)

```bash
cd /opt/anexomail-web && git pull && bash server/caddy/deploy-sites.sh
```

## B · gate (signaling arms · ICE creds · coturn 3478/5349 · recording · DB · UI)

```bash
cd /opt/anexomail-web && bash server/gates/videocall-gate.sh
```

Signaling Rust :3200 par hai (Wire 04), relay apna coturn hai —
koi external video API nahi. Recording sirf consent row ke saath.

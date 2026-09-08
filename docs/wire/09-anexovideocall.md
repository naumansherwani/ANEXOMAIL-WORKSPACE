# WIRE 09 — ANEXOVideoCall (signaling · ICE · relay · recording) — sirf copy-paste

## A · relay + host ingress (coturn cert copy Caddy se, ports khud khulte hain)

```bash
cd /opt/anexomail-web && git pull && bash server/caddy/deploy-sites.sh
```

## B · TURN secret sync (coturn ka HMAC secret → Rust engine .env)

```bash
cd /opt/anexomail-web && git pull && bash server/rust/deploy.sh && bash server/rust/turn-env-sync.sh
```

Secret sirf server par rehta hai (coturn conf + `/opt/anexomail-rust/.env`, chmod 600),
kabhi print ya repo mein nahi. Readiness ka public arm `chat.turn.health` sirf
`"credential_ready":true` deta hai — asli username/credential sirf authenticated
`chat.turn.credentials` se, is liye bina token 401 hi sahi jawab hai.

## C · gate (signaling arms · ICE creds · coturn 3478/5349 · recording · DB · UI)

```bash
cd /opt/anexomail-web && bash server/gates/videocall-gate.sh
```

Signaling Rust :3200 par hai (Wire 04), relay apna coturn hai —
koi external video API nahi. Recording sirf consent row ke saath.

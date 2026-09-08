# WIRE 08 — ANEXOChat (feature-by-feature) — sirf copy-paste

ANEXOChat ka engine wahi Rust :3200 hai (Wire 04 se already deployed).
Bun :3300 sirf fallback hai.

## A · fallback process deploy

```bash
cd /opt/anexomail-web && git pull && bun install && pm2 restart anexochat --update-env && pm2 save
```

## B · gate (har feature: message · file · search · continuity · receipts · timeline · health · provenance · collisions · decisions · promise · work · safety · device vault · integrity · email bridge · file context · cost)

```bash
cd /opt/anexomail-web && bash server/gates/chat-gate.sh
```

Gate teen cheezein padhta hai: Rust arm ka asli response, fallback ka `200`,
aur DB mein us feature ki table + RLS. Jo arm ya table missing hai, uska naam
FAIL list mein aayega — main usi ko theek karunga.

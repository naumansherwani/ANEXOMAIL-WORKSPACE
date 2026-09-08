# WIRE 04 — RUST PRIMARY ENGINE (:3200 + QUIC) — sirf copy-paste

Founder: Muhammad Nauman Sherwani

Yahan kuch edit nahi karna. Do box hain: deploy, phir gate.

## A · deploy (repo se auto-sync, `.env` untouched)

```bash
cd /opt/anexomail-web && git pull && bash server/rust/deploy.sh
```

## B · gate (asli response check — `/rpc/*`, `/file/*`, HTTP/3, WT)

```bash
cd /opt/anexomail-web && bash server/gates/rust-gate.sh
```

Aakhir mein `GATE GREEN` ya `GATE RED` + jo dot fail hua uska naam aayega.
Poora output mujhe do — RED main theek karunga, aap dobara wahi do line chalayenge.

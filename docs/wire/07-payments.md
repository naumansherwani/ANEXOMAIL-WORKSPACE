# WIRE 07 — PAYMENTS :3400 (Polar Rust engine) — sirf copy-paste

Engine ki logic **no-touch** hai. Sirf deploy + gate.

## A · deploy (engine + `polarpayments.anexomail.com` ingress; `.env` untouched)

```bash
cd /opt/anexomail-web && git pull && bash server/rust/polar-payment/deploy.sh
```

## B · gate (health · ready · metrics · 401 signature guard · signed test event · DB truth)

```bash
cd /opt/anexomail-web && bash server/gates/payments-gate.sh
```

Note: webhook par bina signature `401` aana **sahi** hai — gate isi ko PASS ginta hai.
Asli signed event repo ke `test-event.sh` se jaata hai aur DB mein row banni chahiye.

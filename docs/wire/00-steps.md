# 00 — SAB STEPS, EK EK COMMAND (sirf copy-paste)

Qaida: ek waqt mein EK step. Us step ka poora output mujhe bhejo. Green ho to agla step.
Koi file edit nahi, koi nano nahi. SQL sirf editor mein paste hoti hai (jahan likha ho).

---

## STEP 1 — repo latest karo (har baar yahi, local changes ka masla khatam)

```bash
cd /opt/anexomail-web && git checkout -- . && git pull
```

---

## STEP 2 — database connection (agar pehle se GREEN hai to skip)

```bash
cd /opt/anexomail-web && bash sql/connect.sh
```

---

## STEP 3 — SQL phases apply (phase34 aap ne editor mein kar li, is liye us ke baad se)

```bash
cd /opt/anexomail-web && bash sql/apply-all.sh --from sql/phase35_payment_safety.sql
```

---

## STEP 4 — SQL verify

```bash
cd /opt/anexomail-web && bash sql/verify.sh
```

---

## STEP 5 — mail SQL (13 addresses) — SIRF editor mein

`docs/wire/11-mail-sql.md` ka poora SQL block database SQL editor mein paste karke run karo.
Aakhir mein aana chahiye: `mailboxes = 13`, `domains = 1`.

---

## STEP 6 — Rust engine :3200 deploy

```bash
cd /opt/anexomail-web && bash server/rust/deploy.sh
```

---

## STEP 7 — Rust gate

```bash
cd /opt/anexomail-web && bash server/gates/rust-gate.sh
```

---

## STEP 8 — frontend build + restart

```bash
cd /opt/anexomail-web && bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save
```

---

## STEP 9 — Caddy sites deploy

```bash
cd /opt/anexomail-web && bash server/caddy/deploy-sites.sh
```

---

## STEP 10 — web gate (awam + founder host, har route 200)

```bash
cd /opt/anexomail-web && bash server/gates/web-gate.sh
```

---

## STEP 11 — mail server deploy (postfix + dovecot + DKIM)

```bash
cd /opt/anexomail-web && bash server/mail/deploy-mail.sh
```

Output ke aakhir mein DKIM TXT value milegi — woh registrar par record name `mail._domainkey` mein paste karo.
Yeh aur DNS (A · MX · SPF · DMARC · PTR) aap ka wahi ek manual hissa hai.

---

## STEP 12 — mail gate (DNS chain + 13 address + asli round-trip)

```bash
cd /opt/anexomail-web && bash server/gates/mail-gate.sh
```

---

## STEP 13 — payments :3400 deploy

```bash
cd /opt/anexomail-web && bash server/rust/polar-payment/deploy.sh
```

---

## STEP 14 — payments gate

```bash
cd /opt/anexomail-web && bash server/gates/payments-gate.sh
```

---

## STEP 15 — ANEXOChat restart

```bash
cd /opt/anexomail-web && bun install && pm2 restart anexochat --update-env && pm2 save
```

---

## STEP 16 — chat gate

```bash
cd /opt/anexomail-web && bash server/gates/chat-gate.sh
```

---

## STEP 17 — videocall gate

```bash
cd /opt/anexomail-web && bash server/gates/videocall-gate.sh
```

---

## STEP 18 — final audit (sab blocks ek saath)

```bash
cd /opt/anexomail-web && bash server/gates/all-gates.sh
```

---

## Ledger

| Step | Kaam | Status |
|---|---|---|
| 1 | repo pull | TODO |
| 2 | DB connection | DONE |
| 3 | SQL apply (35+) | TODO |
| 4 | SQL verify | TODO |
| 5 | mail SQL (editor) | TODO |
| 6-7 | Rust :3200 + gate | TODO |
| 8-10 | frontend + Caddy + gate | TODO |
| 11-12 | mail + gate | TODO |
| 13-14 | payments + gate | TODO |
| 15-16 | ANEXOChat + gate | TODO |
| 17 | videocall gate | TODO |
| 18 | final audit | TODO |

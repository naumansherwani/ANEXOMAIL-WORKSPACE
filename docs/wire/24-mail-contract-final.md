# 24 — FINAL MAIL CONTRACT (status: READY)

## Live error ka exact matlab

`phase57` ne `spf_result` add kar diya tha, magar live `mail_ingest()` purana raha
aur `mailboxes.org_id` maangta raha. Doosra `/api/mail/deliver` generation
`cc_addrs` maang raha tha jabke canonical naam `cc_addresses` hai.

## Ek auto-sync command

```bash
cd /opt/anexomail-web && git pull && bash server/deploy-all.sh
```

Deploy ka database step ab tarteeb se `phase57` → `phase58` → `phase56` chalata
hai. `phase58` koi mail/table delete nahi karta: function replace, dono address
column generations sync aur Data API schema reload karta hai.

## Sirf mail ko foran prove karna ho

```bash
cd /opt/anexomail-web && git pull
bash sql/run.sh sql/phase58_mail_contract_final.sql
bash server/mail/deploy-mail.sh
postqueue -f
sleep 20
postqueue -p
bash server/gates/mail-gate.sh
```

DONE sirf jab queue empty aur mail gate PASS-only ho. PTR ka DNS fail alag manual
dot hai; woh database delivery ko rollback nahi karta, magar launch gate RED rakhta hai.
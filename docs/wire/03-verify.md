# 03 — VERIFY (copy-paste)

```bash
cd /opt/anexomail-web && git pull && bash sql/verify.sh
```

Output mein yeh 4 line dekhni hai:

- `TABLES` — kitni tables ban gayi
- `FUNCTIONS` — kitne functions ban gaye
- `RLS OFF (must be 0)` — 0 hona chahiye
- `NO GRANT (must be 0)` — 0 hona chahiye

Agar in do mein 0 se zyada aaya, neeche usi output mein table ke naam list hote hain.
Woh poora output mujhe do — main un tables ke liye GRANT/RLS ka SQL usi waqt repo mein daal dunga.

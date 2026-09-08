# WIRE 15 — SIRF SQL EDITOR SE CHALNE WALI PHASES

Yeh do phases terminal runner (`sql/apply-all.sh`) se nikal di gayi hain —
ab woh RED nahi karti. Inko sirf database ke **SQL editor** mein chalana hai.

| Phase | Repo file | Kahan run |
|---|---|---|
| 38 · Move-In hardening | `sql/editor/phase38_movein_hardening.sql` | SQL editor |
| ANEXOChat 01 · Foundation | `sql/editor/anexochat_phase01_foundation.sql` | SQL editor |

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

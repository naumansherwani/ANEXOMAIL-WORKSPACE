# ANEXOMAIL — Server 2 (Brain, port 3100) route files

Rule (locked, SQL folder ki tarah): backend ki har file isi repo folder mein rehti hai.
Backend `/opt/anexomail` git repo nahi hai, is liye founder yahan se **poori file copy**
karta hai aur server par `nano` mein overwrite karta hai (select all -> paste).
Kabhi line-patch, sed ya python patch nahi.

| Repo file | Server path | Phase |
| --- | --- | --- |
| `routes/integrations.ts` | `/opt/anexomail/src/routes/integrations.ts` | 22 |
| `routes/settings.ts` | `/opt/anexomail/src/routes/settings.ts` | 23 |

## Env naam (Server 2 par asli naam)

Supabase #4 ke naam **`SUPABASE4_URL`** aur **`SUPABASE4_SERVICE_ROLE_KEY`** hain.
Nayi file mein hamesha yeh naam pehle aur `SUPABASE_URL` fallback ho.
Aur `createClient` boot par throw na kare — warna poora Brain crash hota hai
(port 3100 dead, curl `000`). Missing env = sirf us router ka `503`.

## Copy + restart tareeqa

```bash
nano /opt/anexomail/src/routes/integrations.ts   # select all -> paste -> Ctrl+O, Ctrl+X
pm2 restart anexomail-leo && sleep 3
for p in providers connections migrations delivery/health exports leo-actions; do
  printf "/api/integrations/%s -> " "$p"
  curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:3100/api/integrations/$p"
done
```

`401` = green (guarded). `000` = server down. `404` = mount missing.
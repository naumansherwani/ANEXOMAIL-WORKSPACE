# ANEXOChat Gateway — Caddy HTTP/3 + Rust PRIMARY (locked 14 Aug 2026)

Blueprint (PART 0 + PHASE 2) ke mutabiq transport tarteeb:

```text
Browser
  ├─ 1. WebTransport / HTTP3 / QUIC  → Rust engine  udp/3443   (PRIMARY realtime + files)
  ├─ 2. tRPC-style /rpc/chat.*       → Rust engine  tcp/3200   (PRIMARY commands/queries)
  └─ 3. /api/chat/*                  → Bun service  tcp/3300   (FALLBACK only)
                                          ↓
                          Supabase #4 / PostgreSQL + RLS (truth)
```

Bun kabhi primary nahi. Rust ka procedure ya WT session available na ho, sirf tab Bun.

## 1) WebTransport cert (Caddy ke certs se, koi naya CA nahi)

```bash
mkdir -p /etc/anexochat/wt
CERT_DIR=$(find /var/lib/caddy/.local/share/caddy/certificates -type d -name 'anexochat.anexomail.com' | head -1)
cp "$CERT_DIR/anexochat.anexomail.com.crt" /etc/anexochat/wt/fullchain.pem
cp "$CERT_DIR/anexochat.anexomail.com.key" /etc/anexochat/wt/privkey.pem
chmod 600 /etc/anexochat/wt/privkey.pem
ufw allow 3443/udp
```

`/opt/anexomail-rust/.env` mein:

```bash
SUPABASE4_URL=https://<ref>.supabase.co
SUPABASE4_SERVICE_ROLE_KEY=<service role key>
ANEXOCHAT_WT_PORT=3443
ANEXOCHAT_WT_CERT=/etc/anexochat/wt/fullchain.pem
ANEXOCHAT_WT_KEY=/etc/anexochat/wt/privkey.pem
```

Frontend `/opt/anexomail-web/.env`:

```bash
VITE_ANEXOCHAT_WT_URL=https://anexochat.anexomail.com:3443
```

Cert/key na hon to Rust WebTransport OFF rakhta hai aur `/rpc/health` mein
`"webtransport":"unavailable"` bolta hai — jhooti capability kabhi nahi.

## 2) Caddyfile — POORI FILE (nano overwrite)

```bash
cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.bak.$(date +%s)
nano /etc/caddy/Caddyfile     # select all -> paste -> Ctrl+O, Ctrl+X
caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy
```

```caddyfile
# ==========================================================
# ANEXOMAIL Production Gateway  (HTTP/1.1 + HTTP/2 + HTTP/3)
# ==========================================================
{
        email admin@nexatect.com
        servers {
                protocols h1 h2 h3
        }
}

anexomail.com, www.anexomail.com {
        encode gzip zstd
        handle /rpc/* {
                reverse_proxy localhost:3200
        }
        handle /api/chat/* {
                reverse_proxy localhost:3300
        }
        handle /api/* {
                reverse_proxy localhost:3100
        }
        handle /health {
                reverse_proxy localhost:3100
        }
        handle {
                reverse_proxy localhost:3000
        }
}

app.anexomail.com {
        encode gzip zstd
        reverse_proxy localhost:3000
}

# ==========================================================
# ai.anexomail.com — LEO AI product (PARALLEL AI BUILD LOCK)
# Same anexomail-web mirror: frontend :3000, wahi API/RPC/chat split.
# Awam ko sirf `/` (coming soon); /app/* mirror unlock key ke peeche.
# ==========================================================
ai.anexomail.com {
        encode gzip zstd
        handle /rpc/* {
                reverse_proxy localhost:3200
        }
        handle /wt/* {
                reverse_proxy localhost:3200
        }
        handle /api/chat/* {
                reverse_proxy localhost:3300
        }
        handle /api/* {
                reverse_proxy localhost:3100
        }
        handle /health {
                reverse_proxy localhost:3100
        }
        handle {
                reverse_proxy localhost:3000
        }
}

api.anexomail.com {
        handle /rpc/* {
                reverse_proxy localhost:3200
        }
        handle {
                reverse_proxy localhost:3100
        }
}

aicrm.anexomail.com {
        reverse_proxy localhost:3000
}

runtime.anexomail.com {
        reverse_proxy localhost:3003
}

auth.anexomail.com {
        reverse_proxy localhost:54321
}

storage.anexomail.com {
        reverse_proxy localhost:9000
}

cdn.anexomail.com {
        root * /opt/anexomail/storage/cdn
        encode gzip zstd
        file_server
}

docs.anexomail.com {
        reverse_proxy localhost:3004
}

status.anexomail.com {
        reverse_proxy localhost:3005
}

preview.anexomail.com {
        reverse_proxy localhost:3006
}

sandbox.anexomail.com {
        reverse_proxy localhost:3007
}

settings.anexomail.com {
        reverse_proxy localhost:3008
}

admin.anexomail.com {
        reverse_proxy localhost:3009
}

mail.anexomail.com {
        respond "ANEXOMAIL Mail Gateway Ready" 200
}

founderworkspace.anexomail.com {
        @founder {
        }
        handle @founder {
                reverse_proxy localhost:3000
        }
        handle {
                respond "Access Denied: Founder Only." 403
        }
}

aiemail.anexomail.com {
        @founder {
        }
        handle @founder {
                reverse_proxy localhost:3100
        }
        handle {
                respond "Access Denied: Founder Only." 403
        }
}

# ==========================================================
# ANEXOChat — Rust PRIMARY, Bun FALLBACK
#   /rpc/*      -> Rust engine 3200   (tRPC-style, PRIMARY)
#   /wt/*       -> Rust engine 3200   (HTTP/3 handshake path)
#   /api/chat/* -> Bun service 3300   (FALLBACK only)
#   /           -> Node SSR 3000      (ANEXOChat UI)
# Note: asli WebTransport/QUIC session udp/3443 par SEEDHA Rust engine se banti
# hai (Caddy reverse proxy WebTransport datagrams carry nahi karta).
# ==========================================================
anexochat.anexomail.com {
        encode gzip zstd
        handle /rpc/* {
                reverse_proxy localhost:3200
        }
        handle /wt/* {
                reverse_proxy localhost:3200
        }
        handle /api/chat/* {
                reverse_proxy localhost:3300
        }
        handle {
                reverse_proxy localhost:3000
        }
}
```

## 3) Verify (tarteeb se)

```bash
# PRIMARY Rust
curl -s http://127.0.0.1:3200/rpc/health | head -20
curl -sk https://anexochat.anexomail.com/rpc/health | head -20
# WebTransport UDP listener
ss -lun | grep 3443
# FALLBACK Bun (sirf backup)
curl -s http://127.0.0.1:3300/health
# gate: token ke bina 401, Basic/Pro token par 403 chat_not_entitled
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://127.0.0.1:3200/rpc/chat.bootstrap
```

Expected: Rust health `role: "primary"`, `webtransport: "live"` (cert lagne ke baad),
`/rpc/chat.bootstrap` bina token `401`.

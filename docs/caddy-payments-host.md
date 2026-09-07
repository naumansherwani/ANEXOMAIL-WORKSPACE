# CADDY — `payments.anexomail.com` (Polar ingress, locked 7 Sep 2026)

Payments ka ingress **boring** hai: koi QUIC/WebTransport mandatory nahi, sirf HTTPS.
QUIC/WT hamari internal services ke beech rahega, Polar ke saath kabhi nahi.

```text
Polar  ──HTTPS──►  payments.anexomail.com  ──►  Caddy  ──►  127.0.0.1:3400
```

## 1. DNS (ek dafa)

| Type | Name | Value |
|---|---|---|
| A | `payments` | `88.198.208.90` |

## 2. Caddyfile — naya site block (poora, jaisa hai waisa paste)

`/etc/caddy/Caddyfile` ke akhir mein add karo. Yeh block **kisi doosre host ke andar nahi**
jaata — apna alag site block hai:

```caddyfile
# ============================================================================
# PAYMENTS INGRESS — Polar webhook + checkout (polar-rust-payment :3400)
# LOCK: sirf /api/v1/* engine ko jaata hai. Baqi sab 404. Koi app, koi asset nahi.
# ============================================================================
payments.anexomail.com {
	encode zstd gzip

	header {
		Strict-Transport-Security "max-age=31536000; includeSubDomains"
		X-Content-Type-Options "nosniff"
		Referrer-Policy "no-referrer"
		-Server
	}

	# webhook + checkout + billing — dedicated Rust engine
	handle /api/v1/* {
		reverse_proxy 127.0.0.1:3400 {
			header_up X-Forwarded-Host {host}
			transport http {
				read_timeout 30s
				write_timeout 30s
			}
		}
	}

	# engine sehat (monitoring only)
	handle /health   { reverse_proxy 127.0.0.1:3400 }
	handle /ready    { reverse_proxy 127.0.0.1:3400 }

	# metrics awam ke liye nahi — sirf server se
	handle /metrics {
		@notlocal not remote_ip 127.0.0.1 88.198.208.90
		respond @notlocal 404
		reverse_proxy 127.0.0.1:3400
	}

	handle {
		respond "Not Found" 404
	}

	log {
		output file /var/log/caddy/payments.log
		format json
	}
}
```

```bash
caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy
curl -s https://payments.anexomail.com/health
```

## 3. Polar dashboard

Settings → Webhooks → endpoint **ANEXOMAIL Production Webhook**:

- URL: `https://payments.anexomail.com/api/v1/polar-webhook`
- Format: **Raw**
- Secret: wahi jo `/opt/polar-rust-payment/.env` mein hai (`whsec_...`)

Purana `https://anexomail.com/api/v1/polar-webhook` chalta rehta hai (bridge) — magar
dashboard mein sirf `payments.` wala URL rakho.

## 4. Sach check (5 second)

```bash
curl -s https://payments.anexomail.com/ready
curl -s -o /dev/null -w "%{http_code}\n" -X POST https://payments.anexomail.com/api/v1/polar-webhook
# 401 = ingress theek, engine ne bina signature reject kiya (yehi expected hai)
```

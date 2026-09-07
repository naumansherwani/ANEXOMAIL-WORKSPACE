# CADDY — `payments.anexomail.com` (Polar ingress, locked 7 Sep 2026)

Ingress par **HTTP/1.1 + HTTP/2 + HTTP/3 (QUIC)** teeno ON hain — Caddy default yehi hai
(TLS 1.3, `Alt-Svc: h3` advertise). Farq sirf itna: HTTP/3 **mandatory nahi** — Polar jis
protocol par aaye (aam tor par HTTP/1.1) woh chalega, aur jo client h3 support karta hai
usay h3 mil jaayega. UDP 443 firewall mein khula hona zaroori hai, warna h3 chup-chaap
fallback kar jaayega.

```text
Polar / koi bhi client ──h1 · h2 · h3(QUIC)──►  payments.anexomail.com  ──►  Caddy  ──►  127.0.0.1:3400
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


## 5. HTTP/3 (QUIC) — firewall (ek dafa)

```bash
ufw allow 443/udp
ufw allow 443/tcp
systemctl reload caddy
curl -sI --http3 https://payments.anexomail.com/health | head -3   # h3 sach check
curl -sI https://payments.anexomail.com/health | grep -i alt-svc    # Alt-Svc: h3=":443"
```

h3 na chale to bhi payments safe hain — client khud h2/h1 par fallback karta hai.

## 6. DO ENDPOINT RULE (mashwara, locked)

Ek hi URL par jump karna khatarnak hai (DNS/TLS ke daoran koi event gir sakta hai).
Is liye **dono endpoints hamesha zinda rehte hain**:

| # | URL | Kirdaar |
|---|---|---|
| PRIMARY | `https://payments.anexomail.com/api/v1/polar-webhook` | dedicated ingress → :3400 seedha |
| BACKUP | `https://anexomail.com/api/v1/polar-webhook` | purana bridge → wahi :3400 |

Dono ek hi engine, ek hi `event_id` unique constraint — is liye agar Polar dono par
bhejay to bhi **duplicate insert nahi hota**. Yeh design se safe hai.

**Polar dashboard ka mashwara:** do webhook endpoints banayen —
1. `ANEXOMAIL Production Webhook` → `payments.` wala URL (primary)
2. `ANEXOMAIL Backup Webhook` → `anexomail.com` wala URL (backup, kabhi delete nahi)

Dono ka secret **ek hi** rakhen (`.env` wala `whsec_...`), warna backup 401 dega.

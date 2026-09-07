# CADDY — `polarpayments.anexomail.com` (Polar ingress, locked 7 Sep 2026)

Ingress par **HTTP/1.1 + HTTP/2 + HTTP/3 (QUIC)** teeno ON hain — Caddy default yehi hai
(TLS 1.3, `Alt-Svc: h3` advertise). Farq sirf itna: HTTP/3 **mandatory nahi** — Polar jis
protocol par aaye (aam tor par HTTP/1.1) woh chalega, aur jo client h3 support karta hai
usay h3 mil jaayega. UDP 443 firewall mein khula hona zaroori hai, warna h3 chup-chaap
fallback kar jaayega.

```text
Polar / koi bhi client ──h1 · h2 · h3(QUIC)──►  polarpayments.anexomail.com  ──►  Caddy  ──►  127.0.0.1:3400
```


## 1. DNS (ek dafa)

| Type | Name | Value |
|---|---|---|
| A | `polarpayments` | `62.238.98.98` |

## 2. Caddyfile — repo se auto-install

Nauman koi Caddy block manually paste nahi karta. Repo ka
`server/rust/polar-payment/polarpayments.Caddyfile` deploy script khud
`/etc/caddy/sites/polarpayments.caddy` mein sync karta hai, main Caddyfile mein ek dafa
glob import add karta hai, validate karke reload karta hai. Existing `anexomail.com`
site block aur us ka live webhook **bilkul touch nahi hota**.

```caddyfile
# ============================================================================
# PAYMENTS INGRESS — Polar webhook + checkout (polar-rust-payment :3400)
# LOCK: sirf /api/v1/* engine ko jaata hai. Baqi sab 404. Koi app, koi asset nahi.
# ============================================================================
polarpayments.anexomail.com {
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
		@notlocal not remote_ip 127.0.0.1 ::1 62.238.98.98
		respond @notlocal 404
		reverse_proxy 127.0.0.1:3400
	}

	handle {
		respond "Not Found" 404
	}

	log {
		output file /var/log/caddy/polarpayments.log
		format json
	}
}
```

Yeh block documentation copy hai; authority repo ki `.Caddyfile` file hai aur deploy
command hi isay install karta hai.

## 3. Polar dashboard

Settings → Webhooks → endpoint **ANEXOMAIL Production Webhook**:

- URL: `https://polarpayments.anexomail.com/api/v1/polar-webhook`
- Format: **Raw**
- API version: **2026-04**
- Secret: Polar har endpoint ke liye khud banata hai; Rust engine `POLAR_ACCESS_TOKEN`
  se dono secrets auto-load karti hai. `.env` wala `POLAR_WEBHOOK_SECRET` fallback hai.
- Events: `order.paid`, `subscription.created`, `subscription.active`,
  `subscription.past_due`, `subscription.canceled`, `subscription.revoked`,
  `subscription.uncanceled` — aur koi event nahi.

Purana `https://anexomail.com/api/v1/polar-webhook` pehle ki tarah live rehta hai.
Naya host replacement nahi; Polar dashboard mein **do alag endpoints** rehte hain.

## 4. Sach check (5 second)

```bash
curl -s https://polarpayments.anexomail.com/ready
curl -s -o /dev/null -w "%{http_code}\n" -X POST https://polarpayments.anexomail.com/api/v1/polar-webhook
# 401 = ingress theek, engine ne bina signature reject kiya (yehi expected hai)
```


## 5. HTTP/3 (QUIC) — firewall (ek dafa)

```bash
ufw allow 443/udp
ufw allow 443/tcp
systemctl reload caddy
curl -sI https://polarpayments.anexomail.com/health | grep -i '^alt-svc:'
# expected: Alt-Svc mein h3=":443" — installed curl mein --http3 na ho tab bhi yeh check chalta hai
```

`Alt-Svc: h3=":443"` ka matlab Caddy HTTP/3 advertise kar raha hai. Local curl build
`--http3` support nahi karti, is liye us flag ko deploy/test commands mein use nahi karte.
Polar jis supported protocol par aaye us par webhook chalega; h3 unavailable ho to h2/h1
fallback payment ko nahi rokta. WebTransport/QUIC ka primary mandate ANEXOChat/Rust realtime
aur large-file transport par apni jagah zinda hai.

## 6. DO ENDPOINT RULE (mashwara, locked)

Ek hi URL par jump karna khatarnak hai (DNS/TLS ke daoran koi event gir sakta hai).
Is liye **dono endpoints hamesha zinda rehte hain**:

| # | URL | Kirdaar |
|---|---|---|
| PRIMARY | `https://polarpayments.anexomail.com/api/v1/polar-webhook` | dedicated ingress → :3400 seedha |
| BACKUP | `https://anexomail.com/api/v1/polar-webhook` | pehle se live direct ingress → wahi :3400 |

Dono ek hi engine, ek hi `event_id` unique constraint — is liye agar Polar dono par
bhejay to bhi **duplicate insert nahi hota**. Yeh design se safe hai.

**Polar dashboard ka mashwara:** do webhook endpoints banayen —
1. `ANEXOMAIL Production Webhook` → `polarpayments.` wala URL (primary)
2. `ANEXOMAIL Backup Webhook` → `anexomail.com` wala URL (backup, kabhi delete nahi)

Polar dono endpoints ke alag secrets banata hai. Rust engine dono ko Polar API se
auto-load karti hai; server par secret copy/paste ya `.env` overwrite nahi hota.

## 7. Nauman ka poora kaam

1. DNS mein `polarpayments` A record → `62.238.98.98`.
2. Polar dashboard mein upar wale **do endpoints** rakhen; purana delete/replace na karein.
3. Server 2 par sirf:

```bash
cd /opt/anexomail-web && git pull && bash server/rust/polar-payment/deploy.sh
```

Script engine, Caddy second host, TCP/UDP 443, validation, reload aur health/Alt-Svc checks
khud karti hai. Koi server file overwrite/paste nahi.

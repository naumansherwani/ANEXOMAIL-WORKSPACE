# ANEXOVideoChat · PHASE 10A — coturn TURN + env (copy-paste)

Host lock: **anexovideocall.anexomail.com** (founder ka chuna hua naam).
Rule: P2P preferred, TURN automatic fallback. TURN secret **kabhi** frontend pe nahi.

---

## 0) DNS pehle (varna `videocall:000` hi aata rahega)

Cloudflare/DNS panel:

```
A   anexovideocall   <Server 2 IP: 88.198.208.90>   Proxy: OFF (DNS only — TURN UDP proxy nahi hota)
```

Verify:

```bash
dig +short anexovideocall.anexomail.com
curl -s -o /dev/null -w "videocall:%{http_code}\n" https://anexovideocall.anexomail.com
```

## 1) coturn install (Server 2)

```bash
apt-get update && apt-get install -y coturn
sed -i 's/^#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn
grep -q TURNSERVER_ENABLED=1 /etc/default/coturn || echo "TURNSERVER_ENABLED=1" >> /etc/default/coturn
TURN_SECRET=$(openssl rand -hex 32); echo "TURN_SECRET=$TURN_SECRET"   # ise sambhal lo
```

## 2) /etc/turnserver.conf (nano overwrite — poori file)

```bash
cp /etc/turnserver.conf /etc/turnserver.conf.bak.$(date +%s) 2>/dev/null
nano /etc/turnserver.conf
```

```conf
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
external-ip=88.198.208.90
realm=anexovideocall.anexomail.com
server-name=anexovideocall.anexomail.com

# Ephemeral REST credentials (HMAC-SHA1) — koi permanent user nahi
use-auth-secret
static-auth-secret=REPLACE_WITH_TURN_SECRET

fingerprint
no-cli
no-multicast-peers
no-tlsv1
no-tlsv1_1
min-port=49152
max-port=49500
user-quota=12
total-quota=600
bps-capacity=0

cert=/etc/anexochat/turn/fullchain.pem
pkey=/etc/anexochat/turn/privkey.pem

# Private range relay band (SSRF/scan protection)
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
```

## 3) TLS cert (Caddy jo cert le chuka hai wahi coturn ko do)

```bash
mkdir -p /etc/anexochat/turn
CERT_DIR=$(find /var/lib/caddy/.local/share/caddy/certificates -type d -name '*anexovideocall.anexomail.com*' | head -1)
cp "$CERT_DIR"/anexovideocall.anexomail.com.crt /etc/anexochat/turn/fullchain.pem
cp "$CERT_DIR"/anexovideocall.anexomail.com.key /etc/anexochat/turn/privkey.pem
chown turnserver:turnserver /etc/anexochat/turn/*.pem && chmod 640 /etc/anexochat/turn/*.pem
```

## 4) Firewall + start

```bash
ufw allow 3478/udp && ufw allow 3478/tcp && ufw allow 5349/tcp && ufw allow 49152:49500/udp
systemctl enable coturn && systemctl restart coturn
systemctl --no-pager -l status coturn | head -20
ss -lunp | grep 3478
```

## 5) Backend env

`/opt/anexomail/.env` (Bun fallback) **aur** `/opt/anexomail-rust/.env` (PRIMARY) — dono mein:

```
TURN_HOST=anexovideocall.anexomail.com
TURN_SECRET=<step 1 ka secret>
TURN_TTL_SECONDS=3600
```

```bash
pm2 restart anexochat anexomail-rust
```

## 6) Frontend env (`/opt/anexomail-web/.env`) — realtime signaling ke liye

```
VITE_SUPABASE4_URL=https://<ref>.supabase.co
VITE_SUPABASE4_PUBLISHABLE_KEY=<publishable/anon key — service role KABHI nahi>
```

```bash
cd /opt/anexomail-web && git pull && bun install && bun run build:node && pm2 restart anexomail-web
```

## 7) Verify (asli reading, claim nahi)

```bash
# TURN creds issuer (Rust PRIMARY)
curl -s -X POST http://127.0.0.1:3200/rpc/chat.turn.credentials \
  -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' -d '{"input":{}}' | head -20

# Bun fallback
curl -s http://127.0.0.1:3300/api/chat/video/turn -H "authorization: Bearer $TOKEN" | head -20
```

Browser: `/app/chat` → video call → badge par tap → RTT/jitter/loss/path dikhega.
Founder aggregates: `/app/founder/calls`.

Note: TURN media UDP par chalta hai — Caddy ke through **nahi** jata. Caddy sirf
us hostname ka HTTPS/cert handle karta hai; relay ports seedhe coturn pe hain.

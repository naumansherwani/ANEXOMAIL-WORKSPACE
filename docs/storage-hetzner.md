# ANEXOMAIL — Storage Ops (Hetzner Storage Box + volumes)

Phase 48 ka physical side. Quota LOGICAL hai (Supabase = truth), weight Storage Box par.
Rule: **Supabase = truth, Storage Box = weight, Hetzner = egress (free 20TB).**

---

## 1) Storage Box order + SSH key (Hetzner Robot)

1. Robot → Storage Box → BX11 (1TB ≈ €3.9/mo) order karo.
2. Storage Box settings mein: **SSH support ON**, **External reachability ON**.
3. Server 2 par key banao aur bhejo:

```bash
ssh-keygen -t ed25519 -f /root/.ssh/storagebox -N ''
# u123456 = tumhara Storage Box username
cat /root/.ssh/storagebox.pub | ssh -p23 u123456@u123456.your-storagebox.de install-ssh-key
```

## 2) Mount (systemd, reboot-safe)

```bash
apt-get install -y sshfs
mkdir -p /mnt/anexomail-box

cat > /etc/systemd/system/mnt-anexomail\\x2dbox.mount <<'EOF'
[Unit]
Description=ANEXOMAIL Hetzner Storage Box
After=network-online.target
Wants=network-online.target

[Mount]
What=u123456@u123456.your-storagebox.de:/home/anexomail
Where=/mnt/anexomail-box
Type=fuse.sshfs
Options=_netdev,allow_other,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,IdentityFile=/root/.ssh/storagebox,port=23,uid=8,gid=8

[Install]
WantedBy=multi-user.target
EOF

ssh -p23 u123456@u123456.your-storagebox.de -i /root/.ssh/storagebox 'mkdir -p /home/anexomail/attachments'
systemctl daemon-reload
systemctl enable --now 'mnt-anexomail\x2dbox.mount'
df -h /mnt/anexomail-box
```

## 3) Volume ko `storage_volumes` mein register karo (asli wiring)

Founder token se (frontend `/app/storage` bhi isi route ko chhoo sakta hai):

```bash
curl -s -X POST http://127.0.0.1:3100/api/founder/storage/volume \
  -H "authorization: Bearer $FOUNDER_JWT" \
  -H 'content-type: application/json' \
  -d '{"name":"hetzner-box-1","kind":"storage_box","capacity_bytes":1099511627776,
       "endpoint":"/mnt/anexomail-box/attachments","drain_others":true}'
```

`drain_others:true` = purana `server2-local` volume `accepts_new=false` ho jata hai.
Naye attachments Storage Box par jaate hain, purana data jahan hai wahin readable rehta hai — **zero migration, zero UI change**.

Radar dekhne ke liye:

```bash
curl -s http://127.0.0.1:3100/api/founder/storage/volumes -H "authorization: Bearer $FOUNDER_JWT" | head -40
```

## 4) Capacity sweep cron (85% par auto-drain)

```bash
( crontab -l 2>/dev/null; echo '7 * * * * curl -s -X POST http://127.0.0.1:3100/api/internal/storage/sweep -H "x-cron-secret: '"$CRON_SECRET"'" >/dev/null' ) | crontab -
```

## 5) Dovecot: mail local disk, attachments Storage Box

Mail body chhoti hoti hai → local NVMe (fast). Attachments bhari → Box (sasta).

```
# /etc/dovecot/conf.d/90-anexomail-storage.conf
mail_location = maildir:/var/mail/vhosts/%d/%n

# SIS: ek jaisi attachment ek hi dafa disk par (dedupe = asli bachat)
plugin {
  sis_dir = /mnt/anexomail-box/attachments
  mail_attachment_dir = /mnt/anexomail-box/attachments
  mail_attachment_min_size = 128k
  mail_attachment_fs = sis posix
  mail_attachment_hash = %{sha1}
  quota = maildir:User quota
  quota_grace = 0%%
}
```

```bash
doveconf -n > /dev/null && systemctl restart dovecot
```

Quota enforcement Dovecot ka nahi — **hamara** hai (`/api/internal/storage/accept`).
Full mailbox par Postfix hook `452` deta hai → sender retry karta hai, mail **hold**, kabhi bounce/discard nahi.

## 6) Caddy: download/serving hamesha Hetzner se (Supabase se kabhi nahi)

Egress asli katil hai: Supabase $0.09/GB, Hetzner 20TB free.

```caddyfile
anexomail.com {
  encode zstd gzip

  # attachment/file download — Box se seedha, Supabase egress zero
  handle_path /files/* {
    root * /mnt/anexomail-box/attachments
    header Cache-Control "private, max-age=31536000, immutable"
    header X-Content-Type-Options nosniff
    file_server
  }

  handle /api/* { reverse_proxy 127.0.0.1:3100 }
  handle { reverse_proxy 127.0.0.1:3000 }
}
```

> `/files/*` sirf signed path ke saath serve karo — backend `storage_commit` ke waqt
> path deta hai; koi directory listing nahi (`file_server` browse OFF by default).

## 7) Launch safety caps

| Plan | Aaj bik sakta? | Sharat |
|---|---|---|
| Basic 5GB×3 | Haan | thin provisioning, 80GB par 100+ customers |
| Pro 10GB×5 | Haan | radar 70% par alert |
| Business 25GB | Haan | radar + Box ready |
| Business Pro 1TB pool | **Storage Box attach hone ke baad** | 1 customer = 1TB claim |

Sach becho, GB nahi: "quota logical hai — mailbox full ho to bhi tumhara mail wapas
nahi jata, hold hota hai." Google/Zoho bounce karte hain, hum hold karte hain.

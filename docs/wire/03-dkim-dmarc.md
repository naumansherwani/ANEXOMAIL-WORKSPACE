# Step 3 — DKIM (OpenDKIM) + DMARC (OpenDMARC)

## 3A. DKIM key banao

```bash
mkdir -p /etc/opendkim/keys/anexomail.com
opendkim-genkey -b 2048 -d anexomail.com -D /etc/opendkim/keys/anexomail.com -s mail -v
chown -R opendkim:opendkim /etc/opendkim
chmod 600 /etc/opendkim/keys/anexomail.com/mail.private

cat > /etc/opendkim.conf <<'EOF'
Syslog                  yes
UMask                   007
Mode                    sv
Canonicalization        relaxed/simple
SubDomains              no
OversignHeaders         From
Socket                  inet:8891@127.0.0.1
PidFile                 /run/opendkim/opendkim.pid
UserID                  opendkim
KeyTable                /etc/opendkim/key.table
SigningTable            refile:/etc/opendkim/signing.table
ExternalIgnoreList      /etc/opendkim/trusted.hosts
InternalHosts           /etc/opendkim/trusted.hosts
EOF

echo "mail._domainkey.anexomail.com anexomail.com:mail:/etc/opendkim/keys/anexomail.com/mail.private" > /etc/opendkim/key.table
echo "*@anexomail.com mail._domainkey.anexomail.com" > /etc/opendkim/signing.table
printf "127.0.0.1\nlocalhost\nmail.anexomail.com\nanexomail.com\n" > /etc/opendkim/trusted.hosts

cat > /etc/opendmarc.conf <<'EOF'
Syslog true
Socket inet:8893@127.0.0.1
PidFile /run/opendmarc/opendmarc.pid
UserID opendmarc:opendmarc
IgnoreHosts /etc/opendkim/trusted.hosts
RejectFailures false
TrustedAuthservIDs mail.anexomail.com
AuthservID mail.anexomail.com
EOF

systemctl enable --now opendkim opendmarc
systemctl restart postfix
systemctl --no-pager status opendkim opendmarc | head -20
```

## 3B. DKIM record DNS mein daalo

```bash
cat /etc/opendkim/keys/anexomail.com/mail.txt
```

Output se sirf quotes ke andar ka `v=DKIM1; k=rsa; p=...` (saare hisse jode kar, spaces hata kar)
ek TXT record mein daalo:

- Name: `mail._domainkey`
- Value: `v=DKIM1; h=sha256; k=rsa; p=<POORI KEY EK LINE MEIN>`

## 3C. Verify (gate)

```bash
dig +short TXT mail._domainkey.anexomail.com
opendkim-testkey -d anexomail.com -s mail -vvv
```

`key OK` aur `key not secure` (yeh DNSSEC ki baat hai, ignore) chalega.

Phir asli signing test — Gmail par mail bhejo:

```bash
echo "dkim test $(date -u)" | mail -s "ANEXOMAIL DKIM test" -a "From: hello@anexomail.com" <TUMHARA_GMAIL>
tail -n 30 /var/log/mail.log
```

Gmail mein mail khol kar **Show original**: `SPF: PASS`, `DKIM: PASS`, `DMARC: PASS` teeno.
Teeno pass na ho to yahin ruko — inbound step ka koi faida nahi.

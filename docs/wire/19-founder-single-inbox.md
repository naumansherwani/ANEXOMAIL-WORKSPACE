# 19 — FOUNDER SINGLE INBOX + RECOVERY (status: READY)

Founder rule (locked 8 Sep 2026):

- Founder ka **ek hi inbox**: `naumansherwani.founder@anexomail.com`
- anexomail.com ki har company address (hello, billing, resolved, trials, abuse,
  dmarc, moveyourbusiness, leo) apni box mein bhi rehti hai **aur** founder inbox
  mein bhi copy hoti hai — kuch khota nahi, routing zinda rehti hai.
- Sab founder-side logins ka **password EK** (`FOUNDER_MAIL_PASSWORD` in
  `/etc/anexomail/mail.env`, chmod 640 root:vmail; repo mein kabhi nahi).
- **Recovery account:** `anexomail27@gmail.com` (`FOUNDER_MAIL_RECOVERY`).
- Founder par awam ke limits (trial, plan, credits, fair-use) apply nahi hote.
- **Awam ka data breach kabhi nahi** — customer mailboxes/conversations founder
  inbox mein nahi aatin; sirf anexomail.com ki apni company addresses aati hain.
  SQL mein yeh `awam_data_access = false` CHECK constraint se locked hai.

## Steps

1. Database truth (SUPABASE #4 SQL editor):

```bash
cd /opt/anexomail-web && bash sql/run.sh sql/phase55_founder_single_inbox.sql
```

2. Mail server (single password + unified copies):

```bash
cd /opt/anexomail-web && git pull && bash server/mail/deploy-mail.sh
```

3. Verify (password print nahi hota):

```bash
sudo grep -c '^FOUNDER_MAIL_PASSWORD=' /etc/anexomail/mail.env      # 1
sudo cut -d: -f1 /etc/dovecot/users                                  # 10 addresses
sudo postmap -q hello@anexomail.com hash:/etc/postfix/valias         # hello@… , naumansherwani.founder@…
bash server/gates/mail-gate.sh
```

## Password kaise dekhna hai (sirf server par, sirf founder)

```bash
sudo grep '^FOUNDER_MAIL_PASSWORD=' /etc/anexomail/mail.env | cut -d= -f2-
```

IMAP/SMTP login: user `naumansherwani.founder@anexomail.com`, server
`mail.anexomail.com`, IMAP 993 (SSL), SMTP 465 (SSL).

Status **DONE** sirf tab jab step 3 ka output green ho.

## Update 8 Sep 2026 — final list

`trials@`, `support@`, `nauman@` khatam; `postmaster@` · `abuse@` · `dmarc@` ab
sirf forward hain (`resolved@` par). Founder inbox mein copy sirf company
addresses ki: hello, moveyourbusiness, resolved, billing, leo. Family accounts
(`humzasherwani@`, `raanasherwani@`) ki mail founder inbox mein kabhi nahi.
Tafseel: `docs/wire/20-final-addresses.md`.

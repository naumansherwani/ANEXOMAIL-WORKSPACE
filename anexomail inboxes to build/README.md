# ANEXOMAIL — Inboxes to build

Founder copy-paste list. Do domain: **anexomail.com** (product) aur **nexatect.com** (parent + AI org).
Har mailbox ke saath: mera maqsad, kis ko dikhta hai, aur kya isko real mailbox chahiye ya sirf alias.

---

## A) anexomail.com — AWAM ke liye (public, website par likha hua)

| Address | Kaam | Type |
| --- | --- | --- |
| `hello@anexomail.com` | Support + saari enquiries. Har important page ke footer par. | Real mailbox |
| `moveyourbusiness@anexomail.com` | Sirf Managed Move-In leads (£500/£1,500/£2,000/£3,000). | Real mailbox |
| `support@anexomail.com` | Alias -> `hello@` (log ki aadat ke liye). | Alias |
| `billing@anexomail.com` | Invoices, Polar receipts, plan sawal. | Real mailbox |
| `noreply@anexomail.com` | Sirf outbound system mail (verify, reset, receipts). Inbound band. | Send-only |

## B) anexomail.com — TRIAL + onboarding automation

| Address | Kaam | Type |
| --- | --- | --- |
| `trials@anexomail.com` | 2-day trial start/expiry mails ka reply-to. | Real mailbox |
| `abuse@anexomail.com` | RFC-required, spam/abuse reports. | Real mailbox |
| `postmaster@anexomail.com` | RFC-required, mail-server reports. | Alias -> abuse@ |
| `dmarc@anexomail.com` | DMARC rua/ruf reports. | Real mailbox |

## C) anexomail.com — FOUNDER

| Address | Kaam | Type |
| --- | --- | --- |
| `naumansherwani.founder@anexomail.com` | Founder primary (product side). | Real mailbox |
| `nauman@anexomail.com` | Chhota alias -> founder primary. | Alias |
| `leo@anexomail.com` | LEO (ANEXOMAIL ka AI) — auto-reply pipeline. | Real mailbox |

## D) nexatect.com — PARENT + AI ORG (awam ko kabhi nahi dikhta)

| Address | Kaam | Type |
| --- | --- | --- |
| `naumansherwani.founder@nexatect.com` | Founder / Chairman. | Real mailbox |
| `jimmyjohn@nexatect.com` | Jimmy John — Supreme Commander (Server 1 brain). | Real mailbox |
| `sherlock@nexatect.com` | Sherlock — deputy / validation. | Real mailbox |
| `resolved@nexatect.com` | Silent internal BCC log of every resolved support reply. | Real mailbox |

### D2) Industry AI agents (nexatect.com)

| Address | Agent |
| --- | --- |
| `aria.tth@nexatect.com` | Aria — travel, tourism & hospitality |
| `atlas.logistics@nexatect.com` | Atlas — logistics |
| `orion.airlines@nexatect.com` | Orion — airlines |
| `kai.railways@nexatect.com` | Kai — railways |
| `sage.education@nexatect.com` | Sage — education |
| `vega.ee@nexatect.com` | Vega — energy & environment |
| `rex@nexatect.com` | Rex — legal / compliance |
| `lyra@nexatect.com` | Lyra — media & content |

---

## E) Build order (mera mashwara)

1. `hello@` · `moveyourbusiness@` · `billing@` · `noreply@` — website already inhi par khadi hai.
2. `abuse@` · `postmaster@` · `dmarc@` — deliverability ke liye lazmi.
3. `trials@` — 2-day trial mails.
4. Founder + `leo@`.
5. nexatect.com AI agents (already zinda hain, sirf audit).

## F) Rule

- Awam ko sirf **A** section ke addresses dikhte hain. B/C/D kabhi public copy mein nahi.
- Har real mailbox par SPF/DKIM/DMARC green hona zaroori — `/ownership` page isi ka proof dikhata hai.

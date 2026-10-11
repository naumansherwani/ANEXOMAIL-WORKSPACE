# BUG — `resolved@anexomail.com` basic (test) account mein nazar aa raha hai

Status: **TODO** (11 Oct 2026, founder ne report kiya)

## Kya dikha
- Basic account (org `16e02f4b-cc52-438f-a2e7-bef4ef7f81cb`) ke sidebar Accounts mein `resolved@anexomail.com`.
- Basic account ke inbox mein Google DMARC report thread (`noreply-dmarc-support@google.com`, "Report domain: anexomail.com") — yeh system/support mail hai.

## Sahi behaviour (docs/wire/20-final-addresses.md)
- `resolved@anexomail.com` = platform ka support/system inbox (postmaster@, abuse@, dmarc@, support@ sab yahin forward).
- Yeh sirf **founder** ko dikhna chahiye, kisi awam / test org ko nahi.

## Shak (diagnose se confirm hona hai, guess pe fix nahi)
1. `mailboxes` ya `mail_accounts` mein `resolved@` ki row ka `org_id` basic org ka hai (galat org).
2. Ya basic user `org_members` ke zariye founder wali org mein bhi hai.
3. `server/routes/mail.ts` `ctx()` fallback: `mail_accounts` se `ilike(address, userEmail)` — org resolve galat ho sakta hai.

## Fix rule
- Data fix = naya E-series SQL (`docs/cursor-work/sql/E16_…sql`), pehle diagnose output ke baad.
- DONE tab jab basic account mein `resolved@` aur DMARC thread nazar na aaye, aur founder account mein aaye.

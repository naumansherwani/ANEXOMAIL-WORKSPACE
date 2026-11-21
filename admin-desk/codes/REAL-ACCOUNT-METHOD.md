# REAL ACCOUNT METHOD (his 21 Nov 2026 10:41: "yeh real hai ... database se supabase bante hain, tareeka repo ke andar hai, woh tareeka gold codes main save kero")
Saved 21 Nov 2026 10:44 PKT. These are the ONLY ways accounts are made, all with the password TYPED ON HIS SERVER (never chat, never a file, never argv).

## 1. Admin Desk owner (admindesk@anexomail.com) - Desk's own table, NOT Supabase auth
- Table: desk.fadm_owner (AD1), pw_hash = ARGON2ID only (CHECK pw_hash LIKE '$argon2id$%').
- Script: admin-desk/scripts/desk-owner.sh. Reads password twice with read -s, `anexomail-desk hashpw` (admin-desk/server/src/auth.rs, argon2id m=64MiB t=3 p=1) turns stdin into a hash, psql inserts via /etc/anexomail-desk/db.env, one ledger line. Env: OWNER_EMAIL, OWNER_NAME, OWNER_ROLE.
- Line: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/desk-owner.sh)

## 2. Company addresses are ALIASES (his 21 Nov 10:52 word), NOT customer accounts
hello@, moveyourbusiness@, resolved@, billing@, noreply@, leo@, postmaster@, abuse@, dmarc@, naumansherwani.founder@ and admindesk@ are his OWN company's aliases. They are NOT made by the E28 customer signup seed (that was my mistake, script desk-business-account.sh removed 10:5x). How they exist today = read-only look first: admin-desk/scripts/desk-alias-look.sh, then his word.

## Isolation
The Desk binary never reads auth.users or any awam table. Account 2 is awam data made by awam's own seed.

# REAL ACCOUNT METHOD (his 21 Nov 2026 10:41: "yeh real hai ... database se supabase bante hain, tareeka repo ke andar hai, woh tareeka gold codes main save kero")
Saved 21 Nov 2026 10:44 PKT. These are the ONLY ways accounts are made, all with the password TYPED ON HIS SERVER (never chat, never a file, never argv).

## 1. Admin Desk owner (admindesk@anexomail.com) - Desk's own table, NOT Supabase auth
- Table: desk.fadm_owner (AD1), pw_hash = ARGON2ID only (CHECK pw_hash LIKE '$argon2id$%').
- Script: admin-desk/scripts/desk-owner.sh. Reads password twice with read -s, `anexomail-desk hashpw` (admin-desk/server/src/auth.rs, argon2id m=64MiB t=3 p=1) turns stdin into a hash, psql inserts via /etc/anexomail-desk/db.env, one ledger line. Env: OWNER_EMAIL, OWNER_NAME, OWNER_ROLE.
- Line: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/desk-owner.sh)

## 2. REAL awam Business account (Supabase, auth.users) - the repo's own real-signup path
- Method = docs/cursor-work/sql/E28_seed_buyer_test_account.sql (header explains): server/routes/auth.ts /signup (auth.users + auth.identities with crypt(pw, gen_salt('bf')), account_profiles workspace_kind=business, user_roles, ensure_trial_account_row) -> /identity/claim -> POST /organisations -> entitlement_state (plan) -> E23 trigger activates the account exactly as a real payment does. One transaction, rolls back whole on any error.
- Plans proven in the repo: basic, pro, business, business_pro (Premium/Max need their plan rows first, R3p).
- Script: admin-desk/scripts/desk-business-account.sh (asks handle, name, company, domain, plan, then password twice, no echo; runs E28 unchanged). Account = handle@anexomail.com.
- Line: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:admin-desk/scripts/desk-business-account.sh)
- Older random-password helpers (do not use for real people): docs/cursor-work/server/t16-accounts-look.sh, pro-second-user.sh.

## Isolation
The Desk binary never reads auth.users or any awam table. Account 2 is awam data made by awam's own seed.

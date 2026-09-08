# ANEXOMAIL Recovery and Live-Proof Plan

## Maqsad
Existing code ko phenkna nahi; jo real schema, Rust, mail aur UI code bana hua hai usko ek consistent live contract par lana. Koi page ya feature sirf file mojood hone par DONE nahi hoga—browser action, server response aur database proof teenon chahiye.

## Block 1 — Mail queue ko pehle unblock karna
- `server/deploy-all.sh` ko self-verifying banana: phase57 ke baad phase58 lazmi chale; phase58 file/version missing ho to script foran RED ho aur frontend build par na jaye.
- Phase58 ke baad database se `mailboxes.org_id`, `mail_messages.cc_addrs`, aur naya `mail_ingest` body/version verify karna; schema cache reload ke baad API readiness ka wait.
- Purane `/api/mail/deliver` aur Postfix RPC dono ko ek canonical payload/column contract par lana.
- Deferred mail delete nahi hogi: `postqueue -f`, queue reason, inbound DB count aur inbox HTTP proof ek hi gate mein.
- Dovecot `127.0.0.1:143` ko deploy script mein real listener/config ke saath restore karna; gate local IMAP ko separately prove karega.
- PTR DNS manual blocker alag report hoga; woh database delivery failure ke saath mix nahi hoga.

## Block 2 — Real account lifecycle restore karna
- Repo se missing auth/workspace backend sources restore karna taa-ke port 3100 ka build isi repository se ho; kisi hidden old server copy par dependency na rahe.
- Real email/password signup, login, logout, current session, email confirmation, forgot-password, reset-password aur signed-in password change endpoints banana.
- Signup par full profile lena: legal/name, display name, avatar, work role aur preferences; profile user-owned aur database-persisted ho.
- Password field par accessible eye show/hide control; password strength/confirmation aur clear validation.
- Founder identity existing UID/email se server-side validate hogi; founder power public-user data bypass nahi karegi.
- Auth gate: temporary test account create → login → session → password change → old password rejected → new password accepted → logout. Test identity cleanup proof ke baad.

## Block 3 — Founder aur public-user surfaces alag
- `founderworkspace.anexomail.com/<feature>` short paths founder shell mein khulenge; public user ko founder controls/data kabhi nahi.
- Public-user `/app/*` apni clean shell aur apne entitlements ke saath; founder ko har product access magar cross-user mailbox/message read ka automatic right nahi.
- Har linked path ko route inventory se test karna; valid signed-out page auth par jaye, signed-in page meaningful content/data state dikhaye—blank screen/404 pass nahi.

## Block 4 — Real product proofs
- **Mail:** external inbound → Postfix → database → inbox; compose/send → SMTP queue → remote acceptance.
- **ANEXOChat:** founder aur brother ke authenticated accounts se conversation create, message A→B, B→A, database IDs/timestamps, refresh ke baad persistence; Rust primary and Bun fallback separately.
- **Calendar:** real create/update/delete event, participants/time zone/reminder persistence; empty decorative calendar ko pass nahi karna. Existing visual system ko cinematic polish dena only after CRUD proof.
- Baqi products ko route-by-route contract list par check karna: real endpoint/data write/read ho to PASS; backend missing ho to TODO, fake row ya dummy success nahi.

## Block 5 — One-command deployment and evidence
- One command remains:
  `cd /opt/anexomail-web && git pull && bash server/deploy-all.sh`
- Script database → Bun build → Rust → payments → Caddy → services → mail/TURN → all gates ki fixed order mein chalega.
- Final report mein har dot sirf DONE / READY / TODO hoga. DONE ke saath exact live test evidence; failure par exact blocker aur next copy-paste command.

## Technical safeguards
- Bun frontend/runtime; Rust primary engine; Caddy TLS/HTTP3; existing Supabase/PostgreSQL source of truth.
- Secrets sirf protected server env files; output/log/docs mein kabhi nahi.
- Public schema ki har nayi table ke grants + RLS same migration mein.
- Roles separate authority table mein; client storage se founder/admin decision nahi.
- Existing data delete nahi; incompatible legacy table ho to timestamped backup/rename first.

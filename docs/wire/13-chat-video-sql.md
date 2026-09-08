# 13 — ANEXOChat + ANEXOVideoCall SQL (editor mein copy-paste)

Chat gate aur VideoCall gate ki RED lines sirf is liye thin ke yeh phases database
par abhi chali nahi hain (aap ne server-runner chhod kar editor chuna, is liye yeh
files editor se chalengi).

Tarteeb ahem hai — upar se neeche, ek file ek dafa. Har file GitHub par kholo,
poora content copy karo, Supabase SQL Editor mein paste karo, Run.

| # | Repo file | Kya banti hai |
|---|---|---|
| 1 | `anexochat/sql/anexochat_phase01_foundation.sql` | workspaces, conversations, receipts, `chat_access()` |
| 2 | `anexochat/sql/anexochat_phase03_message_engine.sql` | messages, `chat_work_items` |
| 3 | `anexochat/sql/anexochat_phase07_cinema_video.sql` | cinema/video base |
| 4 | `anexochat/sql/anexochat_phase10a_call_engine.sql` | `chat_call_sessions`, `chat_call_stats` |
| 5 | `anexochat/sql/anexochat_phase10b_8k_video.sql` | video quality ladder |
| 6 | `anexochat/sql/anexochat_phase11_attachments.sql` | attachments |
| 7 | `anexochat/sql/anexochat_phase11b_attachment_flag.sql` | attachment flag |
| 8 | `anexochat/sql/anexochat_phase12_continuity.sql` | `chat_drafts`, `chat_positions` |
| 9 | `anexochat/sql/phase13_15_file_engine.sql` | transfer ledger, chunks |
| 10 | `anexochat/sql/phase16_18_file_truth_safety.sql` | `file_evidence`, safety |
| 11 | `anexochat/sql/phase19_22_device_safety_work.sql` | `device_vault`, `safety_*`, `chat_work_events` |
| 12 | `anexochat/sql/phase23_promise_engine.sql` | `promise_recovery_log`, appeals |
| 13 | `anexochat/sql/phase24_decision_ledger.sql` | `chat_decisions`, versions |
| 14 | `anexochat/sql/phase24a_account_integrity.sql` | `account_integrity_log` |
| 15 | `anexochat/sql/phase25_27_timeline_health_provenance.sql` | provenance, important, `commitment_collisions` |
| 16 | `anexochat/sql/phase28_receipts.sql` | `chat_receipt_devices`, certificates, handover |
| 17 | `anexochat/sql/phase29_email_to_chat.sql` | email → chat |
| 18 | `anexochat/sql/phase30_chat_to_email.sql` | chat → email + consent |
| 19 | `anexochat/sql/phase31_file_context.sql` | file context graph |
| 20 | `anexochat/sql/videocall_phase31_call_record.sql` | `chat_call_events`, files, work |
| 21 | `anexochat/sql/videocall_phase31a_lightspeed.sql` | rings, SFU rooms, survival |

## Verify (editor mein, aakhir mein ek dafa)

```sql
select t as table_name,
       (select count(*) > 0 from information_schema.tables
         where table_schema = 'public' and table_name = t) as exists
from unnest(array[
  'chat_conversations','chat_messages','chat_message_receipts','chat_work_items',
  'chat_work_events','chat_transfer_ledger','file_evidence','device_vault',
  'safety_reports','promise_recovery_log','chat_decisions','account_integrity_log',
  'chat_message_provenance','commitment_collisions','chat_receipt_devices',
  'chat_drafts','chat_positions','chat_call_sessions','chat_call_events',
  'chat_call_rings','chat_call_sfu_rooms'
]) as t
order by 2, 1;
```

Har row ka `exists = true` chahiye. Uske baad server par:

```bash
cd /opt/anexomail-web && bash server/gates/chat-gate.sh
```

```bash
cd /opt/anexomail-web && bash server/gates/videocall-gate.sh
```

## Sirf aap ka manual hissa (registrar par, ek dafa)

Chat/VideoCall host ka `000000` DNS ki wajah se hai — server theek hai:

| Type | Name | Value |
|---|---|---|
| A | `anexochat` | `62.238.98.98` |
| A | `anexovideocall` | `62.238.98.98` |
| TXT | `mail._domainkey` | DKIM value (Wire 06 ke output se) |
| PTR | reverse DNS (Hetzner console) | `mail.anexomail.com` |

# ANEXOMAIL — PACKAGE FEATURE MAP (locked 7 Sep 2026)

Rule: har phase ke naye features ka package mapping isi file mein likha jata hai
(DB authority tables ke saath). Focus: **Business · Business Pro · AI plans**.
Basic/Pro ko sirf woh feature jo unke plan ki rooh se banta ho.
Surface parity (anexomail.com · founderworkspace.anexomail.com · ai.anexomail.com)
alag cheez hai — code teeno par same, entitlement plan se.

## Phase 13/14/15 — File engine

DB truth: `public.file_plan_limits` + `file_plan_for()` + `file_pool_state()`.

| Feature | Basic | Pro | Business | Business Pro | AI Pro | AI Business | AI Executive |
|---|---|---|---|---|---|---|---|
| Mail attachments (`/files/*`) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Chat file transfer engine | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Max single file | — | — | 2 GB | 5 GB | 2 GB | 5 GB | 5 GB |
| Storage pool | — | — | 256 GB | 1 TB | 256 GB | 1 TB | 2 TB |
| Monthly transfer volume | — | — | 5 TB | unlimited | 5 TB | unlimited | unlimited |
| Resumable transfer (94% se resume) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Per-chunk sha256 verify + self-heal | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Concurrent transfers | — | — | 3 | 6 | 4 | 6 | 8 |
| File versions kept | — | — | 10 | 30 | 10 | 30 | 50 |

Founder: `founder_accounts` row = 5 GB file · 1 TB pool · unlimited transfer · 8 concurrent · 50 versions.

Basic/Pro ko chat file engine ZERO — purana ANEXOChat access lock (Basic/Pro ko
ANEXOChat nahi milta) qaayam hai. Un plans ke liye file transfer UI dikhta hai
magar server sach bolta hai: "Not included in your plan."


## Phase 16/17/18 — File truth + self-hosted safety

DB truth: `file_evidence` · `file_type_policy` · `file_scan_jobs` ·
`file_safety_events` · `file_enforcement` · `file_downloads`
(`sql/phase16_18_file_truth_safety.sql`).

| Feature | Basic | Pro | Business | Business Pro | AI Pro | AI Business | AI Executive |
|---|---|---|---|---|---|---|---|
| Evidence chain (Selected→Uploaded→Scanning→Verified→Available→Downloaded) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Append-only evidence rows (step skip mumkin nahi) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| File-type policy (magic bytes + double extension + mime mismatch) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Self-hosted malware scan (local clamd, no external API) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Entropy + archive-bomb protection | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Local content-safety classifier (text-like files only) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Download proof (`file_downloads`) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Safety panel: engines + queue + account standing | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Safety review queue + enforcement history view | — | — | — | ✓ | — | — | ✓ |

LOCK: insaani guftagu kabhi kisi AI API par nahi jati. Safety sirf files par,
aur woh bhi ANEXOMAIL ke apne infra ke andar (deterministic tools + local
clamd). "Delivered" lafz UI mein kabhi nahi — sirf woh step jo DB mein sabit ho.


## Phase 19/20/21/22 — Device vault · trust · safety reporting · work chain

DB truth: `chat_phase_entitlements` + `chat_feature_allowed()` ·
`device_vault` · `device_bans` · `device_vault_policy` · `device_trust_events` ·
`safety_reports` · `safety_report_events` · `safety_enforcement` ·
`safety_reveal_log` · `chat_work_items` (+chain columns) ·
`chat_work_evidence` · `chat_work_events`
(`sql/phase19_22_device_safety_work.sql`).

| Feature | Basic | Pro | Business | Business Pro | AI Pro | AI Business | AI Executive |
|---|---|---|---|---|---|---|---|
| Device safety vault (sealed, non-biometric) | ✓ 2 | ✓ 4 | ✓ 10 | ✓ 50 | ✓ 10 | ✓ 50 | ✓ 100 |
| Device trust list + one-click revoke (session kill) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Report message · person · file · conversation | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Safety review queue + logged evidence reveal | — | — | — | ✓ | — | — | ✓ |
| Enforcement history + device ban list | — | — | — | ✓ | — | — | ✓ |
| Message → Task/Promise/Decision (deterministic) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Work chain: provenance + completion evidence | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Open work objects | — | — | 200 | 5,000 | 200 | 5,000 | 20,000 |
| Work dependencies (blocked until blocker done) | — | — | ✓ | ✓ | — | ✓ | ✓ |
| Star + forward message (messenger basics) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |

LOCK: Phase 19 mein sirf 5 coarse signals (platform class · browser class ·
timezone bucket · screen bucket · language) — canvas/audio/font/webgl signals
client aur server dono taraf discard hote hain. Vault envelope encrypted,
`retain_until` ke baad `device_vault_purge()` se delete. Reviewer ko report ka
content default nahi milta; `safety_report_reveal` bina 12+ character
justification chalti hi nahi aur har reveal `safety_reveal_log` mein hai.
Phase 22 ka parsing DB ke andar deterministic hai — insaani guftagu kisi AI API
par nahi jati. Work object bina evidence `done` nahi ho sakta, aur source
message hide hone par bhi provenance (conversation · sender · sent_at ·
body_hash) zinda rehti hai.

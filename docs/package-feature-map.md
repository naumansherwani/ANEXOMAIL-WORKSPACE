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


## Site-wide — languages · ANEXOChat landing · account integrity (7 Sep 2026)

Yeh plan-gated feature nahi, poori site par hai:

- **30 asli zubaanein** (`src/lib/locales.ts`) — native script, RTL support
  (Urdu · Arabic · Farsi · Hebrew), real nav/CTA translations. Picker nav mein,
  choice `ax.locale`, `<html lang/dir>` set hota hai. Dummy locale mamnu.
- **`/anexochat`** public landing — ANEXOChat + ANEXOVideoCall ke asli features
  (Rust/QUIC, 5GB resumable, evidence chain, self-hosted safety, device trust,
  message→work chain). Nav mein duplicate "Get started" ki jagah yehi link.
- **One person, one account** ladder (footer + landing + plan cards):
  3+ accounts per device ya 24h mein 3 signup = suspicious → ek final warning →
  block + device ban list → blocked account ko 72h export → phir permanent delete.

Plan cards mein add hone wali lines (Business · Business Pro · AI Pro ·
AI Business · AI Executive): delete for me / delete for everyone (48h ke baad
bhi), edit sent message, reply-quote/forward/star/pin, voice notes + media,
Relay video (Business Pro + AI Executive par 8K-capable + simulcast + telemetry),
sealed device identity, 72h export window.


## Phase 23 — Promise recovery engine

DB truth: `chat_work_items` (promise columns) · `promise_recovery_log`
(append-only) · `promise_board()` · `promise_recover()` · `promise_keep()` ·
`promise_history()` · `device_ban_appeals` (`sql/phase23_promise_engine.sql`).

| Feature | Basic | Pro | Business | Business Pro | AI Pro | AI Business | AI Executive |
|---|---|---|---|---|---|---|---|
| Promise board (open · due soon · overdue · slipped · kept) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Real reminder into the conversation (`chat_send`) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Deadline change with 8+ char reason (original sealed) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Append-only recovery ledger + full history | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| "Kept" only with evidence | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Owner handover (reassign) with logged reason | — | — | — | ✓ | — | ✓ | ✓ |
| Downstream impact on a slipping promise | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Device block appeal (file one) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Appeal review + unblock decision (logged reason) | — | — | — | ✓ | — | — | ✓ |

LOCK: engine khud kabhi deadline nahi badalti aur khud reminder nahi bhejti —
har action insaan ka, reason ke saath. `original_due_at` kabhi overwrite nahi
hota. Ban SIRF device hash par — IP/network/WiFi kabhi ban nahi (cafe aur
office ke masoom log safe), aur har ban appealable hai.


## Phase 25/26/27 — Timeline · health · collision · provenance

DB truth: `chat_message_important` · `chat_message_provenance` (append-only seal
chain) · `commitment_collisions` · `commitment_collision_events` (append-only) ·
`conversation_timeline()` · `conversation_health()` / `conversation_health_board()` ·
`message_provenance()` · `conversation_chain_verify()` · `commitment_collision_scan()` /
`commitment_collision_act()` (`anexochat/sql/phase25_27_timeline_health_provenance.sql`).

| Feature | Basic | Pro | Business | Business Pro | AI Pro | AI Business | AI Executive |
|---|---|---|---|---|---|---|---|
| Conversation → outcome timeline (2 lanes) | — | — | ✓ 200 | ✓ 1,000 | ✓ 200 | ✓ 1,000 | ✓ 2,000 |
| Mark a message Important (mark + unmark logged) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Lenses: messages · files · tasks · promises · decisions | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Matter health: on track · waiting · blocked · completed | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Health with owner + next date + `reasons[]` evidence | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Message provenance (sender · workspace · ms UTC · receipts) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Integrity Verified against the sealed copy | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Whole-conversation tamper-evident chain audit | — | — | — | ✓ | — | ✓ | ✓ |
| Commitment collision prevention (recorded links only) | — | — | — | ✓ | — | ✓ | ✓ |
| Collision actions with 8+ char reason (append-only ledger) | — | — | — | ✓ | — | ✓ | ✓ |

LOCK: timeline kuch invent nahi karti — har event ka asli record hai (message ·
file evidence · work item · decision version) aur "kya kaha gaya" (communication)
"kya hua" (outcome) se hamesha alag lane mein rehta hai. Health sirf sabit cheez
se: khula kaam · overdue deadline · blocked dependency · jawab ka intezar, har
status ke saath evidence. Collision engine dependency KABHI invent nahi karti —
sirf `chat_work_items.depends_on` jo insaan ne likha; deadline/owner tabdeeli
Phase 23 ke `promise_recover` se hoti hai, is liye `original_due_at` kabhi
overwrite nahi hota. Provenance seal per-conversation hash chain hai (append-only,
update/delete trigger se band); edit hone par UI sach bolta hai.


## ANEXOVideoCall — Phase 31/32/33/34 (video focus)

DB truth (aane wali SQL): `call_sessions` · `call_participants` (append-only
join/leave truth) · `call_files` (Phase 16-18 evidence chain reuse) ·
`call_work_links` · `call_quality_samples` · `call_recordings` +
`call_recording_consent` (append-only) · `call_cost_rates` · `call_outcomes`.
Arms Rust-first: `/rpc/call.*` (:3200) + WebTransport/QUIC; Bun `/api/chat/call/*`
sirf fallback. Media: WebRTC + apna coturn (`anexovideocall.anexomail.com`) —
koi Zoom/Daily/Agora/Twilio nahi.

| Feature | Basic | Pro | Business | Business Pro | AI Pro | AI Business | AI Executive |
|---|---|---|---|---|---|---|---|
| 1:1 video call | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Group call participants | — | — | ✓ 8 | ✓ 40 | ✓ 8 | ✓ 40 | ✓ 60 |
| Call business record (join/leave truth) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| In-call file share (scanned · verified chain) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Call → task / promise / decision | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Screen share | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Live call health card (RTT · loss · bitrate) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Post-call quality report (p50/p95/p99) | — | — | — | ✓ | — | ✓ | ✓ |
| Calls in business search (as an object type) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Recording (consent gated, self-hosted) | — | — | — | ✓ | — | ✓ | ✓ |
| Recording retention + legal hold | — | — | — | ✓ | — | ✓ | ✓ |
| Call export bundle (verifiable) | — | — | ✓ | ✓ | ✓ | ✓ | ✓ |
| Transcript (consent + AI package only) | — | — | — | — | ✓ | ✓ | ✓ |
| Meeting cost (explainable formula) | — | — | — | ✓ | — | ✓ | ✓ |
| Meeting outcome ledger | — | — | — | ✓ | — | ✓ | ✓ |
| Workspace meeting roll-up (aggregate only) | — | — | — | ✓ | — | ✓ | ✓ |

LOCK: Basic/Pro ko ANEXOChat/VideoCall ka ZERO access (pehle se locked).
Recording bina consent kabhi nahi; ek participant ke mana karne par record nahi
hoti. Transcript sirf AI packages + consent — warna UI "no transcript recorded"
likhta hai, summary invent nahi karta. Cost analytics default OFF, rate insaan
daalta hai, "unproductive" lafz kabhi nahi. Admin ko private call body/transcript
khud-ba-khud nahi milti (Phase 44 privacy model + 12+ char justification + log).

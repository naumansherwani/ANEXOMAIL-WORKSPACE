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

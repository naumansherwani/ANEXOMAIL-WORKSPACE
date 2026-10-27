# COMPOSE BUSINESS OUTCOMES + FILE CONTEXT + LIVE INK — feature record (27 Oct 2026 08:24 PKT)
Founder idea 27 Oct 2026 07:29 PKT ("Zoho/Gmail sirf alfaaz predict karte hain; Anexomail kaam aur paisa"). Yeh file = sach: kya bana, kahan hai, server par kya hai, kya baaki. Dobara codes mat likho — neeche files dekho.

## Server par KAB aaya (founder ne chalaya)
- 27 Oct 2026 ~08:2x PKT: web pull.sh (UI + kernel 0.4.0 wasm) = **server par**. SQL sql-run.sh: E97, E98, E99 (+ CHECKs) = **founder ke mutabiq sab green** (E97 do baar fail hui — 1) live work_promises mein thread_subject nahi, 2) selftest ka dummy org live FK par — dono fix, commits c57cc77 / 4cc2f3b).
- Rust installer (promx module: commit.* + file.context): founder ne "sab chala diya" kaha; installer ka output CEO ne abhi nahi dekha => Rust ka live saboot (nakli token = 401 'unauthorized', asli Pro token = jawab) **abhi baaki**. Jab tak yeh na ho, UI badge send par commit.record 404 de sakta hai (send phir bhi nahi rukta).

## 1. Promise Extraction (Pro) — kernel intent@1 + SQL E97 + Rust promx + OutcomesBar
- Browser (WASM kernel 0.4.0, deterministic, English + Roman Urdu) wada + deadline pakadta hai: "I will send by Friday", "Monday tak bhej doon ga". Badge: "Detecting a Promise. Link to Calendar & Tasks?" => Task + Calendar / Task only. Send ke BAAD server: commit.record => ek atomic SQL call = work_promises(status committed, commit_state open) + work_tasks(source promise, owner = email) + optional calendar_events hold (kind meeting) + commitment_ledger row.
- HMAC-SHA256: (a) har request par kernel ka ANEXO tag (ANEXO_TAG_MODE observe; enforce tag-enforce.sh se baad mein), (b) har ledger row par per-org HMAC-SHA256 seal + hash-chain; ledger append-only (update/delete/truncate trigger se mana); commit.verify poori chain dobara hisaab.
- Files: web-wasm/src/intent.rs; docs/cursor-work/sql/E97_commitment_ledger_economics.sql (+CHECK_E97); server/rust/promx_core.rs + promx_glue.rs; src/lib/outcomes.ts; src/components/app/compose/OutcomesBar.tsx; ComposeStudio.tsx wiring (sirf Pro).
- Procs: commit.record / status / list / verify / economics / rate / rateSet (Pro, Basic 403).

## 2. Thread Economics (Pro) — same stack
- To/Cc/Bcc + words => "This email will cost about £X of attention to read — N min across M people"; 2-minute call ka mashwara SIRF jab call asli mein sasti ho (jhoota bachat nahi). Formula integer: each = ceil(words*60/wpm)+8s, total = each*recipients, cost = round(total*rate/3600); kernel aur SQL attention_cost() BIT-BA-BIT same (test dono taraf). Default rate £60/ghanta, wpm 220 (org_attention_rates; commit.rateSet). Send par thread_economics_log (call_accepted ka asli saboot).

## 3. File Context (Pro) — kernel filectx@1 + SQL E99 + Rust file.context + FileContextCard
- "the latest CRM sheet" / Q3_budget.xlsx likhte hi card: kaun ne bheji, kab, kis thread mein, kitne versions, har version "same content" ya "+500 B", "Add reference line", "Open the conversation". Sirf APNI org ki mail attachments (dusri org ki file bahar — test se saabit).
- HADD (jhoota claim nahi): file andar se nahi kholi jati => diff = metadata (content wahi/naya via sha256, size); cell-level/database diff NAHI.
- Files: web-wasm/src/filectx.rs; docs/cursor-work/sql/E99_file_context.sql (+CHECK_E99); promx file.context; src/components/app/compose/FileContextCard.tsx; useFileContext in outcomes.ts.

## 4. Live Ink (typewriter / gradient typing) — SAB plans (compose body)
- GhostTextArea.tsx + src/styles.css (.ax-ink/.ax-caret): naye akshar logo-blue gradient mein behte hain (~1.1s mein settle), caret logo-gradient mein blink. Reduced-motion / Calm / data-ax-motion=reduced par band. Asli Chromium screenshot se dekha.
- Word prediction (ghost text) SAB plans par rahegi (founder faisla); uska "advanced upgrade" abhi NAHI hua.

## Kernel
- 0.4.0 (modules sha256,hmac,sniff,rank,live,rpc,intent,filectx), wasm sha256 7499188264a10c8da1a3f82a9ddad20cc2da791b8362b862f11b94925901f88c. E98 (E98_kernel_release_040.sql) isko E90 registry mein 'current' karti hai. 3 round: cargo 46/46, bun/real-wasm 41 pass, asli Chromium (QUIC server wala round live Chrome mein baaki).
- Rule 60 (CINEMATIC-FRONTEND-STACK): Mail/Compose = kaam wali screen => 3D/cinematic NAHI; yahan kernel + debounce + halka motion.

## Baaki / honest
- Rust promx ka live saboot; phir live Chrome (pro.buyer2): badge, cost, file card, Live Ink, send ke baad Tasks/Calendar mein entry, commit.verify.
- Cross-package connect (Basic/Business se mail/contact), booking link 4th refuse, 20-user cap UI, Cancel send test mail (30 Nov) — Pro GREEN se pehle.
- Word prediction upgrade; ANEXO_TAG_MODE=enforce (tag-enforce.sh, aakhri step); Billing C2 founder option; team Sent design founder decision.
- Test jo CEO ne dekha: workx contract drift (6 proc) fix; 221 tests pass (src/lib).

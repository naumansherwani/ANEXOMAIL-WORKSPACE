# SQL ORDER E1 -> E160 (founder 11 Nov 2026 18:56 PKT: "sab sql ki tarteeb lagao")

ONE LINE OF ORDER: every file runs strictly by NUMBER (E1, E2 ... E160), never by date, only through `server/sql-run.sh` on his server (never the Supabase dashboard). A file whose sha is already in the ledger never runs again (never re-send green SQL). A `CHECK_E<n>.sql` only reads and runs every time.

HOW TO READ: number = the order; file = the SQL; CHECK = has a read-only proof file; line = what it does (from docs/cursor-work/sql/index.md or the file header). Numbers that do not exist were never used and are listed at the bottom.

| No | File | CHECK | What it does |
|---|---|---|---|
| E2 | E2_personal_polar.sql | - | E2 — personal Polar map (Personal users only) |
| E5 | E5_billing_subscription_api.sql | - | E5 — Billing subscription + invoices API |
| E6 | E6_companywide_delete.sql | - | E6 — Business Pro: company-wide delete for everyone (NO time limit) |
| E7 | E7_business_delete_48h.sql | - | E7 — Business: delete for everyone within 48 HOURS (card promise) |
| E13 | E13_personal_polar_products.sql | - | E13 — separate Personal Polar products + payment guard |
| E14 | E14_mail_thread_assign.sql | - | Step 5 — mail_thread_assign |
| E14 | E14_security_advisor_clean.sql | - | E14 — SECURITY ADVISOR CLEAN (errors + warnings) |
| E15 | E15_business_domains.sql | - | E15 — Business domains + company addresses (Zoho-style "bring your own domain") |
| E17 | E17_trial_provision_workspace.sql | - | E17: naya real buyer signup -- workspace provisioning (Rule 14, #5/#6). |
| E18 | E18_signup_device_gate_nonblocking.sql | - | E18 — signup_device_gate: auto-block hata do (Phase 24A ladder ki violation thi) |
| E19 | E19_password_reset_hardening.sql | - | E19 — password reset: atomic token consume + rate limit + cleanup |
| E20 | E20_personal_plan_pending.sql | - | E20 — real signup != trial. "Personal Basic" jhoota label hata do. |
| E22 | E22_plan_replacement.sql | - | E22 — package badalna = naye plan ka POORA price, purana plan band. |
| E23 | E23_payment_activates_account.sql | - | E23 — payment ke baad account KHUD active ho (#20 ka wiring). |
| E24 | E24_account_deletion.sql | - | E24 — account delete system (founder request, 14 Oct 2026). |
| E27 | E27_business_pro_mailboxes_unlimited.sql | - | E27 — Business Pro mailboxes = unlimited (blueprint #15, 14 Oct 2026) |
| E28 | E28_seed_buyer_test_account.sql | - | E28 — asli BUYER test account (sirf payment skip) — blueprint #20, 14 Oct 2026 |
| E30 | E30_dashboard_truth.sql | - | E30 — Dashboard ka sach (15 Oct 2026) |
| E31 | E31_calendar_v2.sql | - | E31 — Calendar v2 (18 Oct 2026, shuru se dobara likhi): asli invitations, RSVP, invitation ledger, ek-query busy lookup. |
| E32 | E32_tenant_lock.sql | - | E32 — Tenant lock (18 Oct 2026): ek customer doosre customer ka data public database API se na padh sake, na likh sake. |
| E33 | E33_team_invites.sql | - | E33 — Team invitations + Teams (18 Oct 2026, shuru se dobara likhi): asli invitations, role maana jaye, accept se banda org mein judey. |
| E34 | E34_team_seats_chain_mailbox.sql | - | E34 — Team ke teen baqi hisse (19 Oct 2026, founder "haan"): seat limit, tamper-evident audit chain, join par mailbox. |
| E35 | E35_migration_walled_garden.sql | - | E35 — Purani mailbox ko ANEXOMAIL mein laana (G30, 19 Oct 2026, founder "haan"): "MIGRATION-ONLY WALLED GARDEN". |
| E36 | E36_ensure_test_account.sql | - | E36 — test account ko poora theek karo ("ensure"), har layer par, dobara chalane par bhi safe — 19 Oct 2026 |
| E37 | E37_mail_ingest_no_stray_org.sql | - | E37 — aane wali mail KABHI kisi aur customer ke inbox mein nahi — 20 Oct 2026 (founder "haan", 05:37/06:07 PKT) |
| E38 | E38_thread_message_count_truth.sql | - | E38 — thread ki "kitni mails" ginti hamesha sach — 20 Oct 2026 (Basic live login: ek mail wale thread par "2" likha tha) |
| E39 | E39_security_truth.sql | - | E39 — Security page sach bole — 20 Oct 2026 (Basic live audit) |
| E40 | E40_billing_price_truth.sql | - | E40 — Billing page sahi daam — 20 Oct 2026 (Basic live audit: business account ke Basic plan par "£97.00 / month · 25 GB / mailbox") |
| E41 | E41_family_real_buyer.sql | - | E41 — family account (Humza, Raana, Masood) ko ASAL BUYER wale raaste par laana — G39 — 20 Oct 2026 |
| E42 | E42_device_hash_hmac.sql | - | E42 — device hash: SHA-256+pepper -> HMAC-SHA256 (key-separated) — Blueprint G34 — 20 Oct 2026 |
| E43 | E43_passkey_recovery_codes.sql | - | E43 — passkey lazmi (password + passkey dono) ka database hissa: recovery codes + passkey status — Blueprint G35 — 20 Oct 2026 |
| E44 | E44_account_export.sql | - | E44 — ASLI data export ("export anytime" / blocked account ke 72 ghante) — Blueprint G36 — 20 Oct 2026 |
| E45 | E45_integrity_purge.sql | - | E45 — blocked account: 72 ghante export ke baad ASLI delete — Blueprint G36 — 20 Oct 2026 |
| E46 | E46_integrity_notices_appeal.sql | - | E46 — warn/block par EMAIL + 24 ghante pehle yaad-dihani + purge ka notice + in-app APPEAL — Blueprint G36/G37 — 20 Oct 2026 |
| E47 | E47_device_revoke_real_sessions.sql | - | E47 — device REVOKE se asli login session khatam + device record ki deletion ka asli job — Blueprint G37 / PROMISES #5, #6 — 20 Oct 2026 |
| E48 | E48_outgoing_attachments.sql | yes | E48 — G38: bheji jane wali mail mein ASLI attachments (upload -> org-ke-andar SHA-256 dedup -> quota -> send -> Sent mein download) — 20 Oct 2026 |
| E49 | E49_attach_ceiling_18mb.sql | - | E49 — ek mail mein attachments ki hadd 7 MB se 18 MB (raw) tak — G38 — 20 Oct 2026 (founder "haan" 21:38 PKT) |
| E50 | E50_inbound_attachments.sql | yes | E50 — G38b: AANE WALI mail ke attachments ke bytes bhi Storage Box par (E48 ke org-dedup blobs mein) — 20 Oct 2026 |
| E51 | E51_calendar_response_fix.sql | - | E51: calendar.create 500 ka asli sabab (live saboot 21 Oct 00:29): |
| E52 | E52_alias_fair_use.sql | yes | E52 — alias FAIR-USE cap (chhupa hua, card par nahi likha): har plan par 25 active alias. |
| E52 | E52_calendar_response_values.sql | yes | E52: calendar_attendees.response — live table par purana CHECK (calendar_attendees_response_check) tha jo |
| E53 | E53_auth_session_alive.sql | yes | E53 — Rust local-JWT verify ke liye: "yeh login session abhi zinda hai?" (B1, 21 Oct 2026) |
| E54 | E54_mail_queue_claim.sql | yes | E54 — mail bhejne ki queue: ek row ek hi worker uthaye (B3, 21 Oct 2026) |
| E56 | E56_calendar_recurrence.sql | yes | E56 — Calendar recurrence (B7b, 22 Oct 2026): repeating meetings for EVERY package (koi plan-gating nahi). |
| E57 | E57_ui_pref.sql | yes | E57 — calendar ki display pasand ACCOUNT mein save: clock 12h/24h/auto + layout classic/expanded (22 Oct 2026) |
| E58 | E58_calendar_prefs_reminders.sql | yes | E58 — calendar: alag calendars + rang, working hours, out-of-office (account pasand `awam_ui_pref.extra`) aur |
| E59 | E59_booking_page.sql | yes | E59 — BOOKING PAGE (B7c): har user ka public `/book/<handle>` link (22 Oct 2026). E31 + E56 + E57 + E58 ke baad chalti hai. |
| E60 | E60_imip_reply.sql | yes | E60 — iMIP REPLY (G26): guest apne calendar app (Gmail / Outlook / Apple) mein Yes/Maybe/No dabaye to jawab hamare calendar |
| E61 | E61_world_clocks.sql | yes | E61 — world clocks: awam_ui_pref.extra mein 4th key `clocks` (<= 6 IANA zone naam, duplicate nahi). 22 Oct 2026. E58 ke baad. Dobara chalana safe. Koi |
| E62 | E62_team_overlap.sql | yes | E62 — Overlap Matrix (calendar #4b / W1): team ke working-hours + out-of-office + guest ka timezone, EK function mein (22 Oct 2026). |
| E63 | E63_event_goal.sql | yes | E63 — calendar #9 "outcome colours": har meeting par user ka APNA maqsad (goal, 2000 harf tak, multi-line) aur uski asli halat (open / achieved / miss |
| E64 | E64_history_search.sql | yes | E64 — calendar #10 HISTORY SEARCH: saalon purani meetings (+ unke notes, guests, Aim) ek search mein, tareekh range aur "kis ke saath" ke saath (22 Oc |
| E65 | E65_rls_and_advisor_sweep.sql | yes | E65 — RLS ON + Security Advisor warnings SAAF, ek hi script (22 Oct 2026). Rule 43: ab se har SQL RLS-on hogi; yeh script purani/chhooti hui sab ko ba |
| E66 | E66_identity_vault.sql | yes | identity vault (ek insaan ek account) CHECK_E66 22 Oct 21:25 READY |
| E67 | E67_passkey_vault.sql | yes | passkey vault + authenticated select band CHECK_E67 22 Oct 21:25 READY |
| E68 | E68_identity_vault_admin.sql | yes | identity vault: Block/Release/Appeal hook, raw HMAC wrappers, signup appeals, founder overview CHECK_E68 22 Oct 21:45 READY |
| E69 | E69_identity_mirror_health.sql | yes | identity vault: ban feed (local mirror) + NOTIFY, health report, payment sweep source, deny-after-signup flag CHECK_E69 22 Oct 22:20 READY |
| E70 | E70_identity_hardening.sql | yes | identity hardening: fingerprint groups (fp_hw/gfx/env), signup HOLD (pending + banned_until), gate (open/hold_matches/approval_all), disposable domains, probation limits  |
| E71 | E71_identity_probation_notice.sql | yes | identity: probation ki asli rok (identity_probation_take), session backstop (auth.sessions/refresh_tokens trigger), manzoori ka notice outbox CHECK_E71 23 Oct 00:30 READY |
| E72 | E72_appeal_evidence.sql | yes | appeal: statement 20,000 characters (device + sign-up + apna appeal) + evidence files (appeal_evidence*, atomic open_v2, reviewer-only judi files, access log, 90-din safa |
| E73 | E73_calendar_subscriptions.sql | yes | calendar subscriptions (#4c ICS, read-only): calendar_subscriptions + _events RLS ON, URL secret (list sirf host), 10/user, lease-wali due, atomic apply, 30 fail par auto |
| E74 | E74_calendar_event_files.sql | yes | calendar #5 meeting par files: calendar_event_files (RLS ON, FK cascade, unique event+sha256, max 10), _cal_file_gate (organiser jodta/hatata, attendee dekhta), cal_file_ |
| E75 | E75_home_city.sql | yes | home city save fix: awam_ui_extra_ok mein 5th key `home` (Rust clean_home ka mirror; purane 4 keys same). Bina iske Settings > Home city 500 deta tha CHECK_E75 23 Oct REA |
| E76 | E76_test_account_registry.sql | yes | ACCOUNT CLASS WALL (Rule 49): asli/founder/family/test kabhi mix nahi. test_accounts registry + account_class(email) + register_test_account; ek email=ek class (triggers  |
| E77 | E77_rsvp_conflicts.sql | yes | RSVP collision warning: calendar_rsvp_conflicts(token) -> {count, overlaps (max 3, sirf waqt, TITLE kabhi nahi)}; back-to-back/declined/cancelled/doosra org conflict nahi |
| E78 | E78_travel_status.sql | yes | W4 Travelling status: awam_ui_extra_ok mein 6th key `travel` ({to_city,to_zone,depart_at,arrive_at}; user ka likha, koi position/flight nahi; <=72h, arrive>depart, asli t |
| E79 | E79_market_chip.sql | yes | W5 market chip: awam_ui_extra_ok mein 7th key `market` (sirf boolean; default OFF = key nahi; Rust clean_market ka mirror) CHECK_E79 23 Oct READY |
| E80 | E80_caldav_foundation.sql | yes | CalDAV neev: caldav_app_passwords (sirf hash, 10/user, 8 fail=15 min lock, revoked member band) + calendar_events.dav_rev/dav_updated_at (etag) + caldav_org_state.ctag +  |
| E81 | E81_caldav_feed_link.sql | yes | E81 — CalDAV (#6) B: "Calendar link" (bina app ke Google Calendar mein URL se jodna). 23 Oct 2026. E80 ke baad. Dobara chalana safe. Koi DROP nahi. |
| E82 | E82_calendar_rooms.sql | yes | E82 — Calendar #8: ROOMS / RESOURCES (pseudo-attendee, wohi conflict engine). 23 Oct 2026. E31 ke baad. Dobara chalana safe. Koi DROP nahi. |
| E83 | E83_room_guard.sql | yes | E83 — Rooms: DB-level guard (loophole band). 24 Oct 2026. E82 ke baad. Dobara chalana safe. |
| E84 | E84_room_series_note.sql | yes | E84 — Tarteeb ka number (founder hukm 24 Oct 2026: SQL ki tarteeb nahi tootni). E83 ke baad, E85 se pehle. Dobara chalana safe. |
| E85 | E85_assign_one_function.sql | yes | E85 — Pro "Shared inbox": mail_thread_assign ke do overloads (text aur uuid) PostgREST ko confuse karte the (PGRST203) — assign Bun aur Rust dono par |
| E86 | E86_drafts_followups.sql | yes | E86 — Compose: (1) mail_followups table tha hi nahi (Follow-up GET/POST live 500), (2) draft versions mein (draft_id, version) unique nahi tha — do sa |
| E87 | E87_basic_v6.sql | yes | E87 — Business Basic v6 (26 Oct 2026, founder hukm): £40 / month, £440 / year, up to 5 users, 15 GB SHARED storage. |
| E88 | E88_pro_v6.sql | yes | E88 — Business Pro-package (naam: PRO) v6 (26 Oct 2026, founder hukm): £105 / month, £1,155 / year, up to 20 users, |
| E89 | E89_analytics_backend.sql | yes | E89 — Analytics Center ka ASLI backend (26 Oct 2026, founder hukm: "ek bhi wire adhoora nahi"). Phase24 ke 6 tables pehle se hain (sql/phase24_analyti |
| E90 | E90_kernel_constitution.sql | yes | E90 — ANEXOMAIL KERNEL CONSTITUTION (founder Nauman Sherwani, 26 Oct 2026, Rule 52) |
| E91 | E91_kernel_session_key.sql | yes | E91 — KERNEL SESSION KEY (E90 Article: request tag). Rust :3200 (Tokio) ticket se session key nikalta hai, ek baar cache karta hai, |
| E92 | E92_crm_p1_p2.sql | yes | E92 — CRM P1 + P2 (founder "haan" 26 Oct 2026): multiple pipelines, custom fields, duplicate merge, web forms -> lead. |
| E93 | E93_attach_ceiling_35mb.sql | yes | E93 — attachment ki server ceiling 18 MiB (E49) -> 35 MiB (36_700_160 bytes) taa ke Pro ka vaada (35 MB) asli ho. |
| E94 | E94_plan_promises.sql | yes | E94 — PLAN PROMISES: plan card par jo vaada user se kiya, uska EK registry + khud-jaanch (audit). Kuch aur nahi badalta. |
| E95 | E95_people_rebuild_to_addrs.sql | yes | E95 — PEOPLE bharta nahi tha: bheji hui mail ke recipients `to_addrs`/`cc_addrs` mein likhe jate hain |
| E96 | E96_people_rebuild_live_columns.sql | yes | E96 — PEOPLE ka asli bug (live saboot: people-check.sh 06:43): anexo_rebuild_contacts har baar FAIL: |
| E97 | E97_commitment_ledger_economics.sql | yes | E97 — COMMITMENT LEDGER + THREAD ECONOMICS (compose "Business Outcomes", 27 Oct 2026) |
| E98 | E98_kernel_release_040.sql | yes | E98 — kernel 0.4.0 darj karna: naye modules intent@1 (wada + deadline, email ka waqt/paisa) aur filectx@1 (email mein file ka zikr pakadna). |
| E99 | E99_file_context.sql | yes | E99 — FILE CONTEXT (compose): email mein "the latest CRM sheet" likhte hi us file ka asli sach — kaun ne bheji, kis thread mein, |
| E100 | E100_plan_interop_matrix.sql | yes | E100 — PLAN x PLAN INTEROP ENGINE (super advanced): poori website ke log ek dusre se contact kar sakte hain. |
| E101 | E101_activity_feed_writers.sql | yes | E101 — ACTIVITY ENGINE (super advanced): dashboard "Recent activity" khali kyun tha? activity_log table ko KOI likhta hi nahi tha. |
| E102 | E102_founder_audit_actions_devices.sql | yes | E102 — FOUNDER ENGINE (super advanced): append-only audit chain + one-click action catalogue + approved devices. |
| E103 | E103_founder_actions_english.sql | yes | E103 — FOUNDER ACTION CATALOGUE (super advanced): English text + SAFETY RATCHET + tamper-proof guard trigger + selftest. |
| E104 | E104_founder_device_approval.sql | yes | founder device approval 10/10: exchange (TOFU, pending cap 5, 7-day expiry), approve/revoke by code or hash prefix, immutability trigger, per-user lock, audit chain, self |
| E105 | E105_founder_polar_pulse.sql | yes | founder Polar pulse: read-only RPC founder_polar_pulse() over the webhook-fed tables (events, subscriptions, reconcile, signature rejects, alerts), no PII, STABLE, servic |
| E106 | E106_founder_polar_rejects.sql | yes | founder Polar rejects: founder_polar_rejects() — signature-reject counts by reason/day/sender class, no raw body, no header values; Polar tables untouched CHECK_E106 (5 c |
| E107 | E107_founder_audit_merkle.sql | yes | E107 — FOUNDER AUDIT MERKLE (master order step 5, F2c): audit chain ke upar Merkle tree, signed-ready checkpoints, inclusion proof, export. |
| E108 | E108_founder_settings.sql | yes | founder_settings (+history, RPC founder_setting_set/get) — Settings S1 + profile photo, separate from awam account_profiles CHECK_E108 (6) founder; sandbox-proven 28 Oct  |
| E109 | E109_founder_live.sql | yes | E109 — FOUNDER LIVE (L-phase): har number asli, har badlav page par khud aaye. Zero mock data (Rule 69). 10/10 (FC27). |
| E110 | E110_founder_host_proof.sql | yes | E110 — FOUNDER HOST PROOF (L5 v2): "founder sirf founder host par" ka SABOOT database mein, pm2 log files mein nahi. 10/10 (FC27). |
| E111 | E111_founder_channels_telemetry.sql | yes | E111 — FOUNDER CHANNELS + LIVE TELEMETRY (step 4b-4): "Not connected yet: Glitch, Support, Company Mail" ab database ki asli list hai, Rust mein hard- |
| E112 | E112_founder_inbox.sql | yes | E112 — FOUNDER INBOX (step 4d, P1): user ki Glitch / Support reports ka asli intake, severity, SLA, duplicate-grouping, hash-chained history. |
| E113 | E113_founder_settings_timemachine.sql | yes | E113 — FOUNDER SETTINGS S2 (master order step 6): TIME MACHINE + DRIFT + SCHEDULED CHANGES WITH AUTO-ROLLBACK + EXPLAIN / BLAST RADIUS. |
| E114 | E114_founder_appearance_ambient.sql | yes | E114 — FOUNDER SETTINGS S1b (master order, right after step 6): ONE KEY REGISTRY + the full Appearance tab + AMBIENT STUDIO (car-style ambient looks). |
| E115 | E115_founder_settings_s1c.sql | yes | E115 — Founder Settings S1c: the rest of the awam Settings Center rows, as real registry keys (Personal, Workspace, Notifications, Privacy). |
| E116 | E116_founder_drift_value_rule.sql | yes | E116 — Founder Settings S1d: Drift & schedule measure the new S1c rows. A third baseline rule, "value": the recommended safe value of a setting (true |
| E117 | E117_founder_passkey_stepup_recovery.sql | yes | E117 — Founder step 7 / phase 7-1: passkeys, G3 step-up grants and recovery (SQL only; Rust webauthn-rs is 7-2, the Privacy tab is 7-3). |
| E118 | E118_founder_chairman_protocol.sql | yes | E118 — Founder step 7 / phase 7-1b: the chairman protocol (SQL). Decisions of the founder, 1 Nov 2026 13:07 (design note, "7-0 DECIDED"). |
| E119 | E119_founder_tls_posture.sql | yes | E119 — Founder T256-1 (SQL half): the PROOF LEDGER of what TLS every host really negotiates (1 Nov 2026, founder 14:33 "super advance level sql ke saa |
| E120 | E120_founder_ledger_gauge_hardening.sql | yes | founder_audit_verify_runs + policy knobs + pulse with checker / full_check / sealer_stalled / cp_hash / now_ms (G4 gauge hardening) CHECK_E120 (4) founder; sandbox-proven |
| E121 | E121_founder_audit_consistency.sql | yes | E121 — Founder G5a (SQL half): RFC 9162 section 2.1.4 CONSISTENCY proofs over the E107 audit tree (founder 2 Nov 2026 03:37, "God level"). |
| E122 | E122_founder_seal_interval.sql | yes | founder_seal_interval seal every 20 entries or 10 min, no seal loop, stall on same due (G5a live proof) CHECK_E122 (2) |
| E123 | E123_founder_signed_checkpoints.sql | yes | founder_audit_log_keys + founder_audit_signed_checkpoints + 5 doors: C2SP signed checkpoint per seal (G5b); body derived from the seal, Ed25519 checked by Rust + kernel C |
| E124 | E124_founder_time_anchors.sql | yes | founder_anchor_* (providers, policy, jobs, hash-chained evidence + events) + 12 doors: account-free outside time anchors for signed checkpoints, RFC 3161 TSA + OpenTimest |
| E125 | E125_retire_personal_packages.sql | yes | Personal packages retired: personal_polar_map emptied, 6 Personal price-book rows off/deleted, masoodsherwani kept on Pro, NO account deleted (CHECK_E125; CHECK_PX0B_TEST |
| E126 | E126_delete_two_test_accounts_masood_business.sql | yes | Two test accounts (basic.test@, alikhan@) deleted incl. owned orgs + blockers; masoodsherwani@ converted to business kind on plan pro, never deleted (founder 2 Nov 08:54) |
| E127 | E127_signup_country_phones.sql | yes | PX2a: account_profiles.country_iso2 + account_phones (many numbers per account, same number allowed on several accounts, max 5, unverified until SMS exists) CHECK_E127 (5 |
| E128 | E128_phone_blind_index.sql | yes | PX2b: account_phones.e164_hmac keyed blind index (HMAC-SHA256, HASHING.md), non-unique CHECK_E128 (3) |
| E129 | E129_org_optional_hardening.sql | yes | Create your workspace: organisation OPTIONAL + org layer hardening (guard trigger, limits, hash-chained org_events, domain proof, last-owner, soft delete, integrity repor |
| E130 | E130_org_report_text_cast.sql | - | Fix for E129: org_integrity_report() casts every detail column to text (auth.users.email is varchar) CHECK_E129 (12) |
| E131 | E131_founder_portable_verify.sql | yes | G5d pin portability: the oldest signed checkpoint with outside time evidence (>= 2 TSAs or Bitcoin) as a pin-less horizon; one-read bundle with ONE consistency proof; has |
| E132 | E132_anchor_selftest_repair.sql | - | G5c repair: the E124 selftest judges the signer warning itself, so it passes on a server that has real dead anchoring jobs (CHECK_E124 was red on the live state) CHECK_E1 |
| E133 | E133_anchor_pending_any_length.sql | yes | G5c repair R1: the evidence guard accepts an OpenTimestamps pending commitment of 1 to 4096 whole bytes (Bitcoin stage stays 32); selftest CHECK_E133 (3) |
| E134 | E134_anchor_requeue_door.sql | yes | G5c repair R1 part 2: audited door `founder_anchor_requeue` (founder only, cause must be named, enabled providers only, one event per job + one audit row, 2nd run no-op); |
| E135 | E135_requeue_ots_dead_by_32byte_bug.sql | yes | G5c repair R1 part 3: re-queue the OTS jobs that died of the 32-byte bug (idempotent; freetsa NOT included, it waits for the R2 binary) CHECK_E135 (3) |
| E136 | E136_requeue_ots_dead_actor_fix.sql | yes | G5c repair R1 part 4: E135 skipped itself (server has 2+ founder accounts); actor = founder with the newest audited action, else the only founder CHECK_E136 (4) |
| E137 | E137_requeue_freetsa_after_r2.sql | yes | G5c repair R2 data step: re-queue the freetsa jobs that died of "unsupported ECDSA curve/hash pair" (after the R2 binary) CHECK_E137 (4) |
| E138 | E138_founder_portable_tick.sql | yes | G5d part 2: the portable-pin observer: policy, fencing lease, hash-chained tick log + serve log, canonical bundle text + sha256, selftest CHECK_E138 (6) |
| E139 | E139_founder_webauthn_l3.sql | yes | J3: WebAuthn Level 3 brain: policy singleton, credential facts (BE/AAGUID immutable), hash-chained event ledger, FIDO MDS3 ledger, Signal API queue, clone rule, risk-scor |
| E140 | E140_founder_flare_push.sql | yes | J6: FLARE v2 = phone Web Push (RFC 8291/8292): push subscription (endpoint allow-list, key shapes, T2 flare.push, confirm token hash), outbox state machine, hash-chained  |
| E141 | E141_founder_flare_receipts.sql | yes | J6 hardening: end-to-end DELIVERY RECEIPTS (one-time ack token inside the encrypted push, hash only in SQL), one escalation reminder after 90 s, status of unacknowledged  |
| E142 | E142_founder_hardware_truth.sql | yes | J hardening: a key is HARDWARE only if its model is trusted AND its facts say device-bound (BE=0, not platform); class re-decided by triggers; `founder_hardware_readiness |
| E143 | E143_founder_vault_lease.sql | yes | J8 DEAD-MAN VAULT LEASE: short server-signed lease, race-safe, tamper-evident, self-auditing. CHECK_E143. GREEN on his server |
| E144 | E144_founder_vault_lease_keysplit.sql | yes | J8 lease key split (vault key never sits whole with the server). CHECK_E144. GREEN on his server |
| E145 | E145_founder_vault_panic_t3.sql | yes | J8 panic lock (T3): two hardware keys, ledger. CHECK_E145. GREEN on his server (panic needs his 2 hardware keys to run for real) |
| E146 | E146_founder_banned_countries.sql | yes | Banned countries ledger (Syria wall data). CHECK_E146. GREEN on his server |
| E147 | E147_founder_passkey_pending.sql | yes | Passkey pending ledger. CHECK_E147. GREEN on his server |
| E148 | E148_LIVE.sql | yes | K6 WebTransport sessions ledger. CHECK_E148. GREEN on his server |
| E148 | E148_founder_webtransport_sessions.sql | yes | K6 WebTransport sessions ledger. CHECK_E148. GREEN on his server |
| E149 | E149_founder_dbsc.sql | yes | K7a DBSC: device-bound sessions, jti replay cache, hash-chained events, revoke trigger. CHECK_E149 (8/8). GREEN on his server (09 Nov 2026) |
| E150 | E150_founder_devicekey.sql | yes | K7b device key for every browser and phone (source column dbsc / webcrypto, `founder_dbsc_register_src`, report by_source). File: `docs/cursor-work/sql/E150_founder_devic |
| E151 | E151_founder_signin_ceremony.sql | yes | G-MIX 2b sign-in ceremony brain (tickets, factors, magic links, hash-chained events, known networks, hand-off, risk, 2 selftests, 797 lines). File: `docs/cursor-work/sql/ |
| E152 | E152_founder_signin_one_factor.sql | yes | Founder sign-in = ONE FACTOR by his word + passkey signs in alone (policy word `second_step` off/required with a chained audit, method `passkey`, E151 selftests carried o |
| E153 | E153_founder_signin_password_fail.sql | yes | Founder sign-in: a wrong PASSWORD goes into the append-only ledger (door `founder_signin_password_fail(net_hash)`, 5 from one network lock THAT network, never the founder |
| E154 | E154_founder_passkey_by_credential.sql | yes | Passkey sign-in door, advanced (`founder_passkey_by_credential(text)`: active key of a founder only, same null for unknown/revoked/malformed/non-founder, definer + pinned |
| E155 | E155_founder_devices_sessions.sql | yes | D1: Devices & Sessions Sovereign Command Center, database half (`founder_session_registry` frozen identity + spoof score + protocol + kernel + integrity counters, `founde |
| E156 | E156_founder_sessions_advanced.sql | yes | D2a: Devices & Sessions, ADVANCED upgrade of E155 (E155 stays intact) : per-request door `founder_session_check` (idle + absolute expiry, identity drift UA/engine/device  |
| E157 | E157_founder_session_policy_stepup.sql | yes | D2b-5: policy change needs a fresh passkey touch : action `session.policy` (T2), `founder_session_policy_digest` (dry run + canonical hash) and `founder_session_policy_ap |
| E158 | E158_founder_session_key_attach.sql | yes | K7 WIRE FIX: a founder session recorded without a device key gets its verified key ONCE later (`founder_session_key_attach`, none -> dbsc/webcrypto, never a swap; ledger  |
| E159 | E159_founder_dbsc_chain_fix.sql | yes | DBSC ledger chain fix : E149 chose the chain head by `id` but ids are handed out BEFORE the lock, so two simultaneous events chained out of id order and `founder_dbsc_ver |
| E160 | E160_founder_key_rotation_not_drift.sql | yes | Key rotation is not theft (his Devices ring stayed Alert): a device key registered through the authenticated binding path AFTER a session began no longer counts as `devic |
| E161 | E161_founder_dbsc_heal.sql | yes | DBSC heal: device_state idle_s, key attach removes the two missing-key reasons when the key is proved later |
| E162 | E162_founder_dbsc_hybrid_pq.sql | yes (CHECK_E162) | HYBRID device key (ML-DSA-65 + ECDSA): pq_pub column (immutable), register_pq door with NO DOWNGRADE, device_state returns pq, event kind reject_downgrade |

Numbers never used (no file): E1, E3, E4, E8, E9, E10, E11, E12, E16, E21, E25, E26, E29, E55.

LATEST (11 Nov): E155 + E156 sessions, E157 policy step-up, E158 key attach, E159 DBSC chain fix, E160 key rotation is not theft (waits his sql-run). E161 DBSC heal (permanent ring fix, GREEN on his server 11 Nov 19:30). Next free number: E162.

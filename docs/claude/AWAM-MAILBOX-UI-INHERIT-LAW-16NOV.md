# AWAM INHERITS THE FOUNDER MAILBOX UI (founder word 16 Nov 2026 00:48 PKT, STANDING RULE)

His words: "yeh codes awam ke liye preserve kero; yeh business premium aur business MAX ka yehi same UI hoga; SHA aur HMAC 256 ke saath UI banana hai; baad mein yehi awam ke liye mold ker ker use hoga."

## What is preserved (SHA-256 manifest docs/claude/AWAM-INHERIT-MANIFEST.json, gate AWAM INHERIT in rules-gate.py)
| File | Role | Moulded for awam later |
|---|---|---|
| founder-web/src/mailbox_pure.ts (+ .test.ts) | search language (from:, is:unread, has:file), arrival logic, speed words, layout switch. Pure, no founder names | lifted AS IS |
| founder-web/src/mailbox_icons.tsx | the ONE icon set (24 grid, 1.5 stroke) | lifted AS IS |
| founder-web/src/mailbox.css | blue-only living look: @property ring, edge flash, three layouts, reduced-motion | tokens renamed to the awam theme, structure kept |
| founder-web/src/MailBox.tsx | glue: panes, live channel, View Transitions, send comet | awam copy later: awam doors instead of founder doors, customer wording, no founder trust strip |
| founder-web/src/mail_pure.ts, MailCompose.tsx | rows, chips, compose logic (INHERITABLE already) | as before |
Awam files stay FROZEN until the awam migration phase; nothing under lovable-gold/ is edited. Founder and awam code are never mixed in one file.

## The cryptography of this UI (no new crypto was invented in the UI)
Every call goes through the Rust WASM kernel: server answers carry an Ed25519 signature that the kernel verifies in the browser; requests from the browser are HMAC-SHA256 + HKDF signed; the mail ledger and the per-message proof are SHA-256 hash chains re-hashed in the kernel; a send is bound to a SHA-256 touch target (mail_pure.sendTarget = fmail_mime::send_target). Sealed rows never leak text into search (matchQuery). The same doors carry the awam mailbox later (own tables, own SQL numbers, customer wording).

## Rules for any later change
1. A listed file changes ONLY with the manifest updated in the same commit (python3 docs/cursor-work/server/awam_inherit.py sync); the gate refuses otherwise.
2. Business Premium and Business MAX get the SAME UI; only limits and domain differ (plan caps are a separate order).
3. No Bun/Node, no WebSocket, no mock data in the shipped UI; HTTP/3 + WebTransport via the kernel.
4. Backup of the UI before it went live: commit e22020ab (FOUNDER-BACKUP-LAW record #4).

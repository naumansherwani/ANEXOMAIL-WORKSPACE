# Mailbox <-> Bridge connection + the ledger box (PROPOSAL, 13 Nov 19:25, NOT BUILT; UI law: waits his haan)
His question (19:22): the big "Verify ledger anchor / Open encrypted vault" box in the empty reading pane: right place, or move to Bridge? Define the Bridge <-> mailbox connection.
## What exists (facts)
- The box = empty state of the reading pane (MailView.tsx, class mp-qa), shown only while no message is selected.
- ONE data source: `fmail_ledger` (hash-chained, append-only). Mailbox writes it (arrival, quarantine_in, unseal, send); Bridge reads it through `fmail_bridge_feed` (E168) into lanes (mail-quarantine counts `quarantine_in`). Same table, two views, no copy.
## Chairman view
- Mailbox = work surface: reading, acting. Chain verification is an AUDIT act, not a reading act, so it belongs in Bridge (audit/health surface).
- Proposal P1: Bridge gets one "Mail ledger" lane card: head #, chain verified (button Verify), Quarantined / Opaque / Unsealed counts, click = mailbox filtered to that folder (lane click-to-filter already approved, LA-6).
- P2: reading-pane empty state shrinks to the one-line text + a small "Ledger: verified up to #N" status chip (data only, from the same feed); the two big buttons go away. Vault stays reachable from the folder list.
- Per-message proof pill (Ledger anchor verified SHA-256) stays in the message: that proves THAT message, and is the right place.
- All additive, same code on 390/820/1200+; nothing touches Scene3D.tsx (orb/BridgeMap).
## Needs: his one word "haan P1" and "haan P2" (separately). Until then the UI stays as is.

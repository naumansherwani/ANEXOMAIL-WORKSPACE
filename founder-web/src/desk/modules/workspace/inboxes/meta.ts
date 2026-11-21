import type { DeskModule } from "../../types";
/** Inboxes: Company mailboxes: hello, moveyourbusiness, resolved; billing restricted folder; leo automation; noreply send-only; support@ banned. Planned in phase R4-2; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "inboxes",
  "group": "Anexomail Workspace",
  "label": "Inboxes",
  "what": "Company mailboxes: hello, moveyourbusiness, resolved; billing restricted folder; leo automation; noreply send-only; support@ banned",
  "tech": "Rust axum, Postgres RLS fadm_mailbox, WASM kernel, ML-KEM mail",
  "phase": "R4-2",
  "founderSource": "Mail Desk",
  "status": "planned"
};

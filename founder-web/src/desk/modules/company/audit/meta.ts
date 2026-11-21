import type { DeskModule } from "../../types";
/** Audit: The append-only hash-chained ledger, verify, export. Planned in phase R3g; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "audit",
  "group": "Company",
  "label": "Audit",
  "what": "The append-only hash-chained ledger, verify, export",
  "tech": "Postgres ledger (AD1), transparent log later, Rust",
  "phase": "R3g",
  "founderSource": null,
  "status": "planned"
};

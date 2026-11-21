import type { DeskModule } from "../../types";
/** Automations: Auto-acknowledge (RFC 3834), triggers, escalation timers, follow-up reminders. Planned in phase R3c; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "automations",
  "group": "Anexomail Workspace",
  "label": "Automations",
  "what": "Auto-acknowledge (RFC 3834), triggers, escalation timers, follow-up reminders",
  "tech": "Rust, RFC 3834, Postgres",
  "phase": "R3c",
  "founderSource": null,
  "status": "planned"
};

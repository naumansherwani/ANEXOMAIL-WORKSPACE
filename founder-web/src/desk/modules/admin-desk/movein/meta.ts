import type { DeskModule } from "../../types";
/** Managed Move-In: Customer onboarding cockpit: slots, cut-overs, mailbox and DNS checks. Planned in phase R4-11; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "movein",
  "group": "Admin Desk",
  "label": "Managed Move-In",
  "what": "Customer onboarding cockpit: slots, cut-overs, mailbox and DNS checks",
  "tech": "Rust, DNS probes, Postgres, kernel",
  "phase": "R4-11",
  "founderSource": "Managed Move-In",
  "status": "planned"
};

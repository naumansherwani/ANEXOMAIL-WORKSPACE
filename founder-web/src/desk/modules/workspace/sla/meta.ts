import type { DeskModule } from "../../types";
/** SLA clocks: Plan-based first-response and resolution clocks, breach warnings, pause rules. Planned in phase R3f; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "sla",
  "group": "Anexomail Workspace",
  "label": "SLA clocks",
  "what": "Plan-based first-response and resolution clocks, breach warnings, pause rules",
  "tech": "Rust scheduler, Postgres, plan rows (R3p)",
  "phase": "R3f",
  "founderSource": null,
  "status": "planned"
};

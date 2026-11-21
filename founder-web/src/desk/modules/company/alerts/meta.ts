import type { DeskModule } from "../../types";
/** Alerts: Circuit-breaker freezes, SLA breaches, key events (Desk's own bridge, never the Founder Bridge). Planned in phase ON11; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "alerts",
  "group": "Company",
  "label": "Alerts",
  "what": "Circuit-breaker freezes, SLA breaches, key events (Desk's own bridge, never the Founder Bridge)",
  "tech": "Postgres fadm_alert, Rust",
  "phase": "ON11",
  "founderSource": null,
  "status": "planned"
};

import type { DeskModule } from "../../types";
/** Routing: Rules that put a case in the right queue by plan, language, topic and skill; load balancing. Planned in phase R3b; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "routing",
  "group": "Anexomail Workspace",
  "label": "Routing",
  "what": "Rules that put a case in the right queue by plan, language, topic and skill; load balancing",
  "tech": "Rust rules engine, Postgres policy tables",
  "phase": "R3b",
  "founderSource": null,
  "status": "planned"
};

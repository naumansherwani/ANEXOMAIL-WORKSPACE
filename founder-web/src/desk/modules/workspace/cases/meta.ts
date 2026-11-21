import type { DeskModule } from "../../types";
/** Cases: Every user problem as a case: owner, status, priority, history, one-click assign, close with root cause. Planned in phase R3b; not connected yet (the rail says so, nothing is faked). */
export const meta: DeskModule = {
  "key": "cases",
  "group": "Anexomail Workspace",
  "label": "Cases",
  "what": "Every user problem as a case: owner, status, priority, history, one-click assign, close with root cause",
  "tech": "Rust, Postgres RLS + relation tuples (AD2), kernel signed calls",
  "phase": "R3b",
  "founderSource": null,
  "status": "planned"
};

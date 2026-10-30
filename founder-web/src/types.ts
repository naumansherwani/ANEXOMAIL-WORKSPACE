// Shared founder UI types. The account profile as the SPA holds it (built from GET /founder/v1/settings).
import type { Place } from "./places";
export type Prof = {
  email?: string;
  available?: boolean;
  settings: Record<string, unknown>;
  display_name: string;
  avatar_url: string | null;
  home: Place | null;
};
export type Msg = { ok: boolean; t: string } | null;

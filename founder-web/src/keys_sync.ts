// QC8c (21 Nov 2026, his DONO word 04:55): wires E199 (switch sync) and E200 (key audit log) to the app. NEW FILE. Technology: TypeScript, signed kernel-verified calls (api.get / api.post / api.setSetting).
// The browser copy stays the FAST copy (keys_store.ts): the keys never wait for the network, and a failed call changes nothing the person sees.
import { get, post, setSetting } from "./api";
import { readSingle, writeSingle, subscribeSingle, notifySingle } from "./keys_store";

export const SETTING = "mail.single_keys";

import { reconcile, folderWord } from "./keys_sync_pure";

let started = false;
/** Once per page load: pull the stored switch, follow it, and (migration) push this device's OFF if the server has none. Silent on every failure. */
export async function syncSwitch(): Promise<void> {
  if (started) return; started = true;
  try {
    const r = (await get("/founder/v1/settings")).data;
    const v = r?.settings?.[SETTING];
    const server = typeof v === "boolean" ? v : (v && typeof v === "object" && typeof v.value === "boolean" ? v.value : undefined);
    const d = reconcile(server, readSingle());
    if (typeof d.apply === "boolean") { writeSingle(d.apply); notifySingle(); }
    if (typeof d.push === "boolean") void setSetting(SETTING, d.push).catch(() => {});
  } catch { /* offline, signed out, old server: the browser copy keeps working */ }
}

/** The person flipped the switch in Settings: keep the server copy in step (fire and forget). */
export function pushSwitch(on: boolean): void { try { void setSetting(SETTING, on).catch(() => {}); } catch { /* ignore */ } }

/** Report one key action to the E200 log. No mail id, subject or address is ever sent. Fire and forget; the log refuses past 600 an hour, which is fine. */
export function logKey(action: "archive" | "trash" | "star" | "unread", via: "key" | "batch", n: number, folder?: string | null): void {
  try {
    const label = folder ?? document.querySelector(".mbx-apps .mbx-f[aria-current=\"page\"]")?.getAttribute("title");
    void post("/founder/v1/mail/keys/log", { action, via, n, folder: folderWord(label) }).catch(() => {});
  } catch { /* ignore */ }
}
export { subscribeSingle };

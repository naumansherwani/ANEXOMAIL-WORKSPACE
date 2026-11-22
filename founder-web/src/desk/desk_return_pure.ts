// ADMIN DESK desk_return_pure.ts (23 Nov 2026, his word 03:38: "kpi card pe jaye aur wapis ana ho to folder ko pata hona chahiye ke wapis bhi jana hota hai"):
// the Desk REMEMBERS which card page you opened, so when you come back to the Dashboard that card wears the same red mark the service row wears, and it scrolls into view.
// Pure: path in, id out. Storage is only a per-tab convenience (sessionStorage, wrapped in try/catch); the page works without it.
const KEY = "anexo.desk.from";
/** "/dashboard/alerts?severity=urgent#x" -> "alerts"; the dashboard itself or anything else -> "". */
export function subOf(to: string): string {
  const p = to.split("#")[0].split("?")[0].replace(/\/+$/, "");
  return p.startsWith("/dashboard/") ? p.slice("/dashboard/".length).split("/")[0] : "";
}
export const isHome = (path: string) => path.replace(/\/+$/, "") === "/dashboard";
const ok = (id: string) => /^[a-z]{2,20}$/.test(id);
export function remember(to: string, store: Pick<Storage, "setItem"> | null = safe()): void { const id = subOf(to); if (id && ok(id)) try { store?.setItem(KEY, id); } catch { /* ignore */ } }
export function origin(path: string, store: Pick<Storage, "getItem"> | null = safe()): string { if (!isHome(path)) return ""; try { const v = store?.getItem(KEY) ?? ""; return ok(v) ? v : ""; } catch { return ""; } }
function safe(): Storage | null { try { return window.sessionStorage; } catch { return null; } }
/** CSS selectors of the one element that opens this card on the Dashboard (never a secondary link inside another card). */
export const markSelectors = (id: string) => (ok(id) ? [`a.dcl[href^="/dashboard/${id}"]`, `a.dcc-card[href="/dashboard/${id}"]`] : []);

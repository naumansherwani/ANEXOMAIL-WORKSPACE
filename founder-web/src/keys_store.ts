// QC8a (21 Nov 2026): where the single-letter-keys switch lives. HIS WORD 03:50: in THIS browser (per device), no SQL, no Rust, no server command.
// Default ON: his fast keys keep working until he switches them off. Every storage call is wrapped: private windows / blocked storage give ON, never a crash.
export const KEY = "anx.keys.single";
type Store = Pick<Storage, "getItem" | "setItem">;
const ls = (): Store | null => { try { return typeof localStorage === "undefined" ? null : localStorage; } catch { return null; } };
/** true = single-letter shortcuts work. Only an explicit "off" turns them off. */
export function readSingle(s: Store | null = ls()): boolean { try { return s?.getItem(KEY) !== "off"; } catch { return true; } }
export function writeSingle(on: boolean, s: Store | null = ls()): boolean { try { s?.setItem(KEY, on ? "on" : "off"); return s !== null; } catch { return false; } }
const subs = new Set<() => void>();
export const subscribeSingle = (f: () => void) => { subs.add(f); return () => { subs.delete(f); }; };
export const setSingle = (on: boolean) => { writeSingle(on); subs.forEach((f) => f()); };
/** QC8c: tell the listeners the stored value changed without writing it again (used when the server's copy is applied). */
export const notifySingle = () => { subs.forEach((f) => f()); };

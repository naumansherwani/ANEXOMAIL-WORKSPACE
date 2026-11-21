// QC8c: the pure part of keys_sync (no network, no kernel), so tests can run without the WASM kernel.
/** What to do with the server's answer. Pure, tested. `server` = the stored value or undefined when the founder never set it (the default is ON). */
export function reconcile(server: boolean | undefined, local: boolean): { apply?: boolean; push?: boolean } {
  if (typeof server === "boolean") return server === local ? {} : { apply: server };   // the server has his word: every device follows it
  return local ? {} : { push: false };                                                  // never set on the server, but this device is OFF: tell the server once
}

/** The closed folder word the E200 log accepts (a-z and _ only, 1..24), from the label of the folder that is open; "inbox" when unsure. */
export function folderWord(label: string | null | undefined): string {
  const w = (label ?? "").toLowerCase().replace(/[^a-z]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 24);
  return w || "inbox";
}


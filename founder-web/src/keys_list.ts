// QC8a a5 (21 Nov 2026, his order 03:55 "advance technology pe wire kero"): the DOM side of the list keys, NO change to MailBox. It only clicks the row buttons the mailbox already renders
// and re-sends the existing action keys, so select() / act() stay the single owners of what happens to a mail.
import { typeAhead } from "./mail_keymap";
import { logKey } from "./keys_sync";

const rows = () => [...document.querySelectorAll<HTMLButtonElement>(".mbx-rows .mbx-r")];
const nameOf = (b: HTMLElement) => (b.querySelector(".mbx-rb b")?.textContent ?? b.textContent ?? "").trim();

/** Spoken status. Element.ariaNotify (Baseline 2026) when the browser has it, one polite live region otherwise. One short sentence, never mail content. */
let live: HTMLElement | null = null;
export function announce(text: string) {
  try { const n = (document.body as unknown as { ariaNotify?: (t: string, o?: { priority: string }) => void }).ariaNotify; if (typeof n === "function") { n.call(document.body, text, { priority: "normal" }); return; } } catch { /* fall through to the live region */ }
  if (!live || !live.isConnected) { live = document.createElement("div"); live.setAttribute("role", "status"); live.setAttribute("aria-live", "polite"); live.className = "kl-live"; document.body.appendChild(live); }
  live.textContent = ""; window.setTimeout(() => { if (live) live.textContent = text; }, 30);
}

let anchor = -1;
const marked = () => rows().filter((b) => b.dataset.klMark === "1");
export function clearMarks() { rows().forEach((b) => { delete b.dataset.klMark; }); anchor = -1; }
export const markedCount = () => marked().length;
/** The list changed (mail arrived / moved): marks refer to old rows, so they are dropped. One observer for the whole layer; returns its disposer. */
export function trackList(): () => void {
  let n = rows().length; const o = new MutationObserver(() => { const c = rows().length; if (c !== n) { n = c; if (!busy && marked().length) clearMarks(); } });
  o.observe(document.body, { childList: true, subtree: true }); return () => o.disconnect();
}

/** Home / End. */
export function jump(end: boolean) { const all = rows(), t = end ? all[all.length - 1] : all[0]; if (!t) return false; t.click(); t.focus({ preventScroll: true }); t.scrollIntoView({ block: "nearest" }); clearMarks(); return true; }

/** Shift + Down / Up: marks the range from the anchor to the new row and moves the reading pane with it. */
export function extend(dir: 1 | -1) {
  const all = rows(); if (!all.length) return false;
  const cur = Math.max(0, all.findIndex((b) => b.classList.contains("on") || b === document.activeElement));
  if (anchor < 0) anchor = cur;
  const to = Math.min(all.length - 1, Math.max(0, cur + dir));
  const [a, z] = anchor <= to ? [anchor, to] : [to, anchor];
  all.forEach((b, i) => { if (i >= a && i <= z) b.dataset.klMark = "1"; else delete b.dataset.klMark; });
  all[to].click(); all[to].focus({ preventScroll: true }); all[to].scrollIntoView({ block: "nearest" });
  const n = z - a + 1; announce(n === 1 ? "1 mail selected" : `${n} mails selected`); return true;
}

/** Type-ahead (only while a row has focus): the first row whose sender starts with what was typed, after the current one. */
let buf = "", last = 0;
export function ahead(key: string) {
  const all = rows(); if (!all.length) return false;
  const cur = all.findIndex((b) => b === document.activeElement || b.classList.contains("on")), now = Date.now();
  const r = typeAhead(all.map(nameOf), cur, buf, key, now, last); buf = r.buf; last = now;
  if (r.hit < 0) return false; all[r.hit].click(); all[r.hit].focus({ preventScroll: true }); all[r.hit].scrollIntoView({ block: "nearest" }); return true;
}

let busy = false;
const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));
/** One action key (e # s u) on EVERY marked mail: for each row, open it (the existing select), wait until it is the open one, send the existing key. Max 50 mails, sequential. */
export async function batch(key: string, send: (k: string) => void) {
  if (busy) return; const list = marked().slice(0, 50); if (list.length < 2) return;
  busy = true;
  try {
    let done = 0;
    for (const b of list) {
      if (!b.isConnected) continue;
      b.click();
      for (let i = 0; i < 30 && !(b.isConnected && b.classList.contains("on")); i++) await wait(50);
      if (!b.isConnected || !b.classList.contains("on")) continue;
      send(key); done++; await wait(450);
    }
    announce(done === 1 ? "Done for 1 mail" : `Done for ${done} mails`);
    if (done >= 2) logKey(({ e: "archive", "#": "trash", s: "star", u: "unread" } as const)[key as "e" | "#" | "s" | "u"], "batch", Math.min(done, 50));   // E200: one batch row
  } finally { busy = false; clearMarks(); }
}

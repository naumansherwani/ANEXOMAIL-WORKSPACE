import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import { Switch } from "@/components/ui/switch";
import { HELP_ROWS, helpFor, silenceSingle } from "./mail_keymap";
import { readSingle, setSingle, subscribeSingle } from "./keys_store";
import "./keylayer.css";

// QC8a (21 Nov 2026, his haan 03:50): the keyboard layer, ONE mount line in App.tsx. It ADDS to the existing handlers and edits none of them:
//  1) switch OFF -> a capture-phase listener swallows bare single-letter shortcuts before MailBox / App ever see them (WCAG 2.1.4, level A);
//  2) Up / Down in the mail list re-send the existing j / k key (no change to MailBox);
//  3) "?" opens a native <dialog> (browser traps focus, Esc closes) listing the keys of the screen he is on, with the switch at the bottom.
export const useSingleKeys = () => useSyncExternalStore(subscribeSingle, () => readSingle(), () => true);

const typingIn = (t: EventTarget | null) => { const el = t as HTMLElement | null; return !!el && (/^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName) || el.isContentEditable); };
const interactive = (t: EventTarget | null) => !!(t as HTMLElement | null)?.closest?.("button,a,input,textarea,select,[role=button],[role=menuitem],[role=switch],[contenteditable=true]");

export function KeyLayer() {
  const dlg = useRef<HTMLDialogElement>(null), own = useRef(false), [open, setOpen] = useState(false), [mail, setMail] = useState(false);
  const on = useSingleKeys();
  useEffect(() => {
    const k = (e: KeyboardEvent) => {
      if (own.current || e.isComposing) return;
      const m = { ctrl: e.ctrlKey, meta: e.metaKey, alt: e.altKey, shift: e.shiftKey };
      const dialogOpen = !!document.querySelector("dialog[open]") || !!(e.target as HTMLElement | null)?.closest?.("[role=dialog]");
      const scene = { composeOpen: !!document.querySelector(".mc-wrap"), inDialog: dialogOpen, typing: typingIn(e.target) };
      if (e.key === "?" && !m.ctrl && !m.meta && !m.alt && !scene.typing && !scene.inDialog && !scene.composeOpen) { e.preventDefault(); e.stopImmediatePropagation(); setMail(!!document.querySelector(".mbx-rows")); setOpen(true); return; }
      if (silenceSingle(e.key, m, readSingle(), scene)) { e.stopImmediatePropagation(); return; }
      // Home / End in the mail list: open the first / last row by clicking its own button (the existing select() does the work).
      if ((e.key === "Home" || e.key === "End") && !m.ctrl && !m.meta && !m.alt && !m.shift && !scene.typing && !scene.inDialog && !scene.composeOpen
          && document.querySelector(".mbx-rows") && (!interactive(e.target) || !!(e.target as HTMLElement).closest?.(".mbx-rows"))) {
        const all = document.querySelectorAll<HTMLButtonElement>(".mbx-rows .mbx-r"), t = e.key === "Home" ? all[0] : all[all.length - 1];
        if (t) { e.preventDefault(); e.stopImmediatePropagation(); t.click(); t.focus({ preventScroll: true }); t.scrollIntoView({ block: "nearest" }); }
        return;
      }
      // Up / Down in the mail list: the existing j / k does the real work. Only when nothing else owns the arrows.
      if ((e.key === "ArrowDown" || e.key === "ArrowUp") && !m.ctrl && !m.meta && !m.alt && !m.shift && !scene.typing && !scene.inDialog && !scene.composeOpen
          && document.querySelector(".mbx-rows") && (!interactive(e.target) || !!(e.target as HTMLElement).closest?.(".mbx-rows"))) {
        e.preventDefault(); e.stopImmediatePropagation();
        own.current = true; try { window.dispatchEvent(new KeyboardEvent("keydown", { key: e.key === "ArrowDown" ? "j" : "k", bubbles: true })); } finally { own.current = false; }
      }
    };
    window.addEventListener("keydown", k, true); return () => window.removeEventListener("keydown", k, true);
  }, []);
  useEffect(() => { const d = dlg.current; if (!d) return; if (open && !d.open) d.showModal(); if (!open && d.open) d.close(); }, [open]);
  const rows = mail ? helpFor("mail") : HELP_ROWS.filter((r) => r.where === "page");
  return (
    <dialog ref={dlg} className="kl" aria-labelledby="kl-t" onClose={() => setOpen(false)} onClick={(e) => { if (e.target === dlg.current) setOpen(false); }}>
      {open && (
        <div className="kl-in">
          <h3 id="kl-t">Keyboard shortcuts</h3>
          <p className="kl-sub">{mail ? "Mail" : "This page"} · press ? any time, Esc to close</p>
          <dl className="kl-rows">{rows.map((r) => <div key={r.keys + r.does} className="kl-row"><dt><kbd>{r.keys}</kbd></dt><dd>{r.does}</dd></div>)}</dl>
          <div className="kl-sw"><div><b>Single-letter keys</b><p>{on ? "ON: j k c e s … work." : "OFF: only Ctrl keys, arrows, Enter and Esc."}</p></div>
            <Switch checked={on} aria-label="Single-letter keys" onCheckedChange={(v) => setSingle(v)} /></div>
          <div className="kl-act"><button type="button" className="kl-b" onClick={() => setOpen(false)}>Close</button></div>
        </div>
      )}
    </dialog>
  );
}

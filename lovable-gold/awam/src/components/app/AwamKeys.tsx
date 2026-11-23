// AWAM keys: Ctrl+D home, Ctrl+/ Keys sheet, Alt+Shift+letter pages, Alt+Shift+Up/Down walk the rail, rail follows the open page. NEW file; AppShell mounts it with one hook call.
// Ctrl+K search (CommandPalette.tsx) and the mail list keys are untouched. Pure logic + tests: src/lib/awam-keys.ts.
import { useEffect, useRef, useState, type ReactNode } from "react";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { AWAM_PAGES, awamComboTarget, awamCurrent, awamHelpKey, awamHomeKey, awamKeyLabel, awamStep, awamStepKey } from "@/lib/awam-keys";

const typingIn = (t: EventTarget | null) => { const el = t as HTMLElement | null; return !!el && (/^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName) || el.isContentEditable); };
const RAIL = 'nav[aria-label="Workspace navigation"]';

export function useAwamKeys(go: (to: string) => void, pathname: string, t: (s: string) => string): { help: ReactNode } {
  const [open, setOpen] = useState(false), goRef = useRef(go); goRef.current = go;
  useEffect(() => {
    const on = (e: KeyboardEvent) => {
      if (e.repeat) return;
      if (awamHelpKey(e)) { e.preventDefault(); setOpen((v) => !v); return; }
      if (typingIn(e.target) || document.querySelector('[role="dialog"],[role="alertdialog"]')) return;
      const to = (awamHomeKey(e) ? "/app" : null) ?? awamComboTarget(e);
      if (to) { e.preventDefault(); if (to === "/app/chat") window.open((import.meta.env["VITE_ANEXOCHAT_URL"] as string | undefined) || "/app/chat", "_blank", "noopener"); else goRef.current(to); return; }
      const sd = awamStepKey(e);
      if (sd) {
        e.preventDefault();
        const seen: string[] = [];
        document.querySelectorAll<HTMLAnchorElement>(`${RAIL} a[href]`).forEach((a) => { const c = awamCurrent(new URL(a.href, window.location.origin).pathname); if (c && !seen.includes(c)) seen.push(c); });
        const next = awamStep(seen, awamCurrent(window.location.pathname), sd), p = AWAM_PAGES.find((x) => x.to === next);
        if (p && p.to !== "/app/chat") goRef.current(p.go ?? p.to);
      }
    };
    window.addEventListener("keydown", on); return () => window.removeEventListener("keydown", on);
  }, []);
  // the rail scrolls so the open page is in view; block "nearest" moves nothing when it already is (look untouched)
  useEffect(() => { document.querySelector<HTMLElement>(`${RAIL} [aria-current="page"]`)?.scrollIntoView?.({ block: "nearest" }); }, [pathname]);
  const help = (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent>
        <DialogHeader><DialogTitle>{t("Keyboard shortcuts")}</DialogTitle><DialogDescription>{t("Ctrl+K search · Alt+Shift+Up / Down walk the rail · Esc closes")}</DialogDescription></DialogHeader>
        <ul className="max-h-[60vh] overflow-y-auto">
          {AWAM_PAGES.map((p) => <li key={p.to} className="flex min-h-11 items-center justify-between gap-3 text-sm"><span>{t(p.label)}</span><kbd className="text-xs text-muted-foreground">{awamKeyLabel(p.to)}</kbd></li>)}
        </ul>
      </DialogContent>
    </Dialog>
  );
  return { help };
}

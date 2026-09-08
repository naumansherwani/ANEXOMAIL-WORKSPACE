import { Check, Globe } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { setLocale, useLocale } from "@/lib/i18n";
import { LOCALES } from "@/lib/locales";

/**
 * Real language picker — har entry asli zubaan hai, apni script mein.
 * Choice localStorage mein save hoti hai aur `<html lang/dir>` set karti hai
 * (Urdu · Arabic · Farsi · Hebrew par poori site right-to-left ho jati hai).
 */
export function LanguagePicker({ className = "" }: { className?: string }) {
  const { locale } = useLocale();
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (!box.current?.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <div ref={box} className={`relative ${className}`}>
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={`Language: ${locale.english}`}
        className="ax-focus flex items-center gap-2 rounded-full border border-border/70 px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"
      >
        <Globe className="size-4 shrink-0" aria-hidden="true" />
        <span className="text-[11px] font-semibold tracking-wider uppercase">{locale.region}</span>
        <span className="max-w-[10rem] truncate">{locale.native}</span>
      </button>

      {open && (
        <div
          role="listbox"
          aria-label="Choose your language"
          className="absolute end-0 z-50 mt-2 max-h-[22rem] w-64 overflow-y-auto rounded-2xl border border-border bg-card p-1.5 shadow-elev-2"
        >
          {LOCALES.filter((l) => l.tag === "en-GB").map((l) => {
            const active = l.tag === locale.tag;
            return (
              <button
                key={l.tag}
                type="button"
                role="option"
                aria-selected={active}
                lang={l.tag}
                dir={l.dir}
                onClick={() => {
                  setLocale(l);
                  setOpen(false);
                }}
                className={`flex w-full items-center gap-2.5 rounded-xl px-2.5 py-2 text-start text-sm transition-colors ${
                  active
                    ? "bg-surface-2 text-foreground"
                    : "text-muted-foreground hover:bg-surface-2 hover:text-foreground"
                }`}
              >
                <span className="text-[10px] font-semibold tracking-wider text-steel uppercase">
                  {l.region}
                </span>
                <span className="flex-1 truncate">{l.native}</span>
                {active && <Check className="size-3.5 shrink-0" aria-hidden="true" />}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}

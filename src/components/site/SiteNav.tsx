import { Link } from "@tanstack/react-router";
import { Menu, Sparkles, X } from "lucide-react";
import { useState } from "react";

import { BrandMark } from "./BrandMark";

const links = [
  { label: "Features", href: "/#features" },
  { label: "Pricing", href: "/#pricing" },
  { label: "Security", href: "/#security" },
  { label: "Setup", href: "/#setup" },
];

export function SiteNav() {
  const [open, setOpen] = useState(false);

  return (
    <header className="sticky top-0 z-50 border-b border-border/60 bg-background/80 backdrop-blur-xl">
      <nav className="ax-container flex h-16 items-center gap-6">
        <Link to="/" className="shrink-0">
          <BrandMark />
        </Link>

        <div className="ml-auto hidden items-center gap-7 md:flex">
          {links.map((l) => (
            <a
              key={l.href}
              href={l.href}
              className="text-sm font-medium whitespace-nowrap text-muted-foreground transition-colors hover:text-foreground"
            >
              {l.label}
            </a>
          ))}
          <Link
            to="/ai"
            className="inline-flex items-center gap-1.5 rounded-full border border-indigo/40 bg-indigo/10 px-3 py-1.5 text-xs font-semibold whitespace-nowrap text-foreground transition-colors hover:bg-indigo/20"
          >
            <Sparkles className="size-3.5 text-indigo" />
            ANEXOMAIL AI
          </Link>
        </div>

        <div className="hidden items-center gap-2 md:flex">
          <a
            href="/#pricing"
            className="rounded-xl px-3 py-2 text-sm font-medium whitespace-nowrap text-muted-foreground transition-colors hover:text-foreground"
          >
            Sign in
          </a>
          <a
            href="/#pricing"
            className="rounded-xl bg-primary px-4 py-2 text-sm font-semibold whitespace-nowrap text-primary-foreground shadow-elev-1 transition-colors hover:bg-primary/90"
          >
            Get started
          </a>
        </div>

        <button
          type="button"
          aria-label="Toggle menu"
          onClick={() => setOpen((v) => !v)}
          className="ml-auto flex size-9 items-center justify-center rounded-xl border border-border text-foreground md:hidden"
        >
          {open ? <X className="size-4" /> : <Menu className="size-4" />}
        </button>
      </nav>

      {open && (
        <div className="border-t border-border bg-card md:hidden">
          <div className="ax-container flex flex-col gap-1 py-4">
            {links.map((l) => (
              <a
                key={l.href}
                href={l.href}
                onClick={() => setOpen(false)}
                className="rounded-lg px-2 py-2.5 text-sm font-medium text-muted-foreground hover:bg-surface-2 hover:text-foreground"
              >
                {l.label}
              </a>
            ))}
            <Link
              to="/ai"
              onClick={() => setOpen(false)}
              className="rounded-lg px-2 py-2.5 text-sm font-semibold text-foreground hover:bg-surface-2"
            >
              ANEXOMAIL AI
            </Link>
            <a
              href="/#pricing"
              onClick={() => setOpen(false)}
              className="mt-2 rounded-xl bg-primary px-4 py-2.5 text-center text-sm font-semibold text-primary-foreground"
            >
              Get started
            </a>
          </div>
        </div>
      )}
    </header>
  );
}

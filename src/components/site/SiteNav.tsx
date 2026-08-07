import { Link } from "@tanstack/react-router";
import { Menu, Sparkles, X } from "lucide-react";
import { useState } from "react";

import { BrandMark } from "./BrandMark";

const links = [
  { label: "Workspace", to: "/app" as const },
  { label: "Delivery", to: "/security" as const },
  { label: "Ownership", to: "/ownership" as const },
  { label: "Plans", to: "/plans" as const },
  { label: "Move in", to: "/move-in" as const },
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
            <Link
              key={l.to}
              to={l.to}
              activeProps={{ className: "text-foreground" }}
              className="text-sm font-medium whitespace-nowrap text-muted-foreground transition-colors hover:text-foreground"
            >
              {l.label}
            </Link>
          ))}
          <Link
            to="/ai"
            className="inline-flex items-center gap-1.5 rounded-full border border-steel/35 bg-secondary px-3 py-1.5 text-xs font-semibold whitespace-nowrap text-foreground transition-colors hover:border-steel/60"
          >
            <Sparkles className="size-3.5 text-steel" />
            ANEXOMAIL AI
          </Link>
        </div>

        <div className="hidden items-center gap-2 md:flex">
          <Link
            to="/app"
            className="rounded-xl px-3 py-2 text-sm font-medium whitespace-nowrap text-muted-foreground transition-colors hover:text-foreground"
          >
            Sign in
          </Link>
          <Link
            to="/move-in"
            className="rounded-xl bg-primary px-4 py-2 text-sm font-semibold whitespace-nowrap text-primary-foreground shadow-elev-1 transition-colors hover:bg-primary/90"
          >
            Get started
          </Link>
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
              <Link
                key={l.to}
                to={l.to}
                onClick={() => setOpen(false)}
                className="rounded-lg px-2 py-2.5 text-sm font-medium text-muted-foreground hover:bg-surface-2 hover:text-foreground"
              >
                {l.label}
              </Link>
            ))}
            <Link
              to="/ai"
              onClick={() => setOpen(false)}
              className="rounded-lg px-2 py-2.5 text-sm font-semibold text-foreground hover:bg-surface-2"
            >
              ANEXOMAIL AI
            </Link>
            <Link
              to="/move-in"
              onClick={() => setOpen(false)}
              className="mt-2 rounded-xl bg-primary px-4 py-2.5 text-center text-sm font-semibold text-primary-foreground"
            >
              Get started
            </Link>
          </div>
        </div>
      )}
    </header>
  );
}

import { Link } from "@tanstack/react-router";
import { Menu, X } from "lucide-react";
import { useState } from "react";

import { BrandMark } from "./BrandMark";

const links = [
  { label: "Workspace", to: "/app" as const },
  { label: "About", to: "/about" as const },
  { label: "Security", to: "/security" as const },
  { label: "Ownership", to: "/ownership" as const },
  { label: "Pricing", to: "/plans" as const },
  { label: "Migration", to: "/move-in" as const },
];

export function SiteNav() {
  const [open, setOpen] = useState(false);

  return (
    <header className="sticky top-0 z-50 border-b border-border/60 bg-background/80 backdrop-blur-xl">
      <nav className="ax-container flex h-20 items-center gap-6">
        <Link to="/" className="shrink-0">
          <BrandMark />
        </Link>

        <div className="mx-auto hidden items-center gap-8 md:flex">
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
        </div>

        <div className="hidden shrink-0 items-center gap-2 md:flex">
          <Link
            to="/auth"
            className="ax-focus rounded-full px-4 py-2.5 text-sm font-semibold whitespace-nowrap text-muted-foreground transition-colors hover:text-foreground"
          >
            Sign in
          </Link>
          <Link
            to="/auth"
            className="rounded-full bg-primary px-5 py-2.5 text-sm font-semibold whitespace-nowrap text-primary-foreground shadow-elev-1 transition-colors duration-200 hover:bg-primary/85"
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
              to="/auth"
              onClick={() => setOpen(false)}
              className="rounded-lg px-2 py-2.5 text-sm font-semibold text-foreground hover:bg-surface-2"
            >
              Sign in
            </Link>
            <Link
              to="/auth"
              onClick={() => setOpen(false)}
              className="mt-2 rounded-full bg-primary px-4 py-2.5 text-center text-sm font-semibold text-primary-foreground"
            >
              Get started
            </Link>
          </div>
        </div>
      )}
    </header>
  );
}

import { Link } from "@tanstack/react-router";
import { Menu, X } from "lucide-react";
import { useState } from "react";

import { useLocale } from "@/lib/i18n";
import type { LocaleKey } from "@/lib/locales";

import { BrandMark } from "./BrandMark";
import { LanguagePicker } from "./LanguagePicker";

const links: {
  key: LocaleKey;
  to: "/app" | "/about" | "/security" | "/ownership" | "/plans" | "/move-in" | "/anexochat";
}[] = [
  { key: "workspace", to: "/app" },
  { key: "about", to: "/about" },
  { key: "security", to: "/security" },
  { key: "ownership", to: "/ownership" },
  { key: "pricing", to: "/plans" },
  { key: "migration", to: "/move-in" },
  { key: "chat", to: "/anexochat" },
];

export function SiteNav() {
  const [open, setOpen] = useState(false);
  const { t } = useLocale();

  return (
    <header className="sticky top-0 z-50 border-b border-border/60 bg-background/80 backdrop-blur-xl">
      <nav className="ax-container flex h-20 items-center gap-6">
        <Link to="/" className="shrink-0">
          <BrandMark home={false} />
        </Link>

        <div className="mx-auto hidden items-center gap-7 md:flex">
          {links.map((l) => (
            <Link
              key={l.to}
              to={l.to}
              activeProps={{
                className: "ax-platinum-text after:scale-x-100 after:opacity-100",
                "aria-current": "page",
              }}
              className="relative py-1 text-sm font-medium whitespace-nowrap text-muted-foreground transition-colors after:pointer-events-none after:absolute after:-bottom-0.5 after:left-0 after:h-[2px] after:w-full after:origin-left after:scale-x-0 after:rounded-full after:bg-primary after:opacity-0 after:transition-transform after:duration-200 hover:text-foreground hover:after:scale-x-100 hover:after:opacity-60"
            >
              {t(l.key)}
            </Link>
          ))}
          <a
            href="/ai"
            target="_blank"
            rel="noopener"
            className="text-sm font-medium whitespace-nowrap text-muted-foreground transition-colors hover:text-foreground"
          >
            {t("ai")}
          </a>
        </div>

        <div className="hidden shrink-0 items-center gap-2 md:flex">
          <LanguagePicker />
          <Link
            to="/auth"
            className="ax-focus rounded-full px-4 py-2.5 text-sm font-semibold whitespace-nowrap text-muted-foreground transition-colors hover:text-foreground"
          >
            {t("signIn")}
          </Link>
          <Link
            to="/auth"
            className="rounded-full bg-primary px-5 py-2.5 text-sm font-semibold whitespace-nowrap text-primary-foreground shadow-elev-1 transition-colors duration-200 hover:bg-primary/85"
          >
            {t("getStarted")}
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
                activeProps={{
                  className: "border-l-2 border-primary bg-surface-2 text-foreground",
                  "aria-current": "page",
                }}
                className="rounded-lg px-2 py-2.5 text-sm font-medium text-muted-foreground hover:bg-surface-2 hover:text-foreground"
              >
                {t(l.key)}
              </Link>
            ))}

            <a
              href="/ai"
              target="_blank"
              rel="noopener"
              onClick={() => setOpen(false)}
              className="rounded-lg px-2 py-2.5 text-sm font-medium text-muted-foreground hover:bg-surface-2 hover:text-foreground"
            >
              {t("ai")}
            </a>
            <div className="px-2 py-2">
              <LanguagePicker />
            </div>
            <Link
              to="/auth"
              onClick={() => setOpen(false)}
              className="rounded-lg px-2 py-2.5 text-sm font-semibold text-foreground hover:bg-surface-2"
            >
              {t("signIn")}
            </Link>
            <Link
              to="/auth"
              onClick={() => setOpen(false)}
              className="mt-2 rounded-full bg-primary px-4 py-2.5 text-center text-sm font-semibold text-primary-foreground"
            >
              {t("getStarted")}
            </Link>
          </div>
        </div>
      )}
    </header>
  );
}

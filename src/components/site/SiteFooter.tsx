import { Link } from "@tanstack/react-router";
import { Mail } from "lucide-react";

import { BrandMark } from "./BrandMark";

const groups = [
  {
    title: "Product",
    items: [
      { label: "Workspace", to: "/app" as const },
      { label: "Pricing", to: "/plans" as const },
      { label: "Managed migration", to: "/migration" as const },
      { label: "Move in", to: "/move-in" as const },
      { label: "Sign in", to: "/auth" as const },
    ],
  },
  {
    title: "ANEXOMAIL AI",
    items: [
      { label: "Overview", to: "/ai" as const },
      { label: "Meet LEO", to: "/ai" as const },
      { label: "AI Studio", to: "/ai/studio" as const },
      { label: "AI Automation", to: "/ai/automation" as const },
    ],
  },
  {
    title: "Company",
    items: [
      { label: "About", to: "/about" as const },
      { label: "Partner programme", to: "/partners" as const },
      { label: "Enterprise support", to: "/enterprise" as const },
      { label: "Security", to: "/security" as const },
      { label: "Ownership", to: "/ownership" as const },
    ],
  },
];

export function SiteFooter() {
  return (
    <footer className="border-t border-border bg-card/50">
      <div className="ax-container grid gap-x-8 gap-y-12 py-16 md:grid-cols-2 lg:grid-cols-[1.6fr_1fr_1fr_1fr]">
        <div className="max-w-sm">
          <BrandMark />
          <p className="mt-5 text-sm leading-relaxed text-muted-foreground">
            Private business email on your own domain — mail, contacts, calendar and shared
            work on one fast surface. Your domain, your data, your keys.
          </p>
          <a
            href="mailto:hello@anexomail.com"
            className="mt-5 inline-flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
          >
            <Mail className="size-4 shrink-0" aria-hidden="true" /> hello@anexomail.com
          </a>
        </div>

        {groups.map((g) => (
          <div key={g.title}>
            <h3 className="text-xs font-semibold tracking-wider text-muted-foreground uppercase">
              {g.title}
            </h3>
            <ul className="mt-5 space-y-3">
              {g.items.map((item) => (
                <li key={item.label}>
                  <Link
                    to={item.to}
                    className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    {item.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>

      <div className="border-t border-border">
        <div className="ax-container flex flex-col gap-2 py-6 text-xs text-muted-foreground sm:flex-row sm:items-center sm:justify-between">
          <span>© {new Date().getFullYear()} ANEXOMAIL™. All rights reserved.</span>
          <span>anexomail.com</span>
        </div>
      </div>
    </footer>
  );
}

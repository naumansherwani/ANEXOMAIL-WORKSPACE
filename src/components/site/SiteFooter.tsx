import { Link } from "@tanstack/react-router";

import { BrandMark } from "./BrandMark";

const groups = [
  {
    title: "Product",
    items: [
      { label: "Workspace", to: "/app" as const },
      { label: "Pricing", to: "/plans" as const },
      { label: "Migration", to: "/move-in" as const },
    ],
  },
  {
    title: "AI",
    items: [
      { label: "Leo", to: "/ai" as const },
    ],
  },
  {
    title: "Company",
    items: [
      { label: "Security", to: "/security" as const },
      { label: "Ownership", to: "/ownership" as const },
    ],
  },
  {
    title: "Resources",
    items: [
      { label: "Admin centre", to: "/app/admin" as const },
      { label: "Search", to: "/app/search" as const },
    ],
  },
];

export function SiteFooter() {
  return (
    <footer className="border-t border-border bg-card/50">
      <div className="ax-container grid gap-10 py-14 md:grid-cols-[1.4fr_repeat(4,1fr)]">
        <div>
          <BrandMark />
          <p className="mt-4 max-w-xs text-sm leading-relaxed text-muted-foreground">
            Private business email on your own domain — with the workspace tools your team
            actually uses every day.
          </p>
        </div>

        {groups.map((g) => (
          <div key={g.title}>
            <h3 className="text-xs font-semibold tracking-wider text-muted-foreground uppercase">
              {g.title}
            </h3>
            <ul className="mt-4 space-y-2.5">
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

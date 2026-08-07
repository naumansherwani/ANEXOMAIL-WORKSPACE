import { Link } from "@tanstack/react-router";

import { BrandMark } from "./BrandMark";

const groups = [
  {
    title: "Product",
    items: [
      { label: "Workspace", to: "/app" as const },
      { label: "Delivery", to: "/security" as const },
      { label: "Ownership", to: "/ownership" as const },
      { label: "Move in", to: "/move-in" as const },
    ],
  },
  {
    title: "Plans",
    items: [
      { label: "Basic", to: "/plans" as const },
      { label: "Pro", to: "/plans" as const },
      { label: "Business", to: "/plans" as const },
    ],
  },
  {
    title: "Company",
    items: [
      { label: "ANEXOMAIL AI", to: "/ai" as const },
      { label: "Admin centre", to: "/app/admin" as const },
      { label: "Search", to: "/app/search" as const },
    ],
  },
];

export function SiteFooter() {
  return (
    <footer className="border-t border-border bg-card/50">
      <div className="ax-container grid gap-10 py-14 md:grid-cols-[1.5fr_repeat(3,1fr)]">
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
          <span>© {new Date().getFullYear()} ANEXOMAIL. All rights reserved.</span>
          <span>anexomail.com</span>
        </div>
      </div>
    </footer>
  );
}

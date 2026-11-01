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
      { label: "AI plans & credits", to: "/ai" as const },
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
      { label: "Privacy & account integrity", to: "/privacy" as const },
    ],
  },
];

// Only technology that is really in the code or on the server (package.json, web-wasm/, docs/cursor-work/TECH-MAP.md section 0d).
// MoQ is shown as "planned" on purpose: it is an IETF draft and is not running. Never add a name here that is not running or not clearly marked planned.
const stack = [
  { where: "Built into your browser", what: "A Rust WebAssembly kernel — one kernel for the whole site" },
  { where: "Async engine", what: "Rust · Tokio async runtime · axum" },
  { where: "Live", what: "WebTransport · QUIC · HTTP/3 — with an honest HTTP fallback when a network blocks QUIC · MoQ (Media over QUIC) planned: IETF draft, not running yet" },
  { where: "Website", what: "React 19 · TypeScript · TanStack Start & Router · Vite 8 · Tailwind CSS 4 · Radix / shadcn · Framer Motion · GSAP · Three.js (3D, loaded only when needed)" },
  { where: "Data & files", what: "PostgreSQL with row-level security · Hetzner Storage Box for attachments · ClamAV virus scanning" },
  { where: "Mail transport", what: "Postfix · Dovecot · OpenDKIM" },
  { where: "Edge & pages", what: "Caddy (HTTP/3, automatic TLS) · Nitro on Bun renders the pages" },
  { where: "Payments", what: "Polar" },
];

export function SiteFooter() {
  return (
    <footer className="border-t border-border bg-card/50">
      <div className="ax-container grid gap-x-8 gap-y-12 py-16 md:grid-cols-2 lg:grid-cols-[1.6fr_1fr_1fr_1fr]">
        <div className="max-w-sm">
          <BrandMark />
          <p className="mt-5 text-sm leading-relaxed text-muted-foreground">
            Private business email — mail, contacts, calendar and shared work on one fast surface.
            Your data, your keys.
          </p>
          <div className="mt-5 space-y-2">
            <a
              href="mailto:resolved@anexomail.com"
              className="flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
            >
              <Mail className="size-4 shrink-0" aria-hidden="true" />
              <span>resolved@anexomail.com — support</span>
            </a>
            <a
              href="mailto:hello@anexomail.com"
              className="flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
            >
              <Mail className="size-4 shrink-0" aria-hidden="true" />
              <span>hello@anexomail.com — enquiries</span>
            </a>

            <a
              href="mailto:moveyourbusiness@anexomail.com"
              className="flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
            >
              <Mail className="size-4 shrink-0" aria-hidden="true" />
              <span>moveyourbusiness@anexomail.com — managed move-in</span>
            </a>
          </div>
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
        <div className="ax-container py-8">
          <h3 className="text-xs font-semibold tracking-wider text-muted-foreground uppercase">
            Built with
          </h3>
          <dl className="mt-4 grid gap-x-8 gap-y-2 text-xs text-muted-foreground md:grid-cols-[11rem_1fr]">
            {stack.map((row) => (
              <div key={row.where} className="contents">
                <dt className="font-medium text-foreground/80">{row.where}</dt>
                <dd>{row.what}</dd>
              </div>
            ))}
          </dl>
        </div>
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

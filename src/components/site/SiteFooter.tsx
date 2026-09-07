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
            Private business email on your own domain — mail, contacts, calendar and shared work on
            one fast surface. Your domain, your data, your keys.
          </p>
          <div className="mt-5 space-y-2">
            <a
              href="mailto:hello@anexomail.com"
              className="flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
            >
              <Mail className="size-4 shrink-0" aria-hidden="true" />
              <span>
                <span className="text-foreground">hello@anexomail.com</span> — support &amp;
                enquiries
              </span>
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
        <div className="ax-container grid gap-8 py-10 md:grid-cols-2">
          <div>
            <h3 className="text-xs font-semibold tracking-wider text-muted-foreground uppercase">
              Account integrity &amp; privacy
            </h3>
            <p className="mt-4 text-xs leading-relaxed text-muted-foreground">
              One person, one account. When you sign in we seal a device record built from five
              coarse signals only — platform, browser, timezone bucket, screen bucket and language.
              It is hashed, stored encrypted and carries a deletion date. We do not use biometric
              fingerprinting, and we do not probe canvas, audio, fonts or graphics hardware.
            </p>
            <p className="mt-3 text-xs leading-relaxed text-muted-foreground">
              This exists for one reason: to stop one device farming many accounts for spam, abuse
              or fraud. You can see and revoke your own devices at any time, and revoking one ends
              its live sessions immediately.
            </p>
          </div>
          <div>
            <h3 className="text-xs font-semibold tracking-wider text-muted-foreground uppercase">
              Fair use &amp; your data on exit
            </h3>
            <ul className="mt-4 space-y-2 text-xs leading-relaxed text-muted-foreground">
              <li>
                A device used to reach 3 or more accounts, or to create 3 or more accounts within 24
                hours, is marked suspicious and reviewed.
              </li>
              <li>
                A confirmed violation receives one written final warning before any account is
                blocked.
              </li>
              <li>
                A repeat violation blocks the account, and a severe pattern adds the device to the
                ban list so it cannot create new accounts.
              </li>
              <li>
                A blocked account keeps full export access for 72 hours. After that window the data
                is permanently deleted, as committed.
              </li>
              <li>
                Your conversations are never sent to any AI or third-party moderation service. File
                safety runs on our own infrastructure.
              </li>
            </ul>
          </div>
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

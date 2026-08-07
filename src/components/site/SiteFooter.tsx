import { Mail } from "lucide-react";

const groups = [
  {
    title: "Product",
    items: ["Business email", "Contacts", "Calendar", "Tasks & notes", "Teams"],
  },
  {
    title: "Plans",
    items: ["Basic", "Pro", "Business", "Compare plans"],
  },
  {
    title: "Company",
    items: ["About", "Status", "Documentation", "Support"],
  },
];

export function SiteFooter() {
  return (
    <footer className="border-t border-border bg-card">
      <div className="ax-container grid gap-10 py-14 md:grid-cols-[1.4fr_repeat(3,1fr)]">
        <div>
          <div className="flex items-center gap-2.5">
            <span className="flex size-9 items-center justify-center rounded-xl bg-primary text-primary-foreground">
              <Mail className="size-4.5" strokeWidth={2.4} />
            </span>
            <span className="text-base font-extrabold tracking-tight">ANEXOMAIL</span>
          </div>
          <p className="mt-4 max-w-xs text-sm leading-relaxed text-muted-foreground">
            Business email workspace for teams that outgrew consumer mail. Your domain,
            your data, your rules.
          </p>
        </div>

        {groups.map((g) => (
          <div key={g.title}>
            <h3 className="text-sm font-semibold text-foreground">{g.title}</h3>
            <ul className="mt-4 space-y-2.5">
              {g.items.map((item) => (
                <li key={item}>
                  <span className="text-sm text-muted-foreground">{item}</span>
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
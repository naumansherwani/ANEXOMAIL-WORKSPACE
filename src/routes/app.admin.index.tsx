import { createFileRoute } from "@tanstack/react-router";
import { Globe } from "lucide-react";

const CHECKS = ["MX", "SPF", "DKIM", "DMARC", "TLS"] as const;

export const Route = createFileRoute("/app/admin/")({
  head: () => ({
    meta: [
      { title: "Domains — ANEXOMAIL Admin" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: DomainsPage,
});

function DomainsPage() {
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-10 md:px-10">
      <p className="ax-eyebrow">Ownership</p>
      <h1 className="mt-3 text-3xl text-foreground">Domains</h1>
      <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
        Every record that decides whether your mail is trusted, checked live and shown
        here. No hidden state, no support ticket to find out.
      </p>

      <div className="ax-plane mt-8 rounded-2xl p-5">
        <span className="flex size-9 items-center justify-center rounded-xl bg-secondary text-steel">
          <Globe className="size-4" />
        </span>
        <h2 className="mt-4 text-base font-bold text-foreground">No domain added yet</h2>
        <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
          Add the domain you already own. We generate the records, then verify them
          continuously — not once at setup.
        </p>

        <ul className="mt-5 grid gap-2 sm:grid-cols-5">
          {CHECKS.map((c) => (
            <li
              key={c}
              className="rounded-xl border border-border bg-secondary px-3 py-2 text-center text-xs font-semibold text-muted-foreground"
            >
              {c}
              <span className="mt-1 block text-[10px] font-medium text-steel">
                Not checked
              </span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
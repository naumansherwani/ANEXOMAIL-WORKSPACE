import { createFileRoute } from "@tanstack/react-router";
import { Sparkles } from "lucide-react";

import { SectionTitle } from "@/components/app/crm/CrmBits";
import { useLocale } from "@/lib/i18n";

export const Route = createFileRoute("/app/crm/ai")({
  head: () => ({
    meta: [
      { title: "CRM AI — ANEXOMAIL" },
      {
        name: "description",
        content:
          "AI customer memory, the autonomous agent and executive briefs live on the AI host — this mail workspace stays recorded truth.",
      },
      { property: "og:title", content: "CRM AI — ANEXOMAIL" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CrmAiPage,
});

const COMING = ["AI customer memory", "Autonomous CRM agent", "Executive relationship brief", "Lifecycle prediction"] as const;

function CrmAiPage() {
  const { t } = useLocale();

  return (
    <div className="mx-auto w-full max-w-6xl px-ax-5 py-ax-6">
      <SectionTitle
        title={t("CRM AI")}
        hint={t("Locked on this host. The mail workspace shows recorded truth only — AI reads it on the AI host.")}
      />

      <div className="ax-plane flex min-h-[14rem] flex-col items-center justify-center gap-3 rounded-2xl p-ax-8 text-center">
        <span className="flex size-11 items-center justify-center rounded-2xl bg-secondary text-steel">
          <Sparkles className="size-5" />
        </span>
        <p className="text-sm font-bold text-foreground">
          {t("CRM AI runs on ai.anexomail.com")}
        </p>
        <p className="ax-caption max-w-md text-muted-foreground">
          {t("Memory, the autonomous agent and briefs are being wired on the AI host. Nothing here guesses — this book stays evidence.")}
        </p>
        <div className="mt-2 flex flex-wrap justify-center gap-1.5">
          {COMING.map((label) => (
            <span
              key={label}
              className="rounded-full border border-border px-2.5 py-1 text-[11px] font-semibold text-muted-foreground"
            >
              {t(label)}
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}

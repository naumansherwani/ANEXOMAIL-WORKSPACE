import { Building2, Loader2, UserRound } from "lucide-react";

import { Button } from "@/components/ui/button";
import { useLocale } from "@/lib/i18n";
import { cn } from "@/lib/utils";

/**
 * Create your account for workspace — Personal | Business.
 * Polar SKU yahan nahi. Kind session/backend pe save hoti hai.
 */
export function WorkspaceKindCards({
  busy,
  onPersonal,
  onBusiness,
}: {
  busy?: boolean;
  onPersonal: () => void;
  onBusiness: () => void;
}) {
  const { t } = useLocale();

  return (
    <div className="space-y-5">
      <div className="text-center">
        <p className="ax-eyebrow">{t("Create your account for workspace")}</p>
        <h1 className="ax-heading mt-2 text-foreground">{t("Choose how you'll use ANEXOMAIL")}</h1>
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        <KindCard
          disabled={busy}
          icon={UserRound}
          title={t("Personal")}
          body={t("For your personal life, communication and work.")}
          features={t("Mail · Chat · Calendar")}
          onContinue={onPersonal}
          continueLabel={t("Continue")}
        />
        <KindCard
          disabled={busy}
          icon={Building2}
          title={t("Business")}
          body={t("For teams, companies and growing businesses.")}
          features={t("Mail · CRM · Teams · Shared Workspace")}
          onContinue={onBusiness}
          continueLabel={t("Continue")}
        />
      </div>

      {busy ? (
        <p className="ax-caption flex items-center justify-center gap-2 text-muted-foreground">
          <Loader2 className="size-4 animate-spin" />
          {t("Opening the next step…")}
        </p>
      ) : null}
    </div>
  );
}

function KindCard({
  icon: Icon,
  title,
  body,
  features,
  onContinue,
  continueLabel,
  disabled,
}: {
  icon: typeof UserRound;
  title: string;
  body: string;
  features: string;
  onContinue: () => void;
  continueLabel: string;
  disabled?: boolean;
}) {
  return (
    <div
      className={cn(
        "flex flex-col rounded-2xl border border-border bg-background p-4 text-left shadow-sm",
        "transition-colors hover:border-cyan-accent/40",
      )}
    >
      <span className="flex items-center gap-2 text-[13px] font-bold uppercase tracking-[0.14em] text-foreground">
        <Icon className="size-4 text-cyan-accent" />
        {title}
      </span>
      <p className="ax-caption mt-3 min-h-[2.6rem] text-muted-foreground">{body}</p>
      <p className="mt-3 text-[11px] font-semibold text-foreground">{features}</p>
      <Button
        type="button"
        className="ax-press mt-4 w-full"
        disabled={disabled}
        onClick={onContinue}
      >
        {continueLabel}
      </Button>
    </div>
  );
}

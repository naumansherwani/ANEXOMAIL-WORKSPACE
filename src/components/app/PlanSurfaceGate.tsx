import { Link, useRouterState } from "@tanstack/react-router";
import { useState, type ReactNode } from "react";

import { StateBlock } from "@/components/state/StateBlock";
import { useAuth } from "@/lib/auth";
import { founderSurfaceAllowed, isAiHost, isPublicMailHost } from "@/lib/host";
import { useLocale } from "@/lib/i18n";
import { surfaceDenial, surfaceFromSession } from "@/lib/plan-surface";

/**
 * Honest package wall — never a blank pane.
 * Rail and header stay; the main surface names the package that owns the path.
 */
export function PlanSurfaceGate({ children }: { children: ReactNode }) {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const { session, organisation } = useAuth();
  const { t } = useLocale();
  const [hosts] = useState(() => ({
    publicMailHost: isPublicMailHost(),
    aiHost: isAiHost(),
    founderHost: founderSurfaceAllowed(),
  }));

  const { billed, kind, copyName } = surfaceFromSession(session?.user, organisation?.slug);
  const denial = surfaceDenial(pathname, {
    plan: billed,
    kind,
    founder: Boolean(session?.user.is_founder),
    ...hosts,
  });

  if (!denial) return children;

  return (
    <StateBlock
      title={t(denial.title)}
      body={t(denial.body).replaceAll("{package}", t(copyName))}
      action={
        <Link
          to="/app"
          className="ax-focus inline-flex rounded-lg border border-border bg-secondary px-3 py-1.5 text-xs font-semibold text-foreground"
        >
          {t("Back to dashboard")}
        </Link>
      }
    />
  );
}

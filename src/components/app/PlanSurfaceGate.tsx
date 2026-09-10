import { Link, useRouterState } from "@tanstack/react-router";
import { useState, type ReactNode } from "react";

import { StateBlock } from "@/components/state/StateBlock";
import { useAuth } from "@/lib/auth";
import { founderSurfaceAllowed, isAiHost, isPublicMailHost } from "@/lib/host";
import { platformPlan, surfaceDenial, type WorkspacePlanId } from "@/lib/plan-surface";

/**
 * Honest package wall — never a blank pane.
 * Rail and header stay; the main surface names the package that owns the path.
 */
export function PlanSurfaceGate({ children }: { children: ReactNode }) {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const { session } = useAuth();
  const [hosts] = useState(() => ({
    publicMailHost: isPublicMailHost(),
    aiHost: isAiHost(),
    founderHost: founderSurfaceAllowed(),
  }));

  const plan: WorkspacePlanId = platformPlan(session?.user.workspace_plan, session?.user.ai_plan);
  const denial = surfaceDenial(pathname, {
    plan,
    founder: Boolean(session?.user.is_founder),
    ...hosts,
  });

  if (!denial) return children;

  return (
    <StateBlock
      title={denial.title}
      body={denial.body}
      action={
        <Link
          to="/app"
          className="ax-focus inline-flex rounded-lg border border-border bg-secondary px-3 py-1.5 text-xs font-semibold text-foreground"
        >
          Back to dashboard
        </Link>
      }
    />
  );
}

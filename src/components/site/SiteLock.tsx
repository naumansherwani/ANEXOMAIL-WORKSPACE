import { useEffect, useState, type ReactNode } from "react";

import { aiPublicPathAllowed, isAiHost } from "@/lib/host";
import { resolveSiteAccess, siteLockEnabled } from "@/lib/site-lock";

/**
 * PRE-LAUNCH LOCK gate. Awam ko sirf ek saaf "not open yet" screen milti hai —
 * koi route, koi page, koi founder surface nahi. Founder key wale device par
 * poori site normal chalti hai.
 *
 * PARALLEL AI BUILD LOCK: ai.anexomail.com par awam ko `/` (AI landing +
 * coming soon + package list) milta hai; baqi sab paths lock ke peeche rehte
 * hain (mirror /app/* sirf unlock key se).
 */
export function SiteLock({ children }: { children: ReactNode }) {
  const locked = siteLockEnabled();
  const [allowed, setAllowed] = useState<boolean | null>(locked ? null : true);

  useEffect(() => {
    if (!locked) return;
    setAllowed(resolveSiteAccess());
  }, [locked]);

  if (allowed === null) {
    return <div className="min-h-screen bg-background" aria-hidden />;
  }

  if (allowed) return <>{children}</>;

  // AI host: awam ko sirf AI landing dikhao, baqi sab gated.
  if (
    typeof window !== "undefined" &&
    isAiHost() &&
    aiPublicPathAllowed(window.location.pathname)
  ) {
    return <>{children}</>;
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-6">
      <div className="ax-in max-w-md text-center">
        <p className="ax-eyebrow">ANEXOMAIL Workspace</p>
        <h1 className="mt-5 text-3xl font-extrabold tracking-tight text-foreground md:text-4xl">
          Not open yet
        </h1>
        <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
          The workspace is in private build. Public access opens when it is ready —
          there is nothing to sign up for here today.
        </p>
        <p className="mt-6 text-xs text-muted-foreground">
          Already invited? Open the link you were given, on this device.
        </p>
      </div>
    </main>
  );
}

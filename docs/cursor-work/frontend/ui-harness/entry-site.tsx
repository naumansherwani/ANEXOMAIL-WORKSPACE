// Public-site harness: mounts the REAL route components (landing, plans, get-started, onboarding)
// inside a plain document. Hash: #home | #plans | #getstarted | #onboarding | #auth | #migration  (+ #signed for a logged-in visitor).
import { createRoot } from "react-dom/client";

import { Route as AuthRoute } from "@/routes/auth";
import { Route as HomeRoute } from "@/routes/index";
import { Route as GetStartedRoute } from "@/routes/get-started";
import { Route as OnboardingRoute } from "@/routes/onboarding";
import { Route as PlansRoute } from "@/routes/plans";
import { Route as MigrationRoute } from "@/routes/migration";

type R = { component: () => JSX.Element };
const pick = (h: string): R => {
  if (h.includes("migration")) return MigrationRoute as unknown as R;
  if (h.includes("auth")) return AuthRoute as unknown as R;
  if (h.includes("plans")) return PlansRoute as unknown as R;
  if (h.includes("getstarted")) return GetStartedRoute as unknown as R;
  if (h.includes("onboarding")) return OnboardingRoute as unknown as R;
  return HomeRoute as unknown as R;
};

function App() {
  const Page = pick(location.hash).component;
  return (
    <div className="min-h-dvh bg-background text-foreground">
      <Page />
    </div>
  );
}
createRoot(document.getElementById("root")!).render(<App />);

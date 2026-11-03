import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — `founderworkspace.anexomail.com/founder` seedha
 * founder deck kholta hai. Asli surface `/app/founder` hai.
 */
export const Route = createFileRoute("/founder")({
  beforeLoad: () => {
    throw redirect({ to: "/app/founder" });
  },
});

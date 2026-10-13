import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — founderworkspace.anexomail.com/settings
 * Sirf ek chhota pata; asli surface /app/settings hi rehta hai.
 */
export const Route = createFileRoute("/settings")({
  beforeLoad: () => {
    throw redirect({ to: "/app/settings" });
  },
});

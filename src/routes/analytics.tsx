import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — founderworkspace.anexomail.com/analytics
 * Sirf ek chhota pata; asli surface /app/analytics hi rehta hai.
 */
export const Route = createFileRoute("/analytics")({
  beforeLoad: () => {
    throw redirect({ to: "/app/analytics" });
  },
});

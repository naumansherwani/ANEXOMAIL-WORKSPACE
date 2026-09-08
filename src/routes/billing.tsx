import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — founderworkspace.anexomail.com/billing
 * Sirf ek chhota pata; asli surface /app/billing hi rehta hai.
 */
export const Route = createFileRoute("/billing")({
  beforeLoad: () => {
    throw redirect({ to: "/app/billing" });
  },
});

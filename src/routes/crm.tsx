import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — founderworkspace.anexomail.com/crm
 * Sirf ek chhota pata; asli surface /app/crm hi rehta hai.
 */
export const Route = createFileRoute("/crm")({
  beforeLoad: () => {
    throw redirect({ to: "/app/crm" });
  },
});

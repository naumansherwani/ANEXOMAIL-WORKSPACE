import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — founderworkspace.anexomail.com/mail
 * Sirf ek chhota pata; asli surface /app/mail hi rehta hai.
 */
export const Route = createFileRoute("/mail")({
  beforeLoad: () => {
    throw redirect({ to: "/app/mail" });
  },
});

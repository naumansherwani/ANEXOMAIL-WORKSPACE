import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — founderworkspace.anexomail.com/storage
 * Sirf ek chhota pata; asli surface /app/storage hi rehta hai.
 */
export const Route = createFileRoute("/storage")({
  beforeLoad: () => {
    throw redirect({ to: "/app/storage" });
  },
});

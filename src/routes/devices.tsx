import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Founder short path — founderworkspace.anexomail.com/devices
 * Sirf ek chhota pata; asli surface /app/devices hi rehta hai.
 */
export const Route = createFileRoute("/devices")({
  beforeLoad: () => {
    throw redirect({ to: "/app/devices" });
  },
});

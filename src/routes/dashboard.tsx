import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Awam short path — anexomail.com/dashboard
 * Asli surface /app (workspace home). /mail /people /calendar pehle se yahi pattern.
 */
export const Route = createFileRoute("/dashboard")({
  beforeLoad: () => {
    throw redirect({ to: "/app" });
  },
});

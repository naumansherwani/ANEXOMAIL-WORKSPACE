import { createFileRoute } from "@tanstack/react-router";

// Lightweight liveness probe for PM2/Caddy health checks (`curl :3000/health`).
export const Route = createFileRoute("/health")({
  server: {
    handlers: {
      GET: async () =>
        new Response(JSON.stringify({ ok: true, service: "anexomail-web" }), {
          status: 200,
          headers: { "content-type": "application/json" },
        }),
    },
  },
});

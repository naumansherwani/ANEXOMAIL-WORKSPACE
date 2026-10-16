import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * Addresses ab ek hi asli jagah hain: `/app/domains` (blueprint #8) — Rust
 * `mail.addresses.*`. Yahan pehle ek static khali page tha jo jhoota "No addresses
 * yet" bolta tha; ab seedha asli screen par bhej dete hain.
 */
export const Route = createFileRoute("/app/admin/addresses")({
  head: () => ({
    meta: [{ title: "Addresses — ANEXOMAIL" }, { name: "robots", content: "noindex" }],
  }),
  beforeLoad: () => {
    throw redirect({ to: "/app/domains" });
  },
});

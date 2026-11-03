import { createFileRoute } from "@tanstack/react-router";

import { AuthPage } from "./auth";

/**
 * FOUNDER LOGIN — founderworkspace.anexomail.com/founderlogin (founder 28 Oct 2026).
 * Wohi maujooda sign-in page (passkey, recovery code, email link — Rule 68), sirf founder ke liye. Login ke baad seedha Command Center (/f/).
 * Awam hosts par yeh route kuch nahi dikhata (home par bhej deta hai). Founder host par awam extras (signup, Save/Forgot password) chhupe hain.
 */
export const Route = createFileRoute("/founderlogin")({
  ssr: false,
  head: () => ({
    meta: [{ title: "Founder sign in — ANEXOMAIL" }, { name: "robots", content: "noindex" }],
  }),
  component: () => <AuthPage founderLogin />,
});

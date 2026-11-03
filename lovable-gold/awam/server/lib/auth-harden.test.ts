import { expect, test } from "bun:test";
import { createClient } from "@supabase/supabase-js";

import { forgetAuthToken, hardenSupabaseAuth, isTransientAuthError } from "./auth-harden";

// Asli GoTrueClient.getUser ki jagah script, phir harden — network nahi lagta.
const probe: any = createClient("https://placeholder.supabase.co", "placeholder", { auth: { persistSession: false } });
const proto: any = Object.getPrototypeOf(probe.auth);
let calls = 0;
let script: (n: number) => any = () => ({ data: { user: { id: "u" } }, error: null });
proto.getUser = async function () {
  calls += 1;
  return script(calls);
};
hardenSupabaseAuth();

test("15 parallel calls = 1 upstream call, cached, forget works", async () => {
  calls = 0;
  const r = await Promise.all(Array.from({ length: 15 }, () => probe.auth.getUser("tok1")));
  expect(r.every((x: any) => x.data.user.id === "u")).toBe(true);
  expect(calls).toBe(1);
  await probe.auth.getUser("tok1");
  expect(calls).toBe(1);
  forgetAuthToken("tok1");
  await probe.auth.getUser("tok1");
  expect(calls).toBe(2);
});

test("temporary error retried then succeeds", async () => {
  calls = 0;
  script = (n) => (n < 3 ? { data: { user: null }, error: { status: 429, message: "rate" } } : { data: { user: { id: "u2" } }, error: null });
  const r = await probe.auth.getUser("tok2");
  expect(r.data.user.id).toBe("u2");
  expect(calls).toBe(3);
});

test("invalid token: no retry, not cached", async () => {
  calls = 0;
  script = () => ({ data: { user: null }, error: { status: 401, message: "invalid JWT" } });
  const r = await probe.auth.getUser("bad");
  expect(r.error.status).toBe(401);
  expect(calls).toBe(1);
  await probe.auth.getUser("bad");
  expect(calls).toBe(2);
  expect(isTransientAuthError({ status: 401 })).toBe(false);
  expect(isTransientAuthError({ status: 503 })).toBe(true);
});

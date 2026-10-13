/**
 * ANEXOMAIL — Supabase admin client (service role).
 *
 * Har route file yahan se import karta hai:
 *   import { admin as supa } from "../lib/supa";
 *
 * Service role key = server-only. Kabhi client/browser pe nahi jata.
 * auth.ts apna alag client banata hai (SUPABASE4_* vars) — woh pehle se theek hai.
 */
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const URL =
  process.env.SUPABASE4_URL ||
  process.env.SUPABASE_URL ||
  "";

const KEY =
  process.env.SUPABASE4_SERVICE_ROLE_KEY ||
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  "";

function make(): SupabaseClient {
  if (!URL || !KEY) {
    // Server cold-start pe env missing hoti hai koi dafa — log karo lekin crash mat karo.
    console.warn("[supa] WARNING: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing in env.");
  }
  return createClient(URL || "https://placeholder.supabase.co", KEY || "placeholder", {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Singleton admin client — service role, server-only. */
export const admin: SupabaseClient = make();

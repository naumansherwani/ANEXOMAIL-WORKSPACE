/**
 * G35 — passkey lazmi (password + passkey dono). Ek hi jagah: status, enrol, recovery codes.
 * Server: server/routes/auth-passkey.ts · SQL: docs/cursor-work/sql/E43_passkey_recovery_codes.sql
 */
import { useQuery } from "@tanstack/react-query";

import { api, storeRefresh } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

export type PasskeyStatus = {
  /** E43 SQL abhi server par nahi chala — gate nahi lagta */
  unknown?: boolean;
  count: number;
  target: number;
  codes_remaining: number;
  /** passkey abhi nahi hai */
  required: boolean;
  /** bypass nahi: naya account, ya grace khatam */
  hard: boolean;
  grace_until?: string | null;
};

export const PASSKEY_STATUS_KEY = ["auth", "passkey-status"] as const;

export function usePasskeyStatus(enabled = true) {
  return useQuery<PasskeyStatus>({
    queryKey: PASSKEY_STATUS_KEY,
    enabled,
    staleTime: 60_000,
    retry: false,
    queryFn: () => rpcOrRest<PasskeyStatus>("auth.passkey.status", { path: "/api/auth/passkey/status", method: "GET" }, {}),
  });
}

/** "Chrome on Windows" jaisa chhota naam — device list mein pehchan ke liye */
export function deviceLabel(): string {
  if (typeof navigator === "undefined") return "This device";
  const ua = navigator.userAgent;
  const os = /iPhone|iPad/.test(ua)
    ? "iPhone/iPad"
    : /Android/.test(ua)
      ? "Android"
      : /Mac OS X/.test(ua)
        ? "Mac"
        : /Windows/.test(ua)
          ? "Windows"
          : /Linux/.test(ua)
            ? "Linux"
            : "device";
  const browser = /Edg\//.test(ua)
    ? "Edge"
    : /Firefox\//.test(ua)
      ? "Firefox"
      : /Chrome\//.test(ua)
        ? "Chrome"
        : /Safari\//.test(ua)
          ? "Safari"
          : "Browser";
  return `${browser} on ${os}`;
}

export function passkeySupported(): boolean {
  return typeof window !== "undefined" && "credentials" in navigator && Boolean(window.PublicKeyCredential);
}

export type EnrolResult = { passkey_count: number; recovery_codes: string[] | null; token?: string };

/** WebAuthn create: server challenge → browser → server verify. Pehla passkey 10 recovery codes bhi deta hai (sirf ek baar). */
export async function enrolPasskey(label?: string): Promise<EnrolResult> {
  if (!passkeySupported()) throw new Error("This browser can't create passkeys. Use a phone or laptop with Face ID, Touch ID, fingerprint or Windows Hello.");
  const options = await rpcOrRest<{ publicKey: PublicKeyCredentialCreationOptionsJSON }>(
    "auth.passkey.register.options",
    { path: "/api/auth/passkey/register/options", method: "POST", body: {} },
    {},
  );
  const credential = await navigator.credentials.create({
    publicKey: PublicKeyCredential.parseCreationOptionsFromJSON(options.publicKey),
  });
  if (!credential) throw new Error("Passkey creation was cancelled.");
  const payload = { ...(credential as PublicKeyCredential).toJSON(), label: label || deviceLabel() };
  const res = await rpcOrRest<{ token?: string; passkey_count?: number; recovery_codes?: string[] | null }>(
    "auth.passkey.register.verify",
    { path: "/api/auth/passkey/register/verify", method: "POST", body: payload },
    payload,
  );
  return {
    passkey_count: res.passkey_count ?? 1,
    recovery_codes: res.recovery_codes ?? null,
    token: res.token,
  };
}

export async function regenerateRecoveryCodes(): Promise<string[]> {
  const res = await rpcOrRest<{ codes: string[] }>(
    "auth.recovery.generate",
    { path: "/api/auth/recovery-codes/generate", method: "POST", body: {} },
    {},
  );
  return res.codes;
}

/** Login jawab: Rust sirf token+refresh deta hai (profile Brain /api/auth/session se); Bun poora Session bhi deta hai. */
export type LoginResult = {
  token: string;
  refresh_token?: string;
  expires_at?: number;
  needs_session?: boolean;
  codes_left?: number;
  must_add_passkey?: boolean;
};

function keepRefresh<T extends LoginResult>(r: T): T {
  storeRefresh(r.refresh_token, r.expires_at);
  return r;
}

/** Passkey login, step 1 (challenge). Rust PRIMARY, Bun fallback (404/501/502/503). */
export async function passkeyLoginOptions(email: string): Promise<{ publicKey: PublicKeyCredentialRequestOptionsJSON }> {
  return rpcOrRest(
    "auth.passkey.options",
    { path: "/api/auth/passkey/options", method: "POST", body: { email } },
    { email },
  );
}

/** Passkey login, step 2 (assertion -> real session). */
export async function passkeyLoginVerify(credentialJson: unknown): Promise<LoginResult> {
  return keepRefresh(
    await rpcOrRest<LoginResult>(
      "auth.passkey.verify",
      { path: "/api/auth/passkey/verify", method: "POST", body: credentialJson },
      credentialJson,
    ),
  );
}

/** Recovery-code login (passkey/phone lost). */
export async function recoveryCodeLogin(email: string, code: string): Promise<LoginResult> {
  return keepRefresh(
    await rpcOrRest<LoginResult>(
      "auth.recovery.redeem",
      { path: "/api/auth/recovery-codes/redeem", method: "POST", body: { email, code } },
      { email, code },
    ),
  );
}

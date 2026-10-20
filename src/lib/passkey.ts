/**
 * G35 — passkey lazmi (password + passkey dono). Ek hi jagah: status, enrol, recovery codes.
 * Server: server/routes/auth-passkey.ts · SQL: docs/cursor-work/sql/E43_passkey_recovery_codes.sql
 */
import { useQuery } from "@tanstack/react-query";

import { api } from "@/lib/api";

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
    queryFn: () => api<PasskeyStatus>("/api/auth/passkey/status"),
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
  const options = await api<{ publicKey: PublicKeyCredentialCreationOptionsJSON }>(
    "/api/auth/passkey/register/options",
    { method: "POST", body: "{}" },
  );
  const credential = await navigator.credentials.create({
    publicKey: PublicKeyCredential.parseCreationOptionsFromJSON(options.publicKey),
  });
  if (!credential) throw new Error("Passkey creation was cancelled.");
  const res = await api<{ token?: string; passkey_count?: number; recovery_codes?: string[] | null }>(
    "/api/auth/passkey/register/verify",
    {
      method: "POST",
      body: JSON.stringify({ ...(credential as PublicKeyCredential).toJSON(), label: label || deviceLabel() }),
    },
  );
  return {
    passkey_count: res.passkey_count ?? 1,
    recovery_codes: res.recovery_codes ?? null,
    token: res.token,
  };
}

export async function regenerateRecoveryCodes(): Promise<string[]> {
  const res = await api<{ codes: string[] }>("/api/auth/recovery-codes/generate", { method: "POST", body: "{}" });
  return res.codes;
}

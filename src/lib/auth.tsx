import { useQuery, useQueryClient } from "@tanstack/react-query";
import { createContext, useCallback, useContext, useMemo, type ReactNode } from "react";

import { api, ApiError, sessionToken } from "@/lib/api";

/**
 * Session state — Phase 5A.
 * Single identity chain: Supabase -> Backend -> Frontend.
 * The frontend never mints, validates or stores identity itself; it asks
 * `GET /api/auth/session` and renders whatever the backend says.
 */

export type Organisation = {
  id: string;
  name: string;
  slug: string;
  domain: string | null;
  role: "owner" | "admin" | "member";
};

export type SessionUser = {
  id: string;
  email: string;
  name: string | null;
  mfa_enabled: boolean;
  onboarded: boolean;
};

export type Session = {
  user: SessionUser;
  organisations: Organisation[];
  active_organisation_id: string | null;
};

type AuthValue = {
  session: Session | null;
  organisation: Organisation | null;
  status: "loading" | "signed-in" | "signed-out" | "unavailable";
  /** Backend not wired yet — shown as a TODO surface, never faked. */
  unavailableReason: string | null;
  refresh: () => Promise<void>;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient();

  const query = useQuery<Session | null, ApiError>({
    queryKey: ["auth", "session"],
    queryFn: async () => {
      if (!sessionToken.get()) return null;
      try {
        return await api<Session>("/api/auth/session");
      } catch (error) {
        if (error instanceof ApiError && error.status === 401) {
          sessionToken.clear();
          return null;
        }
        throw error;
      }
    },
    retry: false,
    staleTime: 30_000,
  });

  const refresh = useCallback(async () => {
    await queryClient.invalidateQueries({ queryKey: ["auth"] });
  }, [queryClient]);

  const signOut = useCallback(async () => {
    try {
      await api("/api/auth/logout", { method: "POST" });
    } catch {
      // Token is being dropped locally regardless; the backend revokes on its side.
    }
    sessionToken.clear();
    await queryClient.cancelQueries();
    queryClient.clear();
  }, [queryClient]);

  const value = useMemo<AuthValue>(() => {
    const session = query.data ?? null;
    const status: AuthValue["status"] = query.isLoading
      ? "loading"
      : query.error
        ? "unavailable"
        : session
          ? "signed-in"
          : "signed-out";

    const organisation =
      session?.organisations.find((o) => o.id === session.active_organisation_id) ??
      session?.organisations[0] ??
      null;

    return {
      session,
      organisation,
      status,
      unavailableReason: query.error ? query.error.message : null,
      refresh,
      signOut,
    };
  }, [query.data, query.error, query.isLoading, refresh, signOut]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside <AuthProvider>.");
  return ctx;
}
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

import { api, ApiError, ensureFreshToken, sessionToken } from "@/lib/api";
import { visitorPreviewFromUrl } from "@/lib/visitor-preview";
import { clearOffline } from "@/lib/offline";

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
  display_name?: string | null;
  avatar_url?: string | null;
  mfa_enabled: boolean;
  onboarded: boolean;
  /** Authority `public.founder_accounts` (Brain). Founder par awam ka claim/onboarding kabhi nahi. */
  is_founder?: boolean;
  /**
   * The user's ANEXOMAIL identity, e.g. "nauman@anexomail.com". Every account
   * must own one before the workspace opens — social sign-in only proves who
   * you are, it does not give you a mailbox. `null` = not claimed yet.
   */
      anexomail_address?: string | null;
  workspace_plan?: string | null;
  /** E20 (13 Oct 2026): true sirf jab koi REAL plan mila (family ya trial_subscribe se) — false = abhi tak kuch select/pay nahi hua. */
  has_chosen_plan?: boolean | null;
  ai_plan?: string | null;
  /** Personal | Business — Polar SKU nahi. Session/backend. */
  account_kind?: "personal" | "business" | null;
  /** SQL E2 personal_polar_map — sirf kind=personal. Business null. */
  personal_plan_name?: string | null;
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
  acceptSession: (session: Session) => void;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthValue | null>(null);

// Aakhri tasdeeq-shuda session (sirf offline ke liye). Token pehle se isi browser mein hota hai; sign out / 401 par saaf.
const LAST_SESSION = "anexo.session.last";
const lastSession = {
  save(s: Session) {
    try {
      localStorage.setItem(LAST_SESSION, JSON.stringify(s));
    } catch {
      /* storage band — offline session nahi, bas */
    }
  },
  load(): Session | null {
    try {
      const raw = localStorage.getItem(LAST_SESSION);
      return raw ? (JSON.parse(raw) as Session) : null;
    } catch {
      return null;
    }
  },
  clear() {
    try {
      localStorage.removeItem(LAST_SESSION);
    } catch {
      /* theek */
    }
  },
};

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient();
  // VISITOR PREVIEW: render layer par session ko ignore karte hain — logout nahi.
  const [visitor, setVisitor] = useState(false);
  useEffect(() => {
    setVisitor(visitorPreviewFromUrl());
  }, []);

  const query = useQuery<Session | null, ApiError>({
    queryKey: ["auth", "session"],
    queryFn: async () => {
      const tokenAtStart = sessionToken.get();
      if (!tokenAtStart) return null;
      // Login-loop fix (21 Oct 2026): server/network ka temporary masla (0 / 429 / 5xx) sign-out NAHI hai —
      // 3 baar retry (backoff). Naye login ke 30 s ke andar pehla 401 bhi ek dafa dobara verify hota hai.
      const JUST = "anexo.login.at";
      const recentLogin = () => {
        try {
          return Date.now() - Number(sessionStorage.getItem(JUST) || 0) < 30_000;
        } catch {
          return false;
        }
      };
      try {
        let s: Session | null = null;
        for (let attempt = 0; attempt < 4; attempt++) {
          try {
            s = await api<Session>("/api/auth/session");
            break;
          } catch (e) {
            const st = e instanceof ApiError ? e.status : -1;
            const transient = st === 0 || st === 429 || st >= 500;
            const freshLogin401 = st === 401 && recentLogin() && attempt < 2;
            if ((transient && attempt < 3) || freshLogin401) {
              await new Promise((r) => setTimeout(r, 400 * (attempt + 1)));
              continue;
            }
            throw e;
          }
        }
        if (!s) throw new ApiError("Session check failed.", 503, "session_retry_exhausted");
        lastSession.save(s);
        return s;
      } catch (error) {
        if (error instanceof ApiError && error.status === 401) {
          // A fresh sign-in happened while this (old-token) check was in flight: its 401 is about the OLD token.
          // Never wipe the new token / session because of it — that was the dashboard -> sign-in -> dashboard bounce.
          if (sessionToken.get() !== tokenAtStart) return queryClient.getQueryData<Session>(["auth", "session"]) ?? null;
          sessionToken.clear();
          lastSession.clear();
          return null;
        }
        // Internet nahi (offline / server tak raasta nahi): pichla session — taake mobile par offline bhi cached mail
        // khule (Gmail jaisa). Server ka asli jawab aate hi yeh khud badal jata hai; 401 par sab saaf.
        if (error instanceof ApiError && error.status === 0) {
          const cached = lastSession.load();
          if (cached) return cached;
        }
        throw error;
      }
    },
    retry: false,
    staleTime: 30_000,
  });

  // Access token (1 ghanta) khatam hone se pehle chupke se naya: har minute jaanch + tab wapas aane / internet wapas aane par.
  const hasSession = Boolean(query.data);
  useEffect(() => {
    if (!hasSession || typeof window === "undefined") return;
    const tick = () => void ensureFreshToken();
    tick();
    const iv = window.setInterval(tick, 60_000);
    const onVis = () => document.visibilityState === "visible" && tick();
    document.addEventListener("visibilitychange", onVis);
    window.addEventListener("online", tick);
    return () => {
      window.clearInterval(iv);
      document.removeEventListener("visibilitychange", onVis);
      window.removeEventListener("online", tick);
    };
  }, [hasSession]);

  const refresh = useCallback(async () => {
    await queryClient.invalidateQueries({ queryKey: ["auth"] });
  }, [queryClient]);

  const acceptSession = useCallback(
    (session: Session) => {
      // drop any older in-flight session check (old token) so its late answer can't overwrite this one
      void queryClient.cancelQueries({ queryKey: ["auth", "session"] });
      queryClient.setQueryData(["auth", "session"], session);
    },
    [queryClient],
  );

  const signOut = useCallback(async () => {
    try {
      await api("/api/auth/logout", { method: "POST" });
    } catch {
      // Token is being dropped locally regardless; the backend revokes on its side.
    }
    sessionToken.clear();
    lastSession.clear();
    // Sign out = is browser par is user ki offline mail/drafts bhi khatam (shared computer par agla shakhs na dekhe).
    await clearOffline().catch(() => {});
    await queryClient.cancelQueries();
    queryClient.clear();
  }, [queryClient]);

  const value = useMemo<AuthValue>(() => {
    if (visitor) {
      return {
        session: null,
        organisation: null,
        status: "signed-out",
        unavailableReason: null,
        refresh,
        acceptSession,
        signOut,
      };
    }
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
      acceptSession,
      signOut,
    };
  }, [acceptSession, query.data, query.error, query.isLoading, refresh, signOut, visitor]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside <AuthProvider>.");
  return ctx;
}

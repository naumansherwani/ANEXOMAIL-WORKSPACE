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

import { api, ApiError, sessionToken } from "@/lib/api";
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
      if (!sessionToken.get()) return null;
      try {
        const s = await api<Session>("/api/auth/session");
        lastSession.save(s);
        return s;
      } catch (error) {
        if (error instanceof ApiError && error.status === 401) {
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

  const refresh = useCallback(async () => {
    await queryClient.invalidateQueries({ queryKey: ["auth"] });
  }, [queryClient]);

  const acceptSession = useCallback(
    (session: Session) => queryClient.setQueryData(["auth", "session"], session),
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

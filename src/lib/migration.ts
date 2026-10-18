/**
 * Bring your old mail: copy a mailbox from another provider (IMAP + App Password) into ANEXOMAIL.
 *
 * Rust is the ONLY engine for this (`migration.*` procs, mig_glue.rs) — there is no old Bun route, so there is no
 * fallback: if the engine does not know the procedure or the SQL (E35) is not applied, the page says so plainly.
 *
 * The App Password goes to the engine in one request and is never kept here: the form clears it as soon as the request
 * is sent, and it is never put in the query cache, in storage or in a URL.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpc } from "@/lib/rpc";
import { activeSession, type MigProvider, type MigSession, type MigVerify } from "@/lib/migration-report";

export {
  activeSession,
  describeSession,
  describeVerify,
  formatBytes,
  isOpen,
  phaseOf,
  progressPct,
  shortHash,
  skippedFolderLine,
  stopReason,
} from "@/lib/migration-report";
export type { MigProvider, MigSession, MigVerify, Phase, Tone } from "@/lib/migration-report";

export type StartInput = {
  org_id?: string;
  mailbox: string;
  provider: string;
  /** only for the "another IMAP server" provider */
  host?: string;
  login: string;
  password: string;
  include_trash_spam: boolean;
};

export type StartResult = { session_id: string; status: "verified" | "created"; connecting?: boolean };

/** The engine does not know this feature (old build) or the database part is not applied. */
export function isNotSwitchedOn(e: ApiError | null | undefined): boolean {
  if (!e) return false;
  return e.code === "procedure_not_in_rust" || e.code === "migration_sql_missing" || e.status === 404 || e.status === 501;
}

const KEY = ["migration"] as const;

export function useProviders() {
  return useQuery<{ providers: MigProvider[] }, ApiError>({
    queryKey: [...KEY, "providers"],
    queryFn: () => rpc("migration.providers", {}),
    retry: false,
    staleTime: 10 * 60_000,
  });
}

/** The organisation's copies, newest first. Polls every 3 s while one is open, stays quiet otherwise. */
export function useMigrations(orgId: string | undefined) {
  return useQuery<{ sessions: MigSession[]; max_workers?: number }, ApiError>({
    queryKey: [...KEY, "list", orgId],
    queryFn: () => rpc("migration.list", { org_id: orgId }),
    enabled: Boolean(orgId),
    retry: false,
    refetchInterval: (q) => (activeSession(q.state.data?.sessions) ? 3000 : false),
  });
}

export function useMigrationMutations(orgId: string | undefined) {
  const qc = useQueryClient();
  const refresh = () => qc.invalidateQueries({ queryKey: [...KEY, "list"] });
  return {
    start: useMutation<StartResult, ApiError, StartInput>({
      mutationFn: (input) => rpc<StartResult>("migration.start", { ...input, org_id: orgId }),
      onSettled: refresh,
    }),
    resume: useMutation<StartResult, ApiError, { session_id: string; password: string }>({
      mutationFn: (input) => rpc<StartResult>("migration.resume", { ...input, org_id: orgId }),
      onSettled: refresh,
    }),
    cancel: useMutation<{ requested: boolean; already: boolean; status: string; seal_hash: string }, ApiError, string>({
      mutationFn: (session_id) => rpc("migration.cancel", { session_id, org_id: orgId }),
      onSettled: refresh,
    }),
    verify: useMutation<MigVerify, ApiError, string>({
      mutationFn: (session_id) => rpc<MigVerify>("migration.verify", { session_id, org_id: orgId }),
    }),
  };
}

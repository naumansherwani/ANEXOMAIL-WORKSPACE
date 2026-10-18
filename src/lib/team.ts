/**
 * Team: members, invitations, teams, joining by invitation link.
 *
 * Rust is PRIMARY (`team.*` procs, team_glue.rs). The old Bun REST routes are the fallback only — used when the Rust
 * engine does not know the procedure yet (404 `procedure_not_in_rust`), is down (502/503/0) or the SQL is not applied (501).
 * A real answer from Rust (403 not allowed, 404 member_not_found, 409, 410 …) is NEVER retried on the old route.
 *
 * Truth rule (same as calendar invitations): what the person is told comes from the engine's own report
 * (`invited` / `failed`), never from "the request returned 200".
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { ApiError, api } from "@/lib/api";
import { rpc } from "@/lib/rpc";
import type { InviteResult, SeatState, TeamRole, WorkMail } from "@/lib/team-report";

export { describeSeats, describeWorkMail, summariseInvites } from "@/lib/team-report";
export type { InviteResult, SeatState, WorkMail } from "@/lib/team-report";

export type TeamMember = {
  id: string;
  user_id: string;
  email: string;
  name: string | null;
  role: TeamRole;
  status?: string;
  joined_at: string | null;
  is_you?: boolean;
};

export type TeamInvitation = {
  id: string;
  email: string;
  role: TeamRole;
  expires_at: string | null;
  created_at?: string | null;
  last_sent_at?: string | null;
  send_error?: string | null;
  invited_by?: string | null;
  expired?: boolean;
};

export type Team = { id: string; name: string; slug: string; member_count: number };

export type JoinView = {
  org_name: string;
  role: TeamRole;
  email: string;
  invited_by: string | null;
  expires_at: string;
  status: "pending" | "accepted" | "revoked" | "expired";
  /** the work address that will be created for them, when the organiser asked for one */
  mailbox?: string | null;
};

export type JoinResult = {
  ok: boolean;
  already?: boolean;
  org_id: string;
  org_name: string;
  role: TeamRole;
  /** what happened to the work address (E34); absent on an older server */
  mailbox?: WorkMail;
};

export type MyInvitation = { token: string; org_name: string; role: TeamRole; invited_by: string; expires_at: string };

/** Rust did not take the call (not installed / down / SQL missing) — only then the old route may answer. */
function fallbackable(e: unknown): boolean {
  if (!(e instanceof ApiError)) return false;
  if ([501, 502, 503, 0].includes(e.status)) return true;
  return e.status === 404 && (!e.code || e.code === "procedure_not_in_rust");
}

async function call<T>(
  proc: string,
  input: unknown,
  rest: { path: string; method?: string; body?: unknown } | null,
): Promise<T> {
  try {
    return await rpc<T>(proc, input);
  } catch (e) {
    if (!rest || !fallbackable(e)) throw e;
    return api<T>(rest.path, {
      method: rest.method ?? (rest.body ? "POST" : "GET"),
      ...(rest.body ? { body: JSON.stringify(rest.body) } : {}),
    });
  }
}

export const ROLE_LABEL: Record<TeamRole, string> = {
  owner: "Owner",
  admin: "Admin",
  member: "Member",
  viewer: "Viewer",
};

/* ------------------------------------------------------------ members */

export function useMembers(orgId: string | undefined) {
  return useQuery<{ members: TeamMember[] }, ApiError>({
    queryKey: ["workspace", "members", orgId],
    queryFn: () => call("team.members.list", { org_id: orgId }, { path: "/api/workspace/members" }),
    enabled: Boolean(orgId),
    retry: false,
  });
}

/** Seats and the verified domains for the invite form — the database's own numbers. Rust only; an old server just shows nothing. */
export function useSeats(orgId: string | undefined, enabled: boolean) {
  return useQuery<SeatState, ApiError>({
    queryKey: ["workspace", "seats", orgId],
    queryFn: () => rpc<SeatState>("team.seats", { org_id: orgId }),
    enabled: Boolean(orgId) && enabled,
    retry: false,
  });
}

export function useInvitations(orgId: string | undefined, enabled: boolean) {
  return useQuery<{ invitations: TeamInvitation[] }, ApiError>({
    queryKey: ["workspace", "invitations", orgId],
    queryFn: () => call("team.invites.list", { org_id: orgId }, { path: "/api/workspace/invitations" }),
    enabled: Boolean(orgId) && enabled,
    retry: false,
  });
}

export function useTeamMutations(orgId: string | undefined) {
  const qc = useQueryClient();
  const refresh = () => {
    void qc.invalidateQueries({ queryKey: ["workspace", "members"] });
    void qc.invalidateQueries({ queryKey: ["workspace", "invitations"] });
    void qc.invalidateQueries({ queryKey: ["workspace", "teams"] });
    void qc.invalidateQueries({ queryKey: ["workspace", "seats"] });
  };
  const setRole = useMutation<unknown, ApiError, { id: string; role: TeamRole }>({
    mutationFn: ({ id, role }) =>
      call("team.members.update", { org_id: orgId, id, role }, { path: `/api/workspace/members/${id}`, method: "PATCH", body: { role } }),
    onSuccess: refresh,
  });
  const remove = useMutation<unknown, ApiError, string>({
    mutationFn: (id) =>
      call("team.members.remove", { org_id: orgId, id }, { path: `/api/workspace/members/${id}`, method: "DELETE" }),
    onSuccess: refresh,
  });
  const invite = useMutation<
    InviteResult,
    ApiError,
    { emails: string[]; role: TeamRole; mailbox?: string; domain_id?: string }
  >({
    // the optional work address (mailbox / domain_id) exists only in Rust; the old route simply invites
    mutationFn: ({ emails, role, mailbox, domain_id }) =>
      call(
        "team.invites.create",
        { org_id: orgId, emails, role, ...(mailbox ? { mailbox } : {}), ...(domain_id ? { domain_id } : {}) },
        mailbox ? null : { path: "/api/workspace/invitations", body: { emails, role } },
      ),
    onSuccess: refresh,
  });
  const revoke = useMutation<unknown, ApiError, string>({
    mutationFn: (id) =>
      call("team.invites.revoke", { org_id: orgId, id }, { path: `/api/workspace/invitations/${id}`, method: "DELETE" }),
    onSuccess: refresh,
  });
  const resend = useMutation<{ ok: boolean; sent: boolean }, ApiError, string>({
    // no old route can resend: Rust or nothing
    mutationFn: (id) => call("team.invites.resend", { org_id: orgId, id }, null),
    onSuccess: refresh,
  });
  return { setRole, remove, invite, revoke, resend };
}

/* -------------------------------------------------------------- teams */

export function useTeams(orgId: string | undefined) {
  return useQuery<{ teams: Team[] }, ApiError>({
    queryKey: ["workspace", "teams", orgId],
    queryFn: () => call("team.teams.list", { org_id: orgId }, { path: "/api/workspace/teams" }),
    enabled: Boolean(orgId),
    retry: false,
  });
}

export function useTeamActions(orgId: string | undefined) {
  const qc = useQueryClient();
  const refresh = () => void qc.invalidateQueries({ queryKey: ["workspace", "teams"] });
  const create = useMutation<unknown, ApiError, string>({
    mutationFn: (name) =>
      call("team.teams.create", { org_id: orgId, name }, { path: "/api/workspace/teams", body: { name } }),
    onSuccess: refresh,
  });
  const remove = useMutation<unknown, ApiError, string>({
    mutationFn: (id) =>
      call("team.teams.delete", { org_id: orgId, id }, { path: `/api/workspace/teams/${id}`, method: "DELETE" }),
    onSuccess: refresh,
  });
  const setPeople = useMutation<
    { ok: boolean; added: number; removed: number; ignored: number },
    ApiError,
    { id: string; user_ids: string[] }
  >({
    mutationFn: ({ id, user_ids }) => call("team.teams.setMembers", { org_id: orgId, id, user_ids }, null),
    onSuccess: refresh,
  });
  return { create, remove, setPeople };
}

export function useTeamPeople(orgId: string | undefined, teamId: string | null) {
  return useQuery<{ team_id: string; user_ids: string[] }, ApiError>({
    queryKey: ["workspace", "team-people", orgId, teamId],
    queryFn: () => call("team.teams.members", { org_id: orgId, id: teamId }, null),
    enabled: Boolean(orgId && teamId),
    retry: false,
  });
}

/* --------------------------------------------------------------- join */

/** Public: what the invitation link is for (before sign-in). Rust only — an old server has no invitations to look up. */
export function inviteLookup(token: string): Promise<JoinView> {
  return rpc<JoinView>("team.invite.lookup", { token });
}

/** Signed in: join. The role comes from the invitation on the server, never from here. */
export function inviteAccept(token: string): Promise<JoinResult> {
  return rpc<JoinResult>("team.invite.accept", { token });
}

export const PENDING_INVITE_KEY = "anexo.pending.invite";

export function rememberInvite(token: string) {
  try {
    window.sessionStorage.setItem(PENDING_INVITE_KEY, token);
  } catch {
    /* private window: the link in the e-mail still works */
  }
}

export function recalledInvite(): string {
  try {
    return window.sessionStorage.getItem(PENDING_INVITE_KEY) ?? "";
  } catch {
    return "";
  }
}

export function forgetInvite() {
  try {
    window.sessionStorage.removeItem(PENDING_INVITE_KEY);
  } catch {
    /* ignore */
  }
}

/** Signed in: invitations waiting for MY verified e-mail address (the server checks the address is confirmed). */
export function useMyInvitations(enabled: boolean) {
  return useQuery<{ invitations: MyInvitation[]; verified: boolean }, ApiError>({
    queryKey: ["workspace", "my-invitations"],
    queryFn: () => rpc<{ invitations: MyInvitation[]; verified: boolean }>("team.invites.mine", {}),
    enabled,
    retry: false,
  });
}

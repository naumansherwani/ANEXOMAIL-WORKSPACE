import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Loader2, MailPlus, ShieldCheck, Trash2, UserMinus } from "lucide-react";

import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState, StateBlock } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { api, ApiError } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { ADDRESS_MANAGER_FLAG, ROLES, type WorkspaceRole } from "@/lib/ia";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/admin/members")({
  head: () => ({
    meta: [
      { title: "Members & roles — ANEXOMAIL Admin" },
      {
        name: "description",
        content: "Manage the people in your ANEXOMAIL organisation, their roles and pending invitations.",
      },
      { property: "og:title", content: "Members & roles — ANEXOMAIL Admin" },
      { property: "og:description", content: "People, roles and pending invitations." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: MembersPage,
});

type Member = {
  id: string;
  user_id: string;
  email: string;
  name: string | null;
  role: WorkspaceRole;
  joined_at: string | null;
};

type Invitation = {
  id: string;
  email: string;
  role: WorkspaceRole;
  expires_at: string | null;
};

function MembersPage() {
  const { organisation, session } = useAuth();
  const queryClient = useQueryClient();
  const canManage = organisation?.role === "owner" || organisation?.role === "admin";

  const members = useQuery<{ members: Member[] }, ApiError>({
    queryKey: ["workspace", "members", organisation?.id],
    queryFn: () => api<{ members: Member[] }>("/api/workspace/members"),
    enabled: Boolean(organisation),
    retry: false,
  });

  const invitations = useQuery<{ invitations: Invitation[] }, ApiError>({
    queryKey: ["workspace", "invitations", organisation?.id],
    queryFn: () => api<{ invitations: Invitation[] }>("/api/workspace/invitations"),
    enabled: Boolean(organisation) && canManage,
    retry: false,
  });

  const invalidate = () => {
    void queryClient.invalidateQueries({ queryKey: ["workspace", "members"] });
    void queryClient.invalidateQueries({ queryKey: ["workspace", "invitations"] });
  };

  const setRole = useMutation({
    mutationFn: (vars: { id: string; role: WorkspaceRole }) =>
      api(`/api/workspace/members/${vars.id}`, {
        method: "PATCH",
        body: JSON.stringify({ role: vars.role }),
      }),
    onSuccess: () => {
      notify.done("Role updated", "The change applies on their next request.");
      invalidate();
    },
    onError: (e: ApiError) => notify.failed("Role not changed", { description: e.message }),
  });

  const removeMember = useMutation({
    mutationFn: (id: string) => api(`/api/workspace/members/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      notify.done("Member removed", "Their sessions were revoked.");
      invalidate();
    },
    onError: (e: ApiError) => notify.failed("Member not removed", { description: e.message }),
  });

  const revokeInvite = useMutation({
    mutationFn: (id: string) => api(`/api/workspace/invitations/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      notify.done("Invitation revoked", "That link no longer works.");
      invalidate();
    },
    onError: (e: ApiError) => notify.failed("Invitation not revoked", { description: e.message }),
  });

  const [emails, setEmails] = useState("");
  const [role, setRoleValue] = useState<WorkspaceRole>("member");

  const invite = useMutation({
    mutationFn: (list: string[]) =>
      api("/api/workspace/invitations", {
        method: "POST",
        body: JSON.stringify({ emails: list, role }),
      }),
    onSuccess: (_data, list) => {
      notify.done("Invitations sent", `${list.length} invited to ${organisation?.name ?? "your workspace"}.`);
      setEmails("");
      invalidate();
    },
    onError: (e: ApiError) => notify.failed("Invitations not sent", { description: e.message }),
  });

  if (!organisation) {
    return (
      <div className="mx-auto w-full max-w-3xl px-6 py-10 md:px-10">
        <StateBlock
          title="No organisation yet"
          body="Create your organisation first — members and roles live inside it."
        />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-10 md:px-10">
      <p className="ax-eyebrow">People</p>
      <h2 className="mt-3 text-3xl text-foreground">Members &amp; roles</h2>
      <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
        Three roles, deliberately. Extra power is granted per address instead of adding another
        tier nobody can explain.
      </p>

      {canManage && (
        <form
          className="mt-8 rounded-2xl border border-border bg-card p-5"
          onSubmit={(event) => {
            event.preventDefault();
            const list = emails
              .split(/[\s,;]+/)
              .map((e) => e.trim())
              .filter(Boolean);
            if (!list.length) return;
            invite.mutate(list);
          }}
        >
          <h2 className="ax-label text-foreground">Invite people</h2>
          <div className="mt-3 space-y-1.5">
            <Label htmlFor="invite-emails" className="ax-caption text-foreground">
              Emails
            </Label>
            <Input
              id="invite-emails"
              value={emails}
              onChange={(event) => setEmails(event.target.value)}
              placeholder="sara@yourcompany.com, ali@yourcompany.com"
            />
          </div>
          <div className="mt-3 flex flex-wrap items-center gap-2">
            {ROLES.filter((r) => r.id !== "owner").map((r) => (
              <button
                key={r.id}
                type="button"
                onClick={() => setRoleValue(r.id)}
                className={`ax-focus ax-press rounded-full px-3 py-1.5 text-xs font-semibold ${
                  role === r.id
                    ? "bg-cyan-accent/15 text-cyan-accent"
                    : "bg-secondary text-muted-foreground"
                }`}
              >
                {r.label}
              </button>
            ))}
            <Button type="submit" className="ax-press ml-auto" disabled={invite.isPending}>
              {invite.isPending ? (
                <Loader2 className="size-4 animate-spin" />
              ) : (
                <MailPlus className="size-4" />
              )}
              Send invitations
            </Button>
          </div>
        </form>
      )}

      <section className="mt-8">
        <h2 className="ax-label text-foreground">In this organisation</h2>
        <div className="mt-3">
          {members.isLoading ? (
            <ListSkeleton rows={4} />
          ) : members.error ? (
            <ErrorState
              body={
                members.error.isNotImplemented
                  ? "Members aren't live on the server yet."
                  : members.error.message
              }
              onRetry={() => void members.refetch()}
            />
          ) : !members.data?.members.length ? (
            <StateBlock
              title="Only you so far"
              body="Invite your first people above — they land in the same surface you're in."
            />
          ) : (
            <ul className="space-y-2">
              {members.data.members.map((m) => (
                <li
                  key={m.id}
                  className="ax-row flex flex-wrap items-center gap-3 rounded-xl border border-border bg-card px-4 py-3"
                >
                  <div className="min-w-0 flex-1">
                    <p className="ax-label truncate text-foreground">{m.name ?? m.email}</p>
                    <p className="ax-caption truncate">{m.email}</p>
                  </div>
                  {canManage && m.role !== "owner" && m.user_id !== session?.user.id ? (
                    <div className="flex items-center gap-2">
                      {(["admin", "member"] as WorkspaceRole[]).map((r) => (
                        <button
                          key={r}
                          type="button"
                          disabled={setRole.isPending}
                          onClick={() => setRole.mutate({ id: m.id, role: r })}
                          className={`ax-focus rounded-full px-2.5 py-1 text-xs font-semibold ${
                            m.role === r
                              ? "bg-cyan-accent/15 text-cyan-accent"
                              : "bg-secondary text-muted-foreground"
                          }`}
                        >
                          {r}
                        </button>
                      ))}
                      <Button
                        variant="ghost"
                        size="sm"
                        className="ax-press text-destructive"
                        disabled={removeMember.isPending}
                        onClick={() => removeMember.mutate(m.id)}
                        aria-label={`Remove ${m.email}`}
                      >
                        <UserMinus className="size-4" />
                      </Button>
                    </div>
                  ) : (
                    <span className="ax-caption inline-flex items-center gap-1.5 rounded-full bg-secondary px-2.5 py-1 font-semibold">
                      <ShieldCheck className="size-3.5 text-cyan-accent" />
                      {m.role}
                    </span>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>

      {canManage && (
        <section className="mt-8">
          <h2 className="ax-label text-foreground">Pending invitations</h2>
          <div className="mt-3">
            {invitations.isLoading ? (
              <ListSkeleton rows={2} />
            ) : invitations.error ? (
              <ErrorState
                body={
                  invitations.error.isNotImplemented
                    ? "Invitations aren't live on the server yet."
                    : invitations.error.message
                }
                onRetry={() => void invitations.refetch()}
              />
            ) : !invitations.data?.invitations.length ? (
              <p className="ax-caption">Nothing pending.</p>
            ) : (
              <ul className="space-y-2">
                {invitations.data.invitations.map((inv) => (
                  <li
                    key={inv.id}
                    className="ax-row flex items-center gap-3 rounded-xl border border-dashed border-border px-4 py-3"
                  >
                    <div className="min-w-0 flex-1">
                      <p className="ax-label truncate text-foreground">{inv.email}</p>
                      <p className="ax-caption">
                        {inv.role}
                        {inv.expires_at
                          ? ` · expires ${new Date(inv.expires_at).toLocaleDateString()}`
                          : ""}
                      </p>
                    </div>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="ax-press text-destructive"
                      disabled={revokeInvite.isPending}
                      onClick={() => revokeInvite.mutate(inv.id)}
                      aria-label={`Revoke invitation for ${inv.email}`}
                    >
                      <Trash2 className="size-4" />
                    </Button>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>
      )}

      <section className="mt-8 space-y-3">
        <h2 className="ax-label text-foreground">What each role can do</h2>
        {ROLES.map((r) => (
          <div key={r.id} className="ax-plane rounded-2xl p-5">
            <h3 className="text-base font-bold text-foreground">{r.label}</h3>
            <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">{r.summary}</p>
          </div>
        ))}
        <div className="rounded-2xl border border-dashed border-border p-5">
          <h3 className="text-base font-bold text-foreground">{ADDRESS_MANAGER_FLAG.label}</h3>
          <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
            {ADDRESS_MANAGER_FLAG.summary}
          </p>
        </div>
      </section>
    </div>
  );
}

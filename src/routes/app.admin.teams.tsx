import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Check, ChevronDown, Loader2, Plus, Trash2, Users } from "lucide-react";

import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState, StateBlock } from "@/components/state/StateBlock";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { ApiError } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { notify } from "@/lib/notify";
import { useMembers, useTeamActions, useTeamPeople, useTeams, type Team } from "@/lib/team";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/admin/teams")({
  head: () => ({
    meta: [
      { title: "Teams — ANEXOMAIL Admin" },
      {
        name: "description",
        content:
          "Group your people into teams so shared addresses, assignments and permissions follow the team, not the person.",
      },
      { property: "og:title", content: "Teams — ANEXOMAIL Admin" },
      {
        property: "og:description",
        content: "Teams carry shared addresses, assignments and permissions.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: TeamsPage,
});

function TeamsPage() {
  const { organisation } = useAuth();
  const canManage = organisation?.role === "owner" || organisation?.role === "admin";
  const [name, setName] = useState("");
  // Deleting a team drops the shared-address access and assignments that follow it — ask first (one mis-tap on a phone).
  const [confirmDelete, setConfirmDelete] = useState<Team | null>(null);
  const [open, setOpen] = useState<string | null>(null);

  const teams = useTeams(organisation?.id);
  const { create, remove } = useTeamActions(organisation?.id);

  if (!organisation) {
    return (
      <div className="mx-auto w-full max-w-3xl px-ax-4 py-ax-6 md:px-10 md:py-10">
        <StateBlock
          title="No organisation yet"
          body="Create your organisation first — teams live inside it."
        />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-3xl px-ax-4 py-ax-6 md:px-10 md:py-10">
      <p className="ax-eyebrow">People</p>
      <h2 className="mt-3 text-3xl text-foreground">Teams</h2>
      <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
        A team is who work belongs to. Shared addresses, assignments and permissions follow the
        team, so nothing breaks when one person leaves.
      </p>

      {canManage && (
        <form
          className="mt-8 rounded-2xl border border-border bg-card p-5"
          onSubmit={(event) => {
            event.preventDefault();
            if (!name.trim()) return;
            create.mutate(name.trim(), {
              onSuccess: () => {
                notify.done("Team created", "Press People on it to choose who is in the team.");
                setName("");
              },
              onError: (e: ApiError) => notify.failed("Team not created", { description: e.message }),
            });
          }}
        >
          <div className="space-y-1.5">
            <Label htmlFor="team-name" className="ax-caption text-foreground">
              Team name
            </Label>
            <Input
              id="team-name"
              value={name}
              onChange={(event) => setName(event.target.value)}
              placeholder="Support"
            />
          </div>
          <Button type="submit" className="ax-press mt-3" disabled={create.isPending}>
            {create.isPending ? (
              <Loader2 className="size-4 animate-spin" />
            ) : (
              <Plus className="size-4" />
            )}
            Create team
          </Button>
        </form>
      )}

      <div className="mt-8">
        {teams.isLoading ? (
          <ListSkeleton rows={3} />
        ) : teams.error ? (
          <ErrorState
            body={
              teams.error.isNotImplemented
                ? "Teams aren't live on the server yet."
                : teams.error.message
            }
            onRetry={() => void teams.refetch()}
          />
        ) : !teams.data?.teams.length ? (
          <StateBlock
            title="No teams yet"
            body="Most workspaces start with one — Support — and grow from there."
          />
        ) : (
          <ul className="space-y-2">
            {teams.data.teams.map((team) => (
              <li key={team.id} className="rounded-xl border border-border bg-card">
              <div className="ax-row flex items-center gap-3 px-4 py-3">
                <Users className="size-4 text-cyan-accent" aria-hidden />
                <div className="min-w-0 flex-1">
                  <p className="ax-label truncate text-foreground">{team.name}</p>
                  <p className="ax-caption">
                    {team.member_count} {team.member_count === 1 ? "person" : "people"}
                  </p>
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  className="ax-press ax-tap"
                  aria-expanded={open === team.id}
                  onClick={() => setOpen(open === team.id ? null : team.id)}
                >
                  People
                  <ChevronDown className={cn("size-3.5 transition-transform", open === team.id && "rotate-180")} aria-hidden />
                </Button>
                {canManage && (
                  <Button
                    variant="ghost"
                    size="sm"
                    className="ax-press text-destructive"
                    disabled={remove.isPending}
                    onClick={() => setConfirmDelete(team)}
                    aria-label={`Delete ${team.name}`}
                  >
                    <Trash2 className="size-4" />
                  </Button>
                )}
              </div>
              {open === team.id && (
                <TeamPeople orgId={organisation.id} team={team} canManage={canManage} onDone={() => setOpen(null)} />
              )}
              </li>
            ))}
          </ul>
        )}
      </div>

      <AlertDialog open={Boolean(confirmDelete)} onOpenChange={(o) => !o && setConfirmDelete(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete {confirmDelete?.name}?</AlertDialogTitle>
            <AlertDialogDescription>
              Anything shared with this team — addresses, assignments, permissions — stops following it. Its{" "}
              {confirmDelete?.member_count ?? 0} {confirmDelete?.member_count === 1 ? "person keeps" : "people keep"}{" "}
              their own mailboxes.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Keep team</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => {
                const target = confirmDelete;
                setConfirmDelete(null);
                if (target)
                  remove.mutate(target.id, {
                    onSuccess: () => notify.done("Team deleted", "Its people keep their own mailboxes."),
                    onError: (e: ApiError) => notify.failed("Team not deleted", { description: e.message }),
                  });
              }}
            >
              Delete team
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

/** Who is in the team: every active member of the organisation as a tick-box. Saved in one step. */
function TeamPeople({
  orgId,
  team,
  canManage,
  onDone,
}: {
  orgId: string;
  team: Team;
  canManage: boolean;
  onDone: () => void;
}) {
  const members = useMembers(orgId);
  const current = useTeamPeople(orgId, team.id);
  const { setPeople } = useTeamActions(orgId);
  const [picked, setPicked] = useState<Set<string> | null>(null);
  const chosen = picked ?? new Set(current.data?.user_ids ?? []);

  const toggle = (id: string) => {
    if (!canManage) return;
    const next = new Set(chosen);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    setPicked(next);
  };

  return (
    <div className="border-t border-border px-4 py-3">
      {members.isLoading || current.isLoading ? (
        <ListSkeleton rows={2} />
      ) : members.error || current.error ? (
        <p className="ax-caption text-danger">
          {(members.error ?? current.error)?.isNotImplemented
            ? "Team people aren't live on the server yet."
            : ((members.error ?? current.error)?.message ?? "Could not load.")}
        </p>
      ) : !members.data?.members.length ? (
        <p className="ax-caption">Nobody to add yet — invite people first.</p>
      ) : (
        <>
          <ul className="space-y-1.5" aria-label={`People in ${team.name}`}>
            {members.data.members.map((m) => {
              const on = chosen.has(m.user_id);
              return (
                <li key={m.user_id}>
                  <button
                    type="button"
                    role="checkbox"
                    aria-checked={on}
                    disabled={!canManage}
                    onClick={() => toggle(m.user_id)}
                    className="ax-press ax-focus ax-tap flex w-full items-center gap-3 rounded-lg px-2 py-1.5 text-left hover:bg-secondary disabled:opacity-70"
                  >
                    <span
                      className={cn(
                        "grid size-5 shrink-0 place-items-center rounded border",
                        on ? "border-cyan-accent bg-cyan-accent/20 text-cyan-accent" : "border-border",
                      )}
                    >
                      {on && <Check className="size-3.5" aria-hidden />}
                    </span>
                    <span className="min-w-0 flex-1 break-all text-sm text-foreground sm:truncate">{m.email}</span>
                    <span className="ax-caption shrink-0">{m.role}</span>
                  </button>
                </li>
              );
            })}
          </ul>
          {canManage && (
            <div className="mt-3 flex items-center gap-2">
              <Button
                size="sm"
                className="ax-tap"
                disabled={picked === null || setPeople.isPending}
                onClick={() =>
                  setPeople.mutate(
                    { id: team.id, user_ids: [...chosen] },
                    {
                      onSuccess: (res) => {
                        notify.done("Team saved", `${res.added} added, ${res.removed} removed.`);
                        onDone();
                      },
                      onError: (e: ApiError) => notify.failed("Team not saved", { description: e.message }),
                    },
                  )
                }
              >
                {setPeople.isPending ? "Saving…" : "Save people"}
              </Button>
              <Button size="sm" variant="ghost" className="ax-tap" onClick={onDone}>
                Close
              </Button>
            </div>
          )}
        </>
      )}
    </div>
  );
}

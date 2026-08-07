import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Loader2, Plus, Trash2, Users } from "lucide-react";

import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState, StateBlock } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { api, ApiError } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { notify } from "@/lib/notify";

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

type Team = {
  id: string;
  name: string;
  slug: string;
  member_count: number;
};

function TeamsPage() {
  const { organisation } = useAuth();
  const queryClient = useQueryClient();
  const canManage = organisation?.role === "owner" || organisation?.role === "admin";
  const [name, setName] = useState("");

  const teams = useQuery<{ teams: Team[] }, ApiError>({
    queryKey: ["workspace", "teams", organisation?.id],
    queryFn: () => api<{ teams: Team[] }>("/api/workspace/teams"),
    enabled: Boolean(organisation),
    retry: false,
  });

  const invalidate = () =>
    void queryClient.invalidateQueries({ queryKey: ["workspace", "teams"] });

  const create = useMutation({
    mutationFn: (teamName: string) =>
      api("/api/workspace/teams", { method: "POST", body: JSON.stringify({ name: teamName }) }),
    onSuccess: () => {
      notify.done("Team created", "Add people and shared addresses to it next.");
      setName("");
      invalidate();
    },
    onError: (e: ApiError) => notify.failed("Team not created", { description: e.message }),
  });

  const remove = useMutation({
    mutationFn: (id: string) => api(`/api/workspace/teams/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      notify.done("Team deleted", "Its people keep their own mailboxes.");
      invalidate();
    },
    onError: (e: ApiError) => notify.failed("Team not deleted", { description: e.message }),
  });

  if (!organisation) {
    return (
      <div className="mx-auto w-full max-w-3xl px-6 py-10 md:px-10">
        <StateBlock
          title="No organisation yet"
          body="Create your organisation first — teams live inside it."
        />
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-10 md:px-10">
      <p className="ax-eyebrow">People</p>
      <h1 className="mt-3 text-3xl text-foreground">Teams</h1>
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
            create.mutate(name.trim());
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
              <li
                key={team.id}
                className="ax-row flex items-center gap-3 rounded-xl border border-border bg-card px-4 py-3"
              >
                <Users className="size-4 text-cyan-accent" aria-hidden />
                <div className="min-w-0 flex-1">
                  <p className="ax-label truncate text-foreground">{team.name}</p>
                  <p className="ax-caption">
                    {team.member_count} {team.member_count === 1 ? "person" : "people"}
                  </p>
                </div>
                {canManage && (
                  <Button
                    variant="ghost"
                    size="sm"
                    className="ax-press text-destructive"
                    disabled={remove.isPending}
                    onClick={() => remove.mutate(team.id)}
                    aria-label={`Delete ${team.name}`}
                  >
                    <Trash2 className="size-4" />
                  </Button>
                )}
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

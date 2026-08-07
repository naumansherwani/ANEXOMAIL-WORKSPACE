import { Outlet, createFileRoute, notFound, useNavigate, useRouterState } from "@tanstack/react-router";
import { Mail, PenLine, Search, X } from "lucide-react";
import { useCallback, useEffect, useState } from "react";

import { ComposeOverlay } from "@/components/app/ComposeOverlay";
import { DetailPanel, EmptyState, ListPanel } from "@/components/app/Panel";
import { MailRail } from "@/components/app/mail/MailRail";
import { ThreadList } from "@/components/app/mail/ThreadList";
import { MAIL_FOLDERS, isMailFolder } from "@/lib/ia";
import { notify } from "@/lib/notify";
import {
  THREAD_CATEGORIES,
  useThreadAction,
  useThreads,
  type ThreadCategory,
} from "@/lib/mail";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/mail/$folder")({
  loader: ({ params }) => {
    if (!isMailFolder(params.folder)) throw notFound();
    return { folder: params.folder };
  },
  head: ({ loaderData }) => {
    const label = loaderData
      ? MAIL_FOLDERS.find((f) => f.id === loaderData.folder)?.label
      : undefined;
    return {
      meta: [
        { title: `${label ?? "Mail"} — ANEXOMAIL Workspace` },
        { name: "robots", content: "noindex" },
      ],
    };
  },
  component: MailFolderPage,
  notFoundComponent: UnknownFolder,
});

function UnknownFolder() {
  return (
    <EmptyState
      icon={<Mail className="size-5" />}
      title="That folder doesn't exist"
      body="Pick a folder from the list, or press Cmd+K to jump anywhere in the workspace."
    />
  );
}

function MailFolderPage() {
  const { folder } = Route.useLoaderData();
  const navigate = useNavigate();
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const activeId = pathname.split("/")[4];

  const [label, setLabel] = useState<string | null>(null);
  const [account, setAccount] = useState<string | null>(null);
  const [category, setCategory] = useState<ThreadCategory | null>(null);
  const [q, setQ] = useState("");
  const [cursor, setCursor] = useState(0);
  const [composing, setComposing] = useState(false);

  const query = useThreads({ folder, label, account, category, q });
  const threads = query.data?.threads;
  const action = useThreadAction();

  const act = useCallback(
    (
      threadId: string,
      payload: Parameters<typeof action.mutate>[0]["action"],
      okMessage: string,
      endpoint: string,
    ) =>
      action.mutate(
        { threadId, action: payload },
        {
          onSuccess: () => notify.done(okMessage),
          onError: (error) =>
            notify.failed(error.isNotImplemented ? "Not wired yet" : "Action failed", {
              description: error.isNotImplemented ? `Waiting on ${endpoint}.` : error.message,
            }),
        },
      ),
    [action],
  );

  // Keyboard shortcuts — j/k move, Enter opens, e archives, s snoozes, c composes.
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      if (event.metaKey || event.ctrlKey || event.altKey) return;
      if (target && /input|textarea|select/i.test(target.tagName)) return;
      if (target?.isContentEditable) return;

      const list = threads ?? [];
      const current = list[cursor];

      switch (event.key) {
        case "j":
          event.preventDefault();
          setCursor((i) => Math.min(i + 1, Math.max(list.length - 1, 0)));
          break;
        case "k":
          event.preventDefault();
          setCursor((i) => Math.max(i - 1, 0));
          break;
        case "Enter":
          if (!current) return;
          event.preventDefault();
          void navigate({
            to: "/app/mail/$folder/$threadId",
            params: { folder, threadId: current.id },
          });
          break;
        case "e":
          if (!current) return;
          event.preventDefault();
          act(current.id, { kind: "move", folder: "archive" }, "Archived", "POST /api/mail/thread/:id/move");
          break;
        case "s":
          if (!current) return;
          event.preventDefault();
          act(
            current.id,
            { kind: "snooze", until: new Date(Date.now() + 86_400_000).toISOString() },
            "Snoozed until tomorrow",
            "POST /api/mail/thread/:id/snooze",
          );
          break;
        case "c":
          event.preventDefault();
          setComposing(true);
          break;
        case "/":
          event.preventDefault();
          document.getElementById("mail-search")?.focus();
          break;
        default:
          break;
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [threads, cursor, folder, navigate, act]);

  const folderLabel = MAIL_FOLDERS.find((f) => f.id === folder)?.label ?? "Mail";

  return (
    <>
      <MailRail
        folder={folder}
        label={label}
        account={account}
        onLabel={setLabel}
        onAccount={setAccount}
        onDropLabel={(labelId, threadId) =>
          act(threadId, { kind: "labels", add: [labelId] }, "Filed", "POST /api/mail/thread/:id/labels")
        }
      />

      <ListPanel
        title={account ? folderLabel : `${folderLabel} · Unified`}
        action={
          <button
            type="button"
            onClick={() => setComposing(true)}
            className="ax-press ax-tap inline-flex items-center gap-1.5 rounded-lg border border-border bg-secondary px-2.5 py-1.5 text-xs font-semibold text-foreground transition-colors hover:bg-surface-2"
          >
            <PenLine className="size-3.5" />
            Compose
          </button>
        }
      >
        <div className="sticky top-0 z-10 flex flex-col gap-ax-2 border-b border-border bg-background/95 px-ax-3 py-ax-2 backdrop-blur">
          <div className="flex items-center gap-2 rounded-lg border border-border bg-card px-2.5 py-1.5">
            <Search className="size-3.5 shrink-0 text-steel" aria-hidden="true" />
            <input
              id="mail-search"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Search this workspace…  ( / )"
              className="min-w-0 flex-1 bg-transparent text-[13px] outline-none placeholder:text-muted-foreground"
            />
            {q && (
              <button type="button" aria-label="Clear search" onClick={() => setQ("")}>
                <X className="size-3.5 text-steel" />
              </button>
            )}
          </div>

          <div className="flex items-center gap-1 overflow-x-auto">
            <button
              type="button"
              onClick={() => setCategory(null)}
              className={cn(
                "shrink-0 rounded-full px-2.5 py-1 text-[11px] font-semibold transition-colors",
                category === null
                  ? "bg-secondary text-foreground"
                  : "text-muted-foreground hover:text-foreground",
              )}
            >
              All
            </button>
            {THREAD_CATEGORIES.map((c) => (
              <button
                key={c.id}
                type="button"
                onClick={() => setCategory(c.id === category ? null : c.id)}
                className={cn(
                  "shrink-0 rounded-full px-2.5 py-1 text-[11px] font-semibold transition-colors",
                  category === c.id
                    ? "bg-secondary text-foreground"
                    : "text-muted-foreground hover:text-foreground",
                )}
              >
                {c.label}
              </button>
            ))}
            <span className="ml-auto hidden shrink-0 pl-2 text-[10px] text-steel sm:block">
              j/k · ↵ open · e archive · s snooze · c compose
            </span>
          </div>
        </div>

        <ThreadList
          folder={folder}
          threads={threads}
          isPending={query.isPending}
          error={query.error}
          onRetry={() => void query.refetch()}
          activeId={activeId}
          cursor={cursor}
          onCursor={setCursor}
        />
      </ListPanel>

      <DetailPanel>
        <Outlet />
      </DetailPanel>

      {composing && <ComposeOverlay onClose={() => setComposing(false)} />}
    </>
  );
}

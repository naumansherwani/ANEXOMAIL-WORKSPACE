import { Link } from "@tanstack/react-router";
import { AtSign, Tag } from "lucide-react";
import { useState } from "react";

import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { SkeletonLine } from "@/components/state/Skeletons";
import { MAIL_FOLDERS, type MailFolder } from "@/lib/ia";
import { useAccounts, useLabels } from "@/lib/mail";
import { cn } from "@/lib/utils";

/**
 * Column 1 of the mail surface: folders, labels, accounts.
 * Labels are drag targets — dropping a thread row here files it, no reload.
 */
export function MailRail({
  folder,
  label,
  account,
  onLabel,
  onAccount,
  onDropLabel,
}: {
  folder: MailFolder;
  label: string | null;
  account: string | null;
  onLabel: (id: string | null) => void;
  onAccount: (id: string | null) => void;
  onDropLabel: (labelId: string, threadId: string) => void;
}) {
  const labels = useLabels();
  const accounts = useAccounts();
  const [dropTarget, setDropTarget] = useState<string | null>(null);

  return (
    <div className="hidden w-[13rem] shrink-0 flex-col gap-ax-4 overflow-y-auto border-r border-border bg-sidebar/60 p-ax-3 lg:flex">
      <nav className="flex flex-col gap-0.5">
        {MAIL_FOLDERS.map((f) => (
          <Link
            key={f.id}
            to="/app/mail/$folder"
            params={{ folder: f.id }}
            className={cn(
              "rounded-lg px-2.5 py-2 text-[13px] font-medium transition-colors",
              f.id === folder
                ? "bg-secondary text-foreground"
                : "text-muted-foreground hover:bg-secondary/60 hover:text-foreground",
            )}
          >
            {f.label}
          </Link>
        ))}
      </nav>

      <section className="flex flex-col gap-1.5">
        <h3 className="ax-eyebrow flex items-center gap-1.5 px-1">
          <Tag className="size-3" aria-hidden="true" /> Labels
        </h3>
        {labels.error ? (
          labels.error.isNotImplemented || labels.error.code === "no_api_url" ? (
            <NotWired endpoint="GET /api/mail/labels" />
          ) : (
            <p className="ax-caption px-1 text-muted-foreground">{labels.error.message}</p>
          )
        ) : labels.isPending ? (
          <div className="flex flex-col gap-2 px-1 py-1">
            <SkeletonLine className="h-2.5" width="70%" />
            <SkeletonLine className="h-2.5" width="52%" />
          </div>
        ) : labels.data.labels.length === 0 ? (
          <p className="ax-caption px-1 text-muted-foreground">No labels yet.</p>
        ) : (
          <>
            {label && (
              <button
                type="button"
                onClick={() => onLabel(null)}
                className="ax-press self-start px-1 text-[11px] font-semibold text-steel underline-offset-4 hover:underline"
              >
                Clear label filter
              </button>
            )}
            {labels.data.labels.map((l) => (
              <button
                key={l.id}
                type="button"
                onClick={() => onLabel(l.id === label ? null : l.id)}
                onDragOver={(e) => {
                  e.preventDefault();
                  setDropTarget(l.id);
                }}
                onDragLeave={() => setDropTarget((t) => (t === l.id ? null : t))}
                onDrop={(e) => {
                  e.preventDefault();
                  setDropTarget(null);
                  const threadId = e.dataTransfer.getData("text/anexo-thread");
                  if (threadId) onDropLabel(l.id, threadId);
                }}
                className={cn(
                  "flex items-center gap-2 rounded-lg px-2.5 py-1.5 text-left text-[13px] transition-colors",
                  l.id === label
                    ? "bg-secondary text-foreground"
                    : "text-muted-foreground hover:bg-secondary/60 hover:text-foreground",
                  dropTarget === l.id && "ring-2 ring-ring",
                )}
              >
                <span
                  aria-hidden="true"
                  className="size-2 shrink-0 rounded-full"
                  style={{ background: l.colour ?? "currentColor" }}
                />
                <span className="truncate">{l.name}</span>
                {typeof l.thread_count === "number" && (
                  <span className="ml-auto text-[10px] text-steel">{l.thread_count}</span>
                )}
              </button>
            ))}
          </>
        )}
      </section>

      <section className="flex flex-col gap-1.5">
        <h3 className="ax-eyebrow flex items-center gap-1.5 px-1">
          <AtSign className="size-3" aria-hidden="true" /> Accounts
        </h3>
        {accounts.error ? (
          accounts.error.isNotImplemented || accounts.error.code === "no_api_url" ? (
            <NotWired endpoint="GET /api/mail/accounts" />
          ) : (
            <p className="ax-caption px-1 text-muted-foreground">{accounts.error.message}</p>
          )
        ) : accounts.isPending ? (
          <SkeletonLine className="mx-1 h-2.5" width="80%" />
        ) : accounts.data.accounts.length === 0 ? (
          <p className="ax-caption px-1 text-muted-foreground">
            No address yet. Create one in Admin → Addresses.
          </p>
        ) : (
          <>
            <button
              type="button"
              onClick={() => onAccount(null)}
              className={cn(
                "rounded-lg px-2.5 py-1.5 text-left text-[13px] transition-colors",
                account === null
                  ? "bg-secondary text-foreground"
                  : "text-muted-foreground hover:bg-secondary/60",
              )}
            >
              Unified inbox
            </button>
            {accounts.data.accounts.map((a) => (
              <button
                key={a.id}
                type="button"
                onClick={() => onAccount(a.id === account ? null : a.id)}
                className={cn(
                  "flex items-center gap-2 rounded-lg px-2.5 py-1.5 text-left text-[13px] transition-colors",
                  a.id === account
                    ? "bg-secondary text-foreground"
                    : "text-muted-foreground hover:bg-secondary/60 hover:text-foreground",
                )}
              >
                <span className="truncate">{a.address}</span>
                {a.unread ? (
                  <span className="ml-auto text-[10px] font-semibold text-foreground">
                    {a.unread}
                  </span>
                ) : null}
              </button>
            ))}
          </>
        )}
      </section>
    </div>
  );
}

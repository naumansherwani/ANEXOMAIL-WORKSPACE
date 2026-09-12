import { Link } from "@tanstack/react-router";
import {
  Archive,
  AtSign,
  Clock,
  FileText,
  Inbox,
  PenLine,
  Send,
  ShieldAlert,
  Tag,
  Trash2,
  UserCheck,
} from "lucide-react";
import { useState, type ComponentType } from "react";

import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { SkeletonLine } from "@/components/state/Skeletons";
import { MAIL_FOLDERS, type MailFolder } from "@/lib/ia";
import { useLocale } from "@/lib/i18n";
import { useAccounts, useFolderCounts, useLabels } from "@/lib/mail";
import { cn } from "@/lib/utils";

const FOLDER_ICON: Record<MailFolder, ComponentType<{ className?: string }>> = {
  inbox: Inbox,
  assigned: UserCheck,
  waiting: Clock,
  sent: Send,
  drafts: FileText,
  archive: Archive,
  spam: ShieldAlert,
  trash: Trash2,
};

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
  onCompose,
}: {
  folder: MailFolder;
  label: string | null;
  account: string | null;
  onLabel: (id: string | null) => void;
  onAccount: (id: string | null) => void;
  onDropLabel: (labelId: string, threadId: string) => void;
  onCompose?: () => void;
}) {
  const labels = useLabels();
  const accounts = useAccounts();
  const counts = useFolderCounts();
  const { t } = useLocale();
  const [dropTarget, setDropTarget] = useState<string | null>(null);

  return (
    <div className="hidden w-[13rem] shrink-0 flex-col gap-ax-4 overflow-y-auto border-r border-border bg-sidebar/60 p-ax-3 lg:flex">
      {onCompose && (
        <button
          type="button"
          onClick={onCompose}
          className="flex items-center gap-2 rounded-xl bg-primary px-3 py-2.5 text-[13px] font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
        >
          <PenLine className="size-3.5 shrink-0" aria-hidden="true" />
          {t("New email")}
        </button>
      )}
      <nav className="flex flex-col gap-0.5">
        {MAIL_FOLDERS.map((f) => {
          const Icon = FOLDER_ICON[f.id];
          const unread = counts.data?.folders[f.id]?.unread ?? 0;
          const active = f.id === folder;
          return (
            <Link
              key={f.id}
              to="/app/mail/$folder"
              params={{ folder: f.id }}
              className={cn(
                "relative flex items-center gap-2 rounded-lg px-2.5 py-1.5 text-[13px] font-medium transition-opacity",
                active
                  ? "text-foreground"
                  : "text-muted-foreground opacity-60 hover:opacity-100",
              )}
            >
              {active && (
                <span
                  aria-hidden="true"
                  className="absolute inset-y-[18%] left-0 w-[3px] rounded-full bg-primary"
                />
              )}
              <Icon className="size-3.5 shrink-0" aria-hidden="true" />
              <span className="truncate">{t(f.label)}</span>
              {unread > 0 && (
                <span className="ml-auto tabular-nums text-[10px] font-semibold text-foreground">
                  {unread}
                </span>
              )}
            </Link>
          );
        })}
      </nav>

      <section className="flex flex-col gap-1.5">
        <h3 className="ax-eyebrow flex items-center gap-1.5 px-1">
          <Tag className="size-3" aria-hidden="true" /> {t("Labels")}
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
          <p className="ax-caption px-1 text-muted-foreground">{t("No labels yet.")}</p>
        ) : (
          <>
            {label && (
              <button
                type="button"
                onClick={() => onLabel(null)}
                className="ax-press self-start px-1 text-[11px] font-semibold text-steel underline-offset-4 hover:underline"
              >
                {t("Clear label filter")}
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
                  "flex items-center gap-2 rounded-lg px-2.5 py-1.5 text-left text-[13px] transition-opacity",
                  l.id === label
                    ? "text-foreground"
                    : "text-muted-foreground opacity-60 hover:opacity-100",
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
          <AtSign className="size-3" aria-hidden="true" /> {t("Accounts")}
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
            {t("No address yet. Create one in Admin → Addresses.")}
          </p>
        ) : (
          <>
            <button
              type="button"
              onClick={() => onAccount(null)}
              className={cn(
                "rounded-lg px-2.5 py-1.5 text-left text-[13px] transition-opacity",
                account === null
                  ? "text-foreground"
                  : "text-muted-foreground opacity-60 hover:opacity-100",
              )}
            >
              {t("Unified inbox")}
            </button>
            {accounts.data.accounts.map((a) => (
              <button
                key={a.id}
                type="button"
                onClick={() => onAccount(a.id === account ? null : a.id)}
                className={cn(
                  "flex items-center gap-2 rounded-lg px-2.5 py-1.5 text-left text-[13px] transition-opacity",
                  a.id === account
                    ? "text-foreground"
                    : "text-muted-foreground opacity-60 hover:opacity-100",
                )}
              >
                <span className="break-all">{a.address}</span>
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

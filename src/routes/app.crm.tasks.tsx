import { createFileRoute, Link } from "@tanstack/react-router";
import { CheckSquare } from "lucide-react";

import { Chip, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useTasks } from "@/lib/calendar";
import { useLocale } from "@/lib/i18n";
import { relativeTime } from "@/lib/mail";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/crm/tasks")({
  head: () => ({
    meta: [
      { title: "Tasks — ANEXOMAIL CRM" },
      {
        name: "description",
        content:
          "Work that came out of deals and customer mail — owner, due date and late truth on every row.",
      },
      { property: "og:title", content: "Tasks — ANEXOMAIL CRM" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CrmTasksPage,
});

const STATUS_TONE: Record<string, "quiet" | "warn" | "good"> = {
  todo: "quiet",
  doing: "warn",
  waiting: "warn",
  done: "good",
};

function CrmTasksPage() {
  const { t } = useLocale();
  const tasks = useTasks({});

  return (
    <div className="mx-auto w-full max-w-6xl px-ax-4 py-ax-5 md:px-ax-5 md:py-ax-6">
      <SectionTitle
        title={t("Tasks")}
        hint={t("Deal → work conversion lands here. A task always carries an owner and a due date — never an island.")}
      />

      <CardBody
        query={{
          data: tasks.data,
          isPending: tasks.isPending,
          error: tasks.error ?? null,
          refetch: () => void tasks.refetch(),
        }}
        endpoint="/api/work/tasks"
        skeleton={<StatSkeleton rows={6} />}
      >
        {(data) =>
          data.tasks.length === 0 ? (
            <div className="ax-plane flex min-h-[10rem] flex-col items-center justify-center gap-2 rounded-2xl p-ax-6 text-center">
              <CheckSquare className="size-5 text-steel" />
              <p className="text-sm font-semibold text-foreground">{t("No tasks yet")}</p>
              <p className="ax-caption max-w-sm text-muted-foreground">
                {t("Open a deal on the pipeline and press Work — the task appears here with its owner.")}
              </p>
            </div>
          ) : (
            <div className="ax-plane divide-y divide-border rounded-2xl">
              {data.tasks.map((task) => (
                <div key={task.id} className="flex flex-wrap items-center gap-x-ax-3 gap-y-2 px-ax-4 py-ax-3 sm:flex-nowrap">
                  <span
                    className={cn(
                      "flex size-8 shrink-0 items-center justify-center rounded-xl",
                      task.status === "done"
                        ? "bg-success/10 text-success"
                        : "bg-secondary text-steel",
                    )}
                  >
                    <CheckSquare className="size-4" />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span
                      className={cn(
                        "block break-words text-sm font-semibold sm:truncate",
                        task.status === "done"
                          ? "text-muted-foreground line-through"
                          : "text-foreground",
                      )}
                    >
                      {task.title}
                    </span>
                    <span className="ax-caption block truncate text-muted-foreground">
                      {task.owner ?? t("Unassigned")}
                      {task.due_at ? ` · ${t("due")} ${relativeTime(task.due_at)}` : ""}
                      {task.thread_subject ? ` · ${task.thread_subject}` : ""}
                    </span>
                  </span>
                  {/* Phone: status chips + link sit under the title (aligned with it), not squeezing it to "Send revised pro…". */}
                  <div className="flex basis-full items-center gap-ax-3 ps-11 sm:basis-auto sm:ps-0">
                    {task.late && task.status !== "done" ? (
                      <Chip tone="bad">{t("Late")}</Chip>
                    ) : null}
                    <Chip tone={STATUS_TONE[task.status] ?? "quiet"}>{t(task.status)}</Chip>
                    {task.thread_id ? (
                      <Link
                        to="/app/mail/$folder/$threadId"
                        params={{ folder: "inbox", threadId: task.thread_id }}
                        className="ax-press ax-hit shrink-0 text-[12px] font-semibold text-foreground underline-offset-4 hover:underline"
                      >
                        {t("Open thread")}
                      </Link>
                    ) : null}
                  </div>
                </div>
              ))}
            </div>
          )
        }
      </CardBody>
    </div>
  );
}

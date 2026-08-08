import { createFileRoute } from "@tanstack/react-router";
import { BrainCircuit, Trash2 } from "lucide-react";

import { Chip } from "@/components/app/ai/AiBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import { useAiMemory, useForgetMemory } from "@/lib/ai-workspace";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/founder_/ai/memory")({
  component: Memory,
});

/** Session memory — "forget this" ka matlab REAL delete hai, hide nahi. */
function Memory() {
  const memory = useAiMemory();
  const forget = useForgetMemory();

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-4xl px-6 py-8 md:px-8">
        <p className="ax-eyebrow flex items-center gap-2">
          <BrainCircuit className="size-3.5" aria-hidden="true" /> Memory
        </p>
        <h2 className="ax-h2 mt-1 text-foreground">What LEO remembers</h2>
        <p className="ax-caption mt-1 text-muted-foreground">
          Forget this = real delete on the server. No shadow copy, no archive.
        </p>

        <div className="mt-ax-5">
          <CardBody
            query={{
              data: memory.data,
              isPending: memory.isPending,
              error: memory.error ?? null,
              refetch: () => void memory.refetch(),
            }}
            endpoint="/api/ai/memory"
            skeleton={<StatSkeleton rows={6} />}
          >
            {(d) =>
              d.items.length === 0 ? (
                <p className="ax-caption text-muted-foreground">Nothing remembered yet.</p>
              ) : (
                <ul className="space-y-1.5">
                  {d.items.map((m) => (
                    <li
                      key={m.id}
                      className="flex flex-wrap items-center gap-2 rounded-xl border border-border px-ax-3 py-ax-2"
                    >
                      <span className="text-[13px] font-semibold text-foreground">{m.key}</span>
                      <span className="ax-caption min-w-0 flex-1 truncate text-muted-foreground">
                        {m.value}
                      </span>
                      {m.source && <Chip>{m.source}</Chip>}
                      <span className="ax-caption text-muted-foreground">
                        {relativeTime(m.created_at)}
                      </span>
                      <Button
                        size="sm"
                        variant="secondary"
                        disabled={forget.isPending}
                        onClick={() =>
                          forget.mutate(
                            { id: m.id },
                            {
                              onSuccess: () => notify.done("Forgotten", "Deleted from the server."),
                              onError: (e) =>
                                notify.failed(
                                  e.isNotImplemented ? "Memory not wired yet" : "Could not delete",
                                  { description: e.message },
                                ),
                            },
                          )
                        }
                      >
                        <Trash2 className="size-3.5" aria-hidden="true" /> Forget
                      </Button>
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </div>
      </div>
    </div>
  );
}
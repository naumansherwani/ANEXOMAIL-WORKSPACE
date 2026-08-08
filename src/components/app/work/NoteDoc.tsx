import { useEffect, useRef, useState } from "react";

import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { SkeletonLine } from "@/components/state/Skeletons";
import { useNote, useSaveNote } from "@/lib/calendar";

/**
 * Notes are a live doc attached to a thread or a meeting — never a separate
 * app. Autosave is debounced; the server owns the stored body.
 */
export function NoteDoc({
  target,
}: {
  target: { thread_id?: string; event_id?: string };
}) {
  const query = useNote(target);
  const save = useSaveNote();
  const [body, setBody] = useState<string | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (query.data && body === null) setBody(query.data.note?.body ?? "");
  }, [query.data, body]);

  useEffect(() => () => {
    if (timer.current) clearTimeout(timer.current);
  }, []);

  if (query.error) {
    if (query.error.isNotImplemented || query.error.code === "no_api_url") {
      return <NotWired endpoint="GET /api/work/notes" />;
    }
    return <p className="ax-caption text-danger">{query.error.message}</p>;
  }
  if (query.isPending) return <SkeletonLine className="h-20" />;

  const onChange = (value: string) => {
    setBody(value);
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      save.mutate({ body: value, ...target });
    }, 900);
  };

  return (
    <div className="rounded-xl border border-border">
      <textarea
        value={body ?? ""}
        onChange={(e) => onChange(e.target.value)}
        rows={6}
        placeholder="Write what matters. It stays attached to this conversation."
        className="ax-focus w-full resize-y bg-transparent px-ax-3 py-ax-2 text-[13px] text-foreground outline-none placeholder:text-steel"
      />
      <p className="ax-caption border-t border-border px-ax-3 py-1.5 text-steel">
        {save.isPending
          ? "Saving…"
          : query.data?.note?.updated_at
            ? `Saved ${new Date(query.data.note.updated_at).toLocaleString()}`
            : "Not saved yet"}
      </p>
    </div>
  );
}
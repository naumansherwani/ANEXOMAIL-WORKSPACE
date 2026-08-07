import { createFileRoute } from "@tanstack/react-router";
import { Search } from "lucide-react";

import { EmptyState } from "@/components/app/Panel";

export const Route = createFileRoute("/app/search")({
  validateSearch: (search: Record<string, unknown>) => ({
    q: typeof search["q"] === "string" ? search["q"] : "",
  }),
  head: () => ({
    meta: [
      { title: "Search — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: SearchPage,
});

function SearchPage() {
  const { q } = Route.useSearch();

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 py-12 md:px-10">
        <p className="ax-eyebrow">Everything</p>
        <h1 className="mt-3 text-3xl text-foreground md:text-4xl">Search</h1>
        <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
          One index across mail, people, calendar and work. Press ⌘K anywhere to reach it
          without leaving the panel you are in.
        </p>
        <div className="mt-8">
          <EmptyState
            icon={<Search className="size-5" />}
            title={q ? `No results for “${q}”` : "Nothing to search yet"}
            body="The search index is built from your own mailboxes. Connect a domain and create an address to fill it."
          />
        </div>
      </div>
    </div>
  );
}
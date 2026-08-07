import { Link, Outlet, createFileRoute } from "@tanstack/react-router";

import { ADMIN_SECTIONS } from "@/lib/ia";

export const Route = createFileRoute("/app/admin")({
  head: () => ({
    meta: [
      { title: "Admin — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AdminLayout,
});

function AdminLayout() {
  return (
    <div className="flex min-h-0 flex-1 flex-col overflow-hidden md:flex-row">
      <nav className="flex shrink-0 gap-1 overflow-x-auto border-b border-border p-3 md:w-[15rem] md:flex-col md:overflow-visible md:border-r md:border-b-0">
        {ADMIN_SECTIONS.map((s) => (
          <Link
            key={s.to}
            to={s.to}
            activeOptions={{ exact: s.to === "/app/admin" }}
            activeProps={{ className: "bg-secondary text-foreground" }}
            inactiveProps={{
              className: "text-muted-foreground hover:bg-secondary/60",
            }}
            className="rounded-xl px-3 py-2 text-sm font-medium whitespace-nowrap transition-colors"
          >
            {s.label}
          </Link>
        ))}
      </nav>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <Outlet />
      </div>
    </div>
  );
}
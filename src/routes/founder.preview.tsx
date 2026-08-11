import { createFileRoute, useRouter } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";

import { founderPreviewEnabled, founderPreviewFromUrl } from "@/lib/founder-preview";
import { setVisitorPreview } from "@/lib/visitor-preview";

export const Route = createFileRoute("/founder/preview")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Public preview — ANEXOMAIL founder" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: FounderPublicPreview;
});

type Device = { id: "mobile" | "tablet" | "desktop"; label: string; width: number };

const DEVICES: Device[] = [
  { id: "mobile", label: "Mobile 390", width: 390 },
  { id: "tablet", label: "Tablet 768", width: 768 },
  { id: "desktop", label: "Desktop 1440", width: 1440 },
];

type ScanResult = {
  status: number | "error";
  title: string | null;
  description: string | null;
  bodyChars: number;
  verdict: "ok" | "incomplete" | "broken";
  notes: string[];
};

/** Router config se auto-generate — naya page banate hi yahan khud aa jata hai. */
function usePublicRoutes(): string[] {
  const router = useRouter();
  return useMemo(() => {
    const ids = Object.keys(router.routesById ?? {});
    return ids
      .filter((id) => id.startsWith("/"))
      .map((id) => id.replace(/\/$/, "") || "/")
      .filter((path) => !path.startsWith("/app"))
      .filter((path) => !path.startsWith("/founder"))
      .filter((path) => !path.includes("$"))
      .filter((path) => !path.includes("_"))
      .filter((path) => path !== "/pages")
      .filter((path, i, arr) => arr.indexOf(path) === i)
      .sort((a, b) => (a === "/" ? -1 : b === "/" ? 1 : a.localeCompare(b)));
  }, [router]);
}

async function scanRoute(path: string): Promise<ScanResult> {
  const notes: string[] = [];
  try {
    const res = await fetch(path, { headers: { accept: "text/html" } });
    const html = await res.text();
    const title = /<title[^>]*>([^<]*)<\/title>/i.exec(html)?.[1]?.trim() ?? null;
    const description =
      /<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']/i.exec(html)?.[1] ??
      null;
    const body = html
      .replace(/<script[\s\S]*?<\/script>/gi, "")
      .replace(/<style[\s\S]*?<\/style>/gi, "")
      .replace(/<[^>]+>/g, " ")
      .replace(/\s+/g, " ")
      .trim();

    if (!res.ok) notes.push(`HTTP ${res.status}`);
    if (!title) notes.push("missing <title>");
    if (!description) notes.push("missing meta description");
    if (body.length < 400) notes.push("page looks blank / thin");
    if (/lorem ipsum|placeholder|coming soon soon|TODO/i.test(body))
      notes.push("placeholder copy found");

    const verdict: ScanResult["verdict"] = !res.ok
      ? "broken"
      : notes.length > 0
        ? "incomplete"
        : "ok";

    return { status: res.status, title, description, bodyChars: body.length, verdict, notes };
  } catch (error) {
    return {
      status: "error",
      title: null,
      description: null,
      bodyChars: 0,
      verdict: "broken",
      notes: [error instanceof Error ? error.message : "request failed"],
    };
  }
}

function FounderPublicPreview() {
  const paths = usePublicRoutes();
  const [allowed, setAllowed] = useState<boolean | null>(null);
  const [device, setDevice] = useState<Device>(DEVICES[2]!);
  const [results, setResults] = useState<Record<string, ScanResult>>({});
  const [scanning, setScanning] = useState(false);
  const [copied, setCopied] = useState<string | null>(null);

  useEffect(() => {
    setAllowed(founderPreviewFromUrl() || founderPreviewEnabled());
  }, []);

  async function scanAll() {
    setScanning(true);
    for (const path of paths) {
      const result = await scanRoute(path);
      setResults((prev) => ({ ...prev, [path]: result }));
    }
    setScanning(false);
  }

  function openAsVisitor(path: string) {
    setVisitorPreview(true);
    const url = `${path}${path.includes("?") ? "&" : "?"}preview=public`;
    window.open(url, "_blank", "noopener");
  }

  async function copyLink(path: string) {
    const url = `${window.location.origin}${path}`;
    try {
      await navigator.clipboard.writeText(url);
      setCopied(path);
      window.setTimeout(() => setCopied(null), 1600);
    } catch {
      /* clipboard blocked */
    }
  }

  if (allowed === null) return <div className="min-h-screen bg-background" aria-hidden />;

  if (!allowed) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-background px-6">
        <div className="max-w-md text-center">
          <h1 className="ax-heading text-foreground">Page not found</h1>
          <p className="ax-body mt-ax-2">
            This address does not exist.{" "}
            <a href="/" className="underline">
              Back to home
            </a>
          </p>
        </div>
      </main>
    );
  }

  const counts = {
    ok: Object.values(results).filter((r) => r.verdict === "ok").length,
    incomplete: Object.values(results).filter((r) => r.verdict === "incomplete").length,
    broken: Object.values(results).filter((r) => r.verdict === "broken").length,
  };

  return (
    <main className="min-h-screen bg-background">
      <div className="mx-auto w-full max-w-6xl px-6 py-10 md:px-10 md:py-14">
        <p className="ax-eyebrow">Founder only</p>
        <h1 className="ax-display mt-3 text-foreground">Public preview</h1>
        <p className="ax-body mt-ax-3 max-w-2xl">
          Every public route, exactly as an unknown visitor sees it — no login, no session
          UI. The list is generated from the router, so a new page appears here the moment
          it exists.
        </p>

        <div className="mt-ax-5 flex flex-wrap items-center gap-2">
          {DEVICES.map((d) => (
            <button
              key={d.id}
              type="button"
              onClick={() => setDevice(d)}
              className={`ax-press rounded-full border px-3 py-1.5 text-sm font-semibold transition-colors ${
                device.id === d.id
                  ? "border-primary bg-primary text-primary-foreground"
                  : "border-border text-muted-foreground hover:text-foreground"
              }`}
            >
              {d.label}
            </button>
          ))}

          <button
            type="button"
            onClick={() => void scanAll()}
            disabled={scanning}
            className="ax-press rounded-full border border-border px-3 py-1.5 text-sm font-semibold text-foreground disabled:opacity-60"
          >
            {scanning ? "Scanning…" : "Scan all"}
          </button>

          <button
            type="button"
            onClick={() => openAsVisitor("/")}
            className="ax-press rounded-full bg-secondary px-3 py-1.5 text-sm font-semibold text-foreground"
          >
            View as visitor
          </button>

          <span className="ax-caption text-muted-foreground">
            {paths.length} public routes · {counts.ok} ok · {counts.incomplete} incomplete ·{" "}
            {counts.broken} broken
          </span>
        </div>

        <div className="mt-ax-6 grid gap-ax-5 md:grid-cols-2">
          {paths.map((path) => {
            const r = results[path];
            const badge =
              r?.verdict === "broken"
                ? "border-destructive/60 bg-destructive/10 text-destructive"
                : r?.verdict === "incomplete"
                  ? "border-destructive/50 bg-destructive/10 text-destructive"
                  : r
                    ? "border-border bg-secondary text-foreground"
                    : "border-border bg-secondary/60 text-muted-foreground";

            return (
              <section
                key={path}
                className="overflow-hidden rounded-2xl border border-border bg-card"
              >
                <header className="flex flex-wrap items-center justify-between gap-2 border-b border-border px-4 py-3">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold text-foreground">
                      {r?.title ?? path}
                    </p>
                    <p className="ax-caption truncate text-muted-foreground">{path}</p>
                  </div>
                  <span
                    className={`rounded-full border px-2 py-0.5 text-[11px] font-semibold ${badge}`}
                  >
                    {r ? `${r.status} · ${r.verdict}` : "not scanned"}
                  </span>
                </header>

                <div className="bg-surface-2 p-3">
                  <div className="mx-auto overflow-hidden rounded-xl border border-border bg-background">
                    <iframe
                      title={`Preview ${path}`}
                      src={`${path}?preview=public`}
                      loading="lazy"
                      className="block origin-top-left border-0"
                      style={{
                        width: device.width,
                        height: 900,
                        transform: `scale(${Math.min(1, 520 / device.width)})`,
                        transformOrigin: "top left",
                        marginBottom: 900 * Math.min(1, 520 / device.width) - 900,
                      }}
                    />
                  </div>
                </div>

                {r && r.notes.length > 0 && (
                  <ul className="border-t border-border px-4 py-3">
                    {r.notes.map((n) => (
                      <li key={n} className="ax-caption text-destructive">
                        • {n}
                      </li>
                    ))}
                  </ul>
                )}

                <footer className="flex items-center gap-2 border-t border-border px-4 py-3">
                  <button
                    type="button"
                    onClick={() => openAsVisitor(path)}
                    className="ax-press rounded-full bg-primary px-3 py-1.5 text-sm font-semibold text-primary-foreground"
                  >
                    Open as visitor
                  </button>
                  <button
                    type="button"
                    onClick={() => void copyLink(path)}
                    className="ax-press rounded-full border border-border px-3 py-1.5 text-sm font-semibold text-muted-foreground hover:text-foreground"
                  >
                    {copied === path ? "Copied" : "Copy link"}
                  </button>
                </footer>
              </section>
            );
          })}
        </div>

        <p className="mt-ax-6 ax-caption text-muted-foreground">
          <a href="/pages" className="underline">
            Full page map
          </a>{" "}
          ·{" "}
          <a href="/" className="underline">
            Back to home
          </a>
        </p>
      </div>
    </main>
  );
}
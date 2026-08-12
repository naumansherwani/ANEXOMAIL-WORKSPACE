import { useRouter } from "@tanstack/react-router";
import { ChevronLeft, ChevronRight, Crown, Eye, EyeOff, Monitor, X } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import { founderPreviewFromUrl, setFounderPreview } from "@/lib/founder-preview";
import { setVisitorPreview, visitorPreviewEnabled } from "@/lib/visitor-preview";

/**
 * FOUNDER PREVIEW TOP BAR (founder-only).
 *
 * Sirf us device par dikhta hai jahan `?founder=1` ya localStorage key set ho —
 * awam ke liye poori tarah invisible. Ye sirf navigation + render layer hai:
 * koi session mint nahi karta, koi data fake nahi karta.
 */

const WIDTHS = [
  { id: "off", label: "Full", width: 0 },
  { id: "mobile", label: "390", width: 390 },
  { id: "tablet", label: "768", width: 768 },
  { id: "desktop", label: "1440", width: 1440 },
] as const;

function useAllRoutes(): { public: string[]; app: string[] } {
  const router = useRouter();
  return useMemo(() => {
    const paths = Object.keys(router.routesById ?? {})
      .filter((id) => id.startsWith("/"))
      .map((id) =>
        id
          .split("/")
          .filter((seg) => !seg.startsWith("_"))
          .map((seg) => (seg.endsWith("_") ? seg.slice(0, -1) : seg))
          .join("/"),
      )
      .map((p) => p.replace(/\/$/, "") || "/")
      .filter((p) => !p.includes("$"))
      .filter((p, i, arr) => arr.indexOf(p) === i);

    const sort = (a: string, b: string) =>
      a === "/" ? -1 : b === "/" ? 1 : a.localeCompare(b);

    return {
      public: paths.filter((p) => !p.startsWith("/app")).sort(sort),
      app: paths.filter((p) => p.startsWith("/app")).sort(sort),
    };
  }, [router]);
}

export function FounderBar() {
  const routes = useAllRoutes();
  const [on, setOn] = useState(false);
  const [collapsed, setCollapsed] = useState(false);
  const [visitor, setVisitor] = useState(false);
  const [width, setWidth] = useState<(typeof WIDTHS)[number]["id"]>("off");

  useEffect(() => {
    setOn(founderPreviewFromUrl());
    setVisitor(visitorPreviewEnabled());
  }, []);

  // Device switcher — asli page par width clamp, iframe ke bina.
  useEffect(() => {
    if (typeof document === "undefined") return;
    const body = document.body;
    const px = WIDTHS.find((w) => w.id === width)?.width ?? 0;
    if (!on || !px) {
      body.style.maxWidth = "";
      body.style.margin = "";
      body.style.borderInline = "";
      return;
    }
    body.style.maxWidth = `${px}px`;
    body.style.margin = "0 auto";
    body.style.borderInline = "1px solid hsl(var(--border))";
  }, [on, width]);

  // Bar ko jagah do, warna page ke top par baith jata hai.
  useEffect(() => {
    if (typeof document === "undefined") return;
    document.documentElement.style.scrollPaddingTop = on ? "44px" : "";
    document.body.style.paddingTop = on && !collapsed ? "36px" : "";
  }, [on, collapsed]);

  if (!on) return null;

  const all = [...routes.public, ...routes.app];
  const current =
    typeof window === "undefined" ? "/" : window.location.pathname.replace(/\/$/, "") || "/";
  const index = all.indexOf(current);

  const go = (path: string) => {
    if (typeof window === "undefined") return;
    const url = new URL(path, window.location.origin);
    url.searchParams.set("founder", "1");
    if (visitor) url.searchParams.set("preview", "public");
    window.location.assign(url.toString());
  };

  const toggleVisitor = () => {
    const next = !visitor;
    setVisitorPreview(next);
    setVisitor(next);
    if (typeof window === "undefined") return;
    const url = new URL(window.location.href);
    url.searchParams.set("preview", next ? "public" : "off");
    url.searchParams.set("founder", "1");
    window.location.assign(url.toString());
  };

  if (collapsed) {
    return (
      <button
        type="button"
        onClick={() => setCollapsed(false)}
        className="ax-press fixed left-3 top-3 z-[120] inline-flex items-center gap-1.5 rounded-full border border-border bg-secondary/95 px-2.5 py-1 text-[10px] font-bold tracking-wide text-foreground shadow-elev-1 backdrop-blur"
      >
        <Crown className="size-3" /> FOUNDER
      </button>
    );
  }

  return (
    <div className="fixed inset-x-0 top-0 z-[120] border-b border-border bg-secondary/95 backdrop-blur">
      <div className="flex h-9 items-center gap-1.5 overflow-x-auto px-2 sm:gap-2 sm:px-3">
        <span className="inline-flex shrink-0 items-center gap-1 rounded-full border border-border px-2 py-0.5 text-[10px] font-bold tracking-wide text-foreground">
          <Crown className="size-3" /> FOUNDER
        </span>

        <button
          type="button"
          aria-label="Previous page"
          disabled={index <= 0}
          onClick={() => go(all[index - 1]!)}
          className="ax-press ax-focus shrink-0 rounded-md border border-border p-1 text-muted-foreground disabled:opacity-40"
        >
          <ChevronLeft className="size-3.5" />
        </button>

        <select
          aria-label="Go to page"
          value={index >= 0 ? current : ""}
          onChange={(e) => go(e.target.value)}
          className="ax-focus min-w-0 max-w-[10rem] shrink rounded-md border border-border bg-card px-2 py-1 text-[11px] font-semibold text-foreground sm:max-w-[18rem]"
        >
          {index < 0 && <option value="">{current}</option>}
          <optgroup label="Public">
            {routes.public.map((p) => (
              <option key={p} value={p}>
                {p}
              </option>
            ))}
          </optgroup>
          <optgroup label="Workspace">
            {routes.app.map((p) => (
              <option key={p} value={p}>
                {p}
              </option>
            ))}
          </optgroup>
        </select>

        <button
          type="button"
          aria-label="Next page"
          disabled={index < 0 || index >= all.length - 1}
          onClick={() => go(all[index + 1]!)}
          className="ax-press ax-focus shrink-0 rounded-md border border-border p-1 text-muted-foreground disabled:opacity-40"
        >
          <ChevronRight className="size-3.5" />
        </button>

        <span className="hidden shrink-0 items-center gap-1 text-[10px] font-semibold text-muted-foreground sm:inline-flex">
          <Monitor className="size-3" />
        </span>
        <div className="flex shrink-0 items-center gap-0.5 rounded-md border border-border p-0.5">
          {WIDTHS.map((w) => (
            <button
              key={w.id}
              type="button"
              onClick={() => setWidth(w.id)}
              className={`ax-press rounded px-1.5 py-0.5 text-[10px] font-bold ${
                width === w.id
                  ? "bg-primary text-primary-foreground"
                  : "text-muted-foreground hover:text-foreground"
              }`}
            >
              {w.label}
            </button>
          ))}
        </div>

        <button
          type="button"
          onClick={toggleVisitor}
          className={`ax-press ax-focus inline-flex shrink-0 items-center gap-1 rounded-md border px-2 py-1 text-[10px] font-bold ${
            visitor
              ? "border-primary bg-primary/15 text-foreground"
              : "border-border text-muted-foreground hover:text-foreground"
          }`}
        >
          {visitor ? <Eye className="size-3" /> : <EyeOff className="size-3" />}
          <span className="hidden sm:inline">{visitor ? "VISITOR" : "FOUNDER VIEW"}</span>
        </button>

        <a
          href="/founder/preview?founder=1"
          className="ax-press ax-focus hidden shrink-0 rounded-md border border-border px-2 py-1 text-[10px] font-bold text-muted-foreground hover:text-foreground md:inline-block"
        >
          PAGE INDEX
        </a>

        <div className="ml-auto flex shrink-0 items-center gap-1">
          <button
            type="button"
            onClick={() => setCollapsed(true)}
            className="ax-press ax-focus rounded-md border border-border px-2 py-1 text-[10px] font-bold text-muted-foreground"
          >
            HIDE
          </button>
          <button
            type="button"
            aria-label="Turn founder preview off"
            onClick={() => {
              setFounderPreview(false);
              setVisitorPreview(false);
              setOn(false);
              if (typeof window !== "undefined") window.location.assign("/");
            }}
            className="ax-press ax-focus rounded-md border border-border p-1 text-muted-foreground"
          >
            <X className="size-3.5" />
          </button>
        </div>
      </div>
    </div>
  );
}
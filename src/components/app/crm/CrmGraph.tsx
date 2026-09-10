import { useMemo } from "react";

import { useLocale } from "@/lib/i18n";
import type { CrmLive } from "@/lib/crm";

const COL: Record<string, number> = {
  person: 0,
  deal: 1,
  mail: 2,
  work: 2,
  calendar: 2,
};

export function CrmGraph({
  graph,
}: {
  graph: CrmLive["graph"];
}) {
  const { t } = useLocale();
  const layout = useMemo(() => {
    const byKind = new Map<string, CrmLive["graph"]["nodes"]>();
    for (const node of graph.nodes.slice(0, 36)) {
      const list = byKind.get(node.kind) ?? [];
      list.push(node);
      byKind.set(node.kind, list);
    }
    const width = 720;
    const height = 280;
    const pos = new Map<string, { x: number; y: number }>();
    const columns = ["person", "deal", "mail"];
    columns.forEach((kind, col) => {
      const nodes = [
        ...(byKind.get(kind) ?? []),
        ...(kind === "mail" ? [...(byKind.get("work") ?? []), ...(byKind.get("calendar") ?? [])] : []),
      ].slice(0, 12);
      nodes.forEach((node, i) => {
        const x = 90 + col * ((width - 180) / 2);
        const y = 28 + i * ((height - 40) / Math.max(nodes.length, 1));
        pos.set(node.id, { x, y });
      });
    });
    for (const node of graph.nodes) {
      if (pos.has(node.id)) continue;
      const col = COL[node.kind] ?? 1;
      pos.set(node.id, { x: 90 + col * 270, y: height - 24 });
    }
    return { width, height, pos };
  }, [graph.nodes]);

  if (graph.edges.length === 0) {
    return (
      <p className="ax-caption text-muted-foreground">
        {t("Links appear when mail, a deal, a meeting or a work task names the same person.")}
      </p>
    );
  }

  const shown = graph.nodes.filter((n) => layout.pos.has(n.id));

  return (
    <svg
      viewBox={`0 0 ${layout.width} ${layout.height}`}
      className="h-64 w-full"
      role="img"
      aria-label={t("Recorded links")}
    >
      {graph.edges.slice(0, 48).map((e, i) => {
        const a = layout.pos.get(e.from);
        const b = layout.pos.get(e.to);
        if (!a || !b) return null;
        return (
          <line
            key={`${e.from}-${e.to}-${i}`}
            x1={a.x}
            y1={a.y}
            x2={b.x}
            y2={b.y}
            className="stroke-border"
            strokeWidth="1"
          />
        );
      })}
      {shown.map((n) => {
        const p = layout.pos.get(n.id);
        if (!p) return null;
        return (
          <g key={n.id}>
            <circle cx={p.x} cy={p.y} r="4.5" className="fill-foreground" />
            <text x={p.x + 8} y={p.y + 3} className="fill-muted-foreground" style={{ fontSize: "9px" }}>
              {(n.label || n.kind).slice(0, 22)}
            </text>
          </g>
        );
      })}
    </svg>
  );
}

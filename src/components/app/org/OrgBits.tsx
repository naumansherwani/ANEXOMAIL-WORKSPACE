import { ShieldCheck, ShieldAlert, ShieldX } from "lucide-react";

import { Chip } from "@/components/app/crm/CrmBits";
import type { GraphEdge, GraphNode, ProofTile } from "@/lib/org";
import { cn } from "@/lib/utils";

export { Chip, CrmStat as OrgStat, ScoreBar, SectionTitle } from "@/components/app/crm/CrmBits";

/** Ownership Proof Wall tile — colour never carries the meaning alone. */
export function ProofTileCard({ tile }: { tile: ProofTile }) {
  const Icon = tile.state === "ok" ? ShieldCheck : tile.state === "warn" ? ShieldAlert : ShieldX;
  return (
    <div
      className={cn(
        "rounded-2xl border p-ax-4",
        tile.state === "ok" && "border-success/40 bg-success/5",
        tile.state === "warn" && "border-warning/40 bg-warning/5",
        tile.state === "fail" && "border-danger/40 bg-danger/5",
      )}
    >
      <div className="flex items-center gap-2">
        <Icon
          aria-hidden="true"
          className={cn(
            "size-4",
            tile.state === "ok" && "text-success",
            tile.state === "warn" && "text-warning",
            tile.state === "fail" && "text-danger",
          )}
        />
        <p className="text-[13px] font-bold text-foreground">{tile.key}</p>
        <Chip tone={tile.state === "ok" ? "good" : tile.state === "warn" ? "warn" : "bad"}>
          {tile.state === "ok" ? "green" : tile.state}
        </Chip>
      </div>
      <p className="ax-caption mt-2 text-muted-foreground">{tile.detail}</p>
    </div>
  );
}

/**
 * Live Org Graph — drawn from real mail traffic the server measured.
 * Pure SVG, no library: nodes on a ring, edge thickness = conversation weight.
 */
export function OrgGraphCanvas({
  nodes,
  edges,
  onSelect,
  selected,
}: {
  nodes: GraphNode[];
  edges: GraphEdge[];
  onSelect: (id: string) => void;
  selected: string | null;
}) {
  const size = 520;
  const r = size / 2 - 60;
  const center = size / 2;
  const points = new Map<string, { x: number; y: number }>();
  nodes.forEach((n, i) => {
    const angle = (i / Math.max(1, nodes.length)) * Math.PI * 2 - Math.PI / 2;
    points.set(n.id, { x: center + r * Math.cos(angle), y: center + r * Math.sin(angle) });
  });
  const maxWeight = Math.max(1, ...edges.map((e) => e.weight));

  return (
    <svg
      viewBox={`0 0 ${size} ${size}`}
      className="h-auto w-full"
      role="img"
      aria-label="Organisation communication graph"
    >
      {edges.map((e, i) => {
        const a = points.get(e.from);
        const b = points.get(e.to);
        if (!a || !b) return null;
        const active = selected === null || selected === e.from || selected === e.to;
        return (
          <line
            key={`${e.from}-${e.to}-${i}`}
            x1={a.x}
            y1={a.y}
            x2={b.x}
            y2={b.y}
            stroke="currentColor"
            className={active ? "text-foreground/35" : "text-foreground/8"}
            strokeWidth={0.6 + (e.weight / maxWeight) * 3}
          />
        );
      })}
      {nodes.map((n) => {
        const p = points.get(n.id);
        if (!p) return null;
        const active = selected === n.id;
        return (
          <g
            key={n.id}
            className="cursor-pointer"
            onClick={() => onSelect(n.id)}
            tabIndex={0}
            role="button"
            aria-label={`${n.label}${n.bottleneck ? " — bottleneck" : ""}`}
          >
            <circle
              cx={p.x}
              cy={p.y}
              r={10 + (n.centrality ?? 0) * 0.12}
              className={cn(
                n.bottleneck ? "fill-warning/70" : "fill-secondary",
                active ? "stroke-foreground" : "stroke-border",
              )}
              strokeWidth={active ? 2 : 1}
            />
            <text
              x={p.x}
              y={p.y + 26}
              textAnchor="middle"
              className="fill-current text-[9px] font-semibold text-muted-foreground"
            >
              {n.label.length > 16 ? `${n.label.slice(0, 15)}…` : n.label}
            </text>
          </g>
        );
      })}
    </svg>
  );
}
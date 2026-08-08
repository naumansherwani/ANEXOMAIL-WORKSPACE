import type { ReactNode } from "react";

import { initialsOf, RELATIONSHIP_LABEL, type Contact, type Relationship } from "@/lib/contacts";
import { cn } from "@/lib/utils";

/** Deterministic initials chip — no avatar service, no third-party pixel. */
export function Avatar({
  contact,
  size = "md",
}: {
  contact: Pick<Contact, "display_name" | "primary_address">;
  size?: "sm" | "md" | "lg";
}) {
  return (
    <span
      aria-hidden
      className={cn(
        "grid shrink-0 place-items-center rounded-full bg-secondary font-bold text-foreground",
        size === "sm" && "size-6 text-[10px]",
        size === "md" && "size-8 text-[11px]",
        size === "lg" && "size-12 text-sm",
      )}
    >
      {initialsOf(contact)}
    </span>
  );
}

const TONE: Record<Relationship, string> = {
  new: "text-steel",
  growing: "text-emerald-400",
  stable: "text-foreground",
  at_risk: "text-amber-400",
  dormant: "text-steel",
};

export function RelationshipChip({
  relationship,
  score,
}: {
  relationship: Relationship;
  score?: number | null;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full border border-border px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide",
        TONE[relationship],
      )}
    >
      {RELATIONSHIP_LABEL[relationship]}
      {typeof score === "number" && <span className="text-steel">{score}</span>}
    </span>
  );
}

export function Stat({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="rounded-md border border-border px-3 py-2">
      <p className="ax-caption text-steel">{label}</p>
      <p className="mt-0.5 text-sm font-bold text-foreground">{value}</p>
    </div>
  );
}

export function TagChip({
  name,
  onRemove,
}: {
  name: string;
  onRemove?: () => void;
}) {
  return (
    <span className="inline-flex items-center gap-1 rounded-full bg-secondary px-2 py-0.5 text-[10px] font-medium text-foreground">
      {name}
      {onRemove && (
        <button
          type="button"
          onClick={onRemove}
          aria-label={`Remove tag ${name}`}
          className="text-steel transition-colors hover:text-foreground"
        >
          ×
        </button>
      )}
    </span>
  );
}

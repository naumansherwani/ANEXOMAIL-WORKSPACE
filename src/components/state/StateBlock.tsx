import { AlertTriangle, CheckCircle2, RotateCcw } from "lucide-react";
import type { ReactNode } from "react";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

/**
 * State surfaces — Phase 4.
 * Honest states only: what happened, why, and the one next step.
 * No fake data, no dead ends, colour never carries the meaning alone.
 */

type Tone = "quiet" | "success" | "error";

const toneRing: Record<Tone, string> = {
  quiet: "border-border bg-secondary text-steel",
  success: "border-success/40 bg-success/10 text-success",
  error: "border-danger/40 bg-danger/10 text-danger",
};

export function StateBlock({
  icon,
  title,
  body,
  action,
  secondary,
  tone = "quiet",
  className,
  live = false,
}: {
  icon?: ReactNode;
  title: string;
  body: string;
  action?: ReactNode;
  secondary?: ReactNode;
  tone?: Tone;
  className?: string;
  live?: boolean;
}) {
  return (
    <div
      {...(live ? { role: "status", "aria-live": "polite" } : {})}
      className={cn(
        "ax-in flex h-full min-h-[16rem] flex-col items-center justify-center px-ax-6 py-ax-8 text-center",
        className,
      )}
    >
      {icon && (
        <span
          aria-hidden="true"
          className={cn(
            "mb-ax-4 flex size-11 items-center justify-center rounded-2xl border",
            toneRing[tone],
            tone === "success" && "ax-confirm",
          )}
        >
          {icon}
        </span>
      )}
      <h3 className="ax-heading text-foreground">{title}</h3>
      <p className="ax-body mt-ax-2 max-w-sm">{body}</p>
      {(action || secondary) && (
        <div className="mt-ax-5 flex flex-wrap items-center justify-center gap-ax-2">
          {action}
          {secondary}
        </div>
      )}
    </div>
  );
}

/** Something finished. One quiet confirmation, then the surface goes silent. */
export function SuccessState({
  title,
  body,
  action,
}: {
  title: string;
  body: string;
  action?: ReactNode;
}) {
  return (
    <StateBlock
      live
      tone="success"
      icon={<CheckCircle2 className="size-5" />}
      title={title}
      body={body}
      action={action}
    />
  );
}

/**
 * Something broke. Says what failed in plain language and always offers a
 * retry — an error screen is never a dead end.
 */
export function ErrorState({
  title = "That didn't go through",
  body,
  onRetry,
  retryLabel = "Try again",
  secondary,
}: {
  title?: string;
  body: string;
  onRetry?: () => void;
  retryLabel?: string;
  secondary?: ReactNode;
}) {
  return (
    <StateBlock
      live
      tone="error"
      icon={<AlertTriangle className="size-5" />}
      title={title}
      body={body}
      action={
        onRetry ? (
          <Button variant="outline" size="sm" className="ax-press ax-tap" onClick={onRetry}>
            <RotateCcw className="size-4" />
            <span>{retryLabel}</span>
          </Button>
        ) : undefined
      }
      secondary={secondary}
    />
  );
}
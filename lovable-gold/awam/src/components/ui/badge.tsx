import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "@/lib/utils";

const badgeVariants = cva(
  "ax-focus inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-[0.6875rem] font-semibold tracking-[0.02em] transition-colors",
  {
    variants: {
      variant: {
        default: "border-transparent bg-primary text-primary-foreground",
        secondary: "border-border bg-surface-2 text-steel",
        destructive: "border-transparent bg-destructive text-destructive-foreground",
        outline: "border-border text-foreground",
        // Ownership proof states — DKIM / SPF / DMARC / TLS.
        verified: "border-success/35 bg-success/12 text-success",
        pending: "border-warning/35 bg-warning/12 text-warning",
        failing: "border-danger/35 bg-danger/12 text-danger",
        // Signal — new, live, AI.
        signal: "border-cyan-accent/35 bg-cyan-accent/12 text-cyan-accent",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  },
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>, VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return <div className={cn(badgeVariants({ variant }), className)} {...props} />;
}

export { Badge, badgeVariants };

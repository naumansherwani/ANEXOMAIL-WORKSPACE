// Stand-ins for modules that need packages absent from the sandbox. Visual stand-ins only.
import * as React from "react";
import { cn } from "@/lib/utils";

export function Chip({ children, tone = "quiet" }: { children: React.ReactNode; tone?: "quiet" | "good" | "warn" | "bad" }) {
  return (
    <span
      className={cn(
        "ax-caption rounded-full border px-2 py-0.5 font-semibold",
        tone === "good" && "border-success/40 bg-success/10 text-success",
        tone === "warn" && "border-warning/40 bg-warning/10 text-warning",
        tone === "bad" && "border-danger/40 bg-danger/10 text-danger",
        tone === "quiet" && "border-border text-muted-foreground",
      )}
    >
      {children}
    </span>
  );
}
export function ErrorState({ title, body, onRetry }: { title?: string; body: string; onRetry?: () => void }) {
  return (
    <div className="ax-plane rounded-2xl p-5">
      <p className="font-bold">{title}</p>
      <p className="text-sm text-muted-foreground">{body}</p>
      {onRetry && <button onClick={onRetry}>Try again</button>}
    </div>
  );
}
const Pass = ({ children }: { children?: React.ReactNode }) => <div>{children}</div>;
export const AlertDialog = ({ open, children }: { open?: boolean; children?: React.ReactNode }) => (open ? <div role="alertdialog">{children}</div> : null);
export const AlertDialogContent = Pass;
export const AlertDialogHeader = Pass;
export const AlertDialogFooter = Pass;
export const AlertDialogTitle = Pass;
export const AlertDialogDescription = Pass;
export const AlertDialogAction = ({ children, onClick }: { children?: React.ReactNode; onClick?: () => void }) => <button onClick={onClick}>{children}</button>;
export const AlertDialogCancel = ({ children }: { children?: React.ReactNode }) => <button>{children}</button>;

// Sheet (Radix dialog) stand-in: same positioning classes as src/components/ui/sheet.tsx side="bottom".
export const Sheet = ({ open, onOpenChange, children }: { open?: boolean; onOpenChange?: (o: boolean) => void; children?: React.ReactNode }) =>
  open ? (
    <div data-sheet>
      <div className="fixed inset-0 z-50 bg-black/80" onClick={() => onOpenChange?.(false)} />
      {children}
    </div>
  ) : null;
export const SheetContent = ({ className, side = "bottom", children }: { className?: string; side?: string; children?: React.ReactNode }) => (
  <div role="dialog" className={cn("fixed z-50 gap-4 bg-background p-6 shadow-lg", side === "right" ? "inset-y-0 right-0 h-full w-3/4 border-l sm:max-w-sm" : "inset-x-0 bottom-0 border-t", className)}>
    {children}
  </div>
);
export const SheetDescription = ({ className, children }: { className?: string; children?: React.ReactNode }) => (
  <p className={cn("text-sm text-muted-foreground", className)}>{children}</p>
);
export const SheetHeader = ({ className, children }: { className?: string; children?: React.ReactNode }) => (
  <div className={cn("flex flex-col space-y-2 text-center sm:text-left", className)}>{children}</div>
);
export const SheetTitle = ({ className, children }: { className?: string; children?: React.ReactNode }) => (
  <h2 className={cn("text-lg font-semibold text-foreground", className)}>{children}</h2>
);

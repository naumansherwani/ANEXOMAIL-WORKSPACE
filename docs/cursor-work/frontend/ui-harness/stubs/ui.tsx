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

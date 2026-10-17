// Stand-ins for modules that need packages absent from the sandbox. Visual stand-ins only.
import * as React from "react";
import { cn } from "@/lib/utils";
import { buttonVariants } from "@/components/ui/button";

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
// AlertDialog stand-in: SAME class strings as src/components/ui/alert-dialog.tsx (minus Radix animation hooks), so the dialog looks as it will live.
const AdCtx = React.createContext<(o: boolean) => void>(() => {});
export const AlertDialog = ({ open, onOpenChange, children }: { open?: boolean; onOpenChange?: (o: boolean) => void; children?: React.ReactNode }) =>
  open ? <AdCtx.Provider value={onOpenChange ?? (() => {})}><div role="alertdialog" aria-modal="true">{children}</div></AdCtx.Provider> : null;
export const AlertDialogContent = ({ children }: { children?: React.ReactNode }) => (
  <>
    <div className="fixed inset-0 z-50 bg-black/80" />
    <div className="fixed left-[50%] top-[50%] z-50 grid w-full max-w-lg translate-x-[-50%] translate-y-[-50%] gap-4 border bg-background p-6 shadow-lg duration-200 sm:rounded-lg">{children}</div>
  </>
);
export const AlertDialogHeader = ({ children }: { children?: React.ReactNode }) => <div className="flex flex-col space-y-2 text-center sm:text-left">{children}</div>;
export const AlertDialogFooter = ({ children }: { children?: React.ReactNode }) => <div className="flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2">{children}</div>;
export const AlertDialogTitle = ({ children }: { children?: React.ReactNode }) => <h2 className="text-lg font-semibold">{children}</h2>;
export const AlertDialogDescription = ({ children }: { children?: React.ReactNode }) => <p className="text-sm text-muted-foreground">{children}</p>;
export const AlertDialogAction = ({ children, onClick, className }: { children?: React.ReactNode; onClick?: () => void; className?: string }) => {
  const close = React.useContext(AdCtx);
  return <button className={cn(buttonVariants(), className)} onClick={() => { onClick?.(); close(false); }}>{children}</button>;
};
export const AlertDialogCancel = ({ children }: { children?: React.ReactNode }) => {
  const close = React.useContext(AdCtx);
  return <button className={cn(buttonVariants({ variant: "outline" }), "mt-2 sm:mt-0")} onClick={() => close(false)}>{children}</button>;
};

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

// Switch (Radix) stand-in: same size/shape as src/components/ui/switch.tsx (h-5 w-9 track, h-4 w-4 thumb).
export const Switch = ({ checked, onCheckedChange }: { checked?: boolean; onCheckedChange?: (v: boolean) => void }) => (
  <button
    type="button"
    role="switch"
    aria-checked={Boolean(checked)}
    onClick={() => onCheckedChange?.(!checked)}
    className={cn("peer inline-flex h-5 w-9 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent shadow-sm transition-colors", checked ? "bg-primary" : "bg-input")}
  >
    <span className={cn("pointer-events-none block h-4 w-4 rounded-full bg-background shadow-lg ring-0 transition-transform", checked ? "translate-x-4" : "translate-x-0")} />
  </button>
);

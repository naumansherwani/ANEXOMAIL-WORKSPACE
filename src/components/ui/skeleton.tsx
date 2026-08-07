import { cn } from "@/lib/utils";

function Skeleton({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div aria-hidden="true" className={cn("ax-shimmer rounded-md", className)} {...props} />
  );
}

export { Skeleton };

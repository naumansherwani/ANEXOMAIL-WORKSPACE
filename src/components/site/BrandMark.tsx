import { Mail } from "lucide-react";

export function BrandMark({ compact = false }: { compact?: boolean }) {
  return (
    <span className="flex items-center gap-2.5">
      <span className="flex size-8 items-center justify-center rounded-lg bg-primary text-primary-foreground shadow-elev-1">
        <Mail className="size-4" strokeWidth={2.5} />
      </span>
      {!compact && (
        <span className="text-[15px] leading-none font-extrabold tracking-tight whitespace-nowrap text-foreground">
          ANEXO<span className="text-muted-foreground">MAIL</span>
        </span>
      )}
    </span>
  );
}

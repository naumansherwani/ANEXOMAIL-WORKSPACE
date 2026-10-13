import { Label } from "@/components/ui/label";
import { ANEXOMAIL_DOMAIN, anexomailAddress, anexomailLocalPart } from "@/lib/anexomail-address";

/**
 * ANEXOMAIL identity: user types only the name. @anexomail.com is printed,
 * locked, mandatory. Typed letters are dark on a light field.
 */
export function AnexoMailField({
  id = "email",
  label = "Email",
  value,
  onChange,
  autoComplete = "username",
  autoFocus = false,
  required = true,
}: {
  id?: string;
  label?: string | null;
  value: string;
  onChange: (local: string) => void;
  autoComplete?: string;
  autoFocus?: boolean;
  required?: boolean;
}) {
  const local = anexomailLocalPart(value);
  const mailbox = anexomailAddress(local);

  return (
    <div className="space-y-1.5">
      {label ? (
        <Label htmlFor={id} className="text-[13px] font-semibold text-foreground">
          {label}
        </Label>
      ) : null}
      <input type="hidden" name="email" value={mailbox} autoComplete={autoComplete} readOnly />
      <div className="flex h-10 overflow-hidden rounded-md border border-border bg-[#F9FAFB] ring-offset-background focus-within:ring-1 focus-within:ring-ring">
        <input
          id={id}
          type="text"
          inputMode="email"
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          autoFocus={autoFocus}
          required={required}
          autoComplete={autoComplete}
          value={local}
          placeholder="yourname"
          aria-label={`${label || "Email"} (anexomail.com is already set)`}
          onChange={(e) => onChange(anexomailLocalPart(e.target.value))}
          className="min-w-0 flex-1 bg-transparent px-3 text-[15px] font-semibold text-[#0B1220] outline-none placeholder:font-normal placeholder:text-[#6B7280]"
        />
        <span
          aria-hidden
          className="flex shrink-0 items-center border-l border-[#E5E7EB] bg-[#E5E7EB] px-3 text-[15px] font-semibold text-[#0B1220] select-none"
        >
          @{ANEXOMAIL_DOMAIN}
        </span>
      </div>
    </div>
  );
}

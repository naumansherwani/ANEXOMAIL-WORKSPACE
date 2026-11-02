import { useEffect, useMemo, useState } from "react";

import { CountryPicker } from "@/components/auth/CountryPicker";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { countryList, filterBlocked, toE164 } from "@/lib/countries";
import { getPolicy } from "@/lib/signx";

export type Contact = { country_iso2: string; national: string };

/** Country (required) + mobile number (optional here; more numbers later in Settings). Blocked countries are not in the list. */
export function ContactFields({ value, onChange, locale = "en" }: { value: Contact; onChange: (c: Contact) => void; locale?: string }) {
  const [blocked, setBlocked] = useState<string[]>(["AF", "IL", "KP"]);
  useEffect(() => {
    let live = true;
    getPolicy()
      .then((p) => live && setBlocked(p.blocked_countries))
      .catch(() => undefined); // the built-in list already holds the same three
    return () => {
      live = false;
    };
  }, []);
  const list = useMemo(() => filterBlocked(countryList(locale), blocked), [locale, blocked]);
  const current = list.find((c) => c.iso2 === value.country_iso2);
  const e164 = current ? toE164(current.dial, value.national) : null;

  return (
    <div className="space-y-ax-3">
      <CountryPicker list={list} value={value.country_iso2} onChange={(iso2) => onChange({ ...value, country_iso2: iso2 })} />
      <div className="space-y-1.5">
        <Label htmlFor="signup-mobile" className="text-[13px] font-semibold text-foreground">
          Mobile number <span className="font-normal text-muted-foreground">(optional)</span>
        </Label>
        <div className="flex gap-2">
          <span className="flex h-10 min-w-[4.5rem] items-center justify-center rounded-md border border-border bg-muted px-3 text-sm text-muted-foreground" aria-hidden="true">
            {current ? `+${current.dial}` : "+"}
          </span>
          <Input
            id="signup-mobile"
            type="tel"
            inputMode="tel"
            autoComplete="tel-national"
            placeholder="300 1234567"
            value={value.national}
            onChange={(e) => onChange({ ...value, national: e.target.value })}
            disabled={!current}
          />
        </div>
        {value.national.trim() !== "" && !e164 && <p className="ax-caption text-destructive">Enter the number without the country code.</p>}
        <p className="ax-caption text-muted-foreground">You can keep up to 5 numbers. Sign-in by SMS is not live yet.</p>
      </div>
    </div>
  );
}

export function contactToE164(c: Contact, locale = "en"): string | null {
  const cur = countryList(locale).find((x) => x.iso2 === c.country_iso2);
  return cur && c.national.trim() ? toE164(cur.dial, c.national) : null;
}

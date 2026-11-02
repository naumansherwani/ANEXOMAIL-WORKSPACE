import { useEffect, useId, useMemo, useRef, useState } from "react";
import { ChevronDown } from "lucide-react";

import { Label } from "@/components/ui/label";
import type { Country } from "@/lib/countries";
import { cn } from "@/lib/utils";

/** Search + first-letter filter: typing "P" shows the countries that START with P first, then the ones that merely contain it. Also matches ISO code (PK) and calling code (+92 / 92). */
export function rankCountries(list: Country[], query: string): Country[] {
  const q = query.trim().toLowerCase().replace(/^\+/, "");
  if (!q) return list;
  const starts: Country[] = [];
  const word: Country[] = [];
  const has: Country[] = [];
  for (const c of list) {
    const n = c.name.toLowerCase();
    if (n.startsWith(q) || c.iso2.toLowerCase() === q) starts.push(c);
    else if (n.split(/[\s(),-]+/).some((w) => w.startsWith(q))) word.push(c);
    else if (n.includes(q) || c.dial.startsWith(q)) has.push(c);
  }
  return [...starts, ...word, ...has];
}

export function CountryPicker({
  list,
  value,
  onChange,
  id = "signup-country",
  label = "Country",
}: {
  list: Country[];
  value: string;
  onChange: (iso2: string) => void;
  id?: string;
  label?: string;
}) {
  const uid = useId();
  const listId = `${uid}-list`;
  const current = list.find((c) => c.iso2 === value);
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [active, setActive] = useState(0);
  const box = useRef<HTMLDivElement>(null);
  const items = useMemo(() => rankCountries(list, query), [list, query]);

  useEffect(() => setActive(0), [query, open]);
  useEffect(() => {
    if (!open) return;
    const off = (e: MouseEvent) => {
      if (box.current && !box.current.contains(e.target as Node)) {
        setOpen(false);
        setQuery("");
      }
    };
    document.addEventListener("mousedown", off);
    return () => document.removeEventListener("mousedown", off);
  }, [open]);
  useEffect(() => {
    if (open) document.getElementById(`${uid}-opt-${active}`)?.scrollIntoView({ block: "nearest" });
  }, [active, open, uid]);

  const pick = (c: Country) => {
    onChange(c.iso2);
    setOpen(false);
    setQuery("");
  };

  return (
    <div className="space-y-1.5" ref={box}>
      <Label htmlFor={id} className="text-[13px] font-semibold text-foreground">
        {label}
      </Label>
      <div className="relative">
        <input
          id={id}
          type="text"
          role="combobox"
          aria-expanded={open}
          aria-controls={listId}
          aria-autocomplete="list"
          aria-activedescendant={open && items[active] ? `${uid}-opt-${active}` : undefined}
          autoComplete="off"
          required
          className="flex h-10 w-full rounded-md border border-border bg-background px-3 pr-9 text-sm"
          placeholder={current ? `${current.flag} ${current.name} (+${current.dial})` : "Search your country"}
          value={open ? query : current ? `${current.flag} ${current.name} (+${current.dial})` : ""}
          onFocus={() => setOpen(true)}
          onChange={(e) => {
            setQuery(e.target.value);
            setOpen(true);
          }}
          onKeyDown={(e) => {
            if (e.key === "ArrowDown") {
              e.preventDefault();
              setOpen(true);
              setActive((a) => Math.min(a + 1, Math.max(items.length - 1, 0)));
            } else if (e.key === "ArrowUp") {
              e.preventDefault();
              setActive((a) => Math.max(a - 1, 0));
            } else if (e.key === "Enter" && open && items[active]) {
              e.preventDefault();
              pick(items[active]!);
            } else if (e.key === "Escape") {
              setOpen(false);
              setQuery("");
            }
          }}
        />
        <ChevronDown className="pointer-events-none absolute right-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" aria-hidden="true" />
        {open && (
          <ul
            id={listId}
            role="listbox"
            className="absolute z-30 mt-1 max-h-60 w-full overflow-auto rounded-md border border-border bg-popover py-1 text-sm shadow-xl"
          >
            {items.length === 0 && <li className="px-3 py-2 text-muted-foreground">No country found</li>}
            {items.map((c, i) => (
              <li
                key={c.iso2}
                id={`${uid}-opt-${i}`}
                role="option"
                aria-selected={c.iso2 === value}
                onMouseDown={(e) => {
                  e.preventDefault();
                  pick(c);
                }}
                onMouseEnter={() => setActive(i)}
                className={cn("flex cursor-pointer items-center gap-2 px-3 py-1.5", i === active && "bg-accent text-accent-foreground", c.iso2 === value && "font-semibold")}
              >
                <span aria-hidden="true">{c.flag}</span>
                <span className="flex-1">{c.name}</span>
                <span className="text-xs text-muted-foreground">+{c.dial}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

import { useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import {
  CalendarDays,
  CheckSquare,
  Inbox,
  Mail,
  Search,
  Shield,
  Users,
} from "lucide-react";

import {
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import { ADMIN_SECTIONS, MAIL_FOLDERS } from "@/lib/ia";

/**
 * Rule: Cmd+K is the whole product. Mail, people, calendar, work, admin —
 * one palette, no second app. Phase 2 wires navigation targets; data-backed
 * results (threads, people, events) attach in their own phases.
 */
export function CommandPalette({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const navigate = useNavigate();

  const go = (to: string) => {
    onOpenChange(false);
    void navigate({ to });
  };

  return (
    <CommandDialog open={open} onOpenChange={onOpenChange}>
      <CommandInput placeholder="Go to a folder, person, calendar, task or setting…" />
      <CommandList>
        <CommandEmpty>Nothing matches that yet.</CommandEmpty>

        <CommandGroup heading="Workspace">
          <CommandItem value="today" onSelect={() => go("/app")}>
            <Inbox className="size-4" />
            Today
          </CommandItem>
          <CommandItem value="people contacts" onSelect={() => go("/app/people")}>
            <Users className="size-4" />
            People
          </CommandItem>
          <CommandItem value="calendar" onSelect={() => go("/app/calendar")}>
            <CalendarDays className="size-4" />
            Calendar
          </CommandItem>
          <CommandItem value="work tasks notes" onSelect={() => go("/app/work")}>
            <CheckSquare className="size-4" />
            Work
          </CommandItem>
          <CommandItem value="search everything" onSelect={() => go("/app/search")}>
            <Search className="size-4" />
            Search everything
          </CommandItem>
        </CommandGroup>

        <CommandGroup heading="Mail">
          {MAIL_FOLDERS.map((f) => (
            <CommandItem
              key={f.id}
              value={`mail ${f.label}`}
              onSelect={() => go(`/app/mail/${f.id}`)}
            >
              <Mail className="size-4" />
              {f.label}
            </CommandItem>
          ))}
        </CommandGroup>

        <CommandGroup heading="Admin">
          {ADMIN_SECTIONS.map((s) => (
            <CommandItem
              key={s.to}
              value={`admin ${s.label} ${s.summary}`}
              onSelect={() => go(s.to)}
            >
              <Shield className="size-4" />
              {s.label}
              <span className="ml-auto text-xs text-muted-foreground">{s.summary}</span>
            </CommandItem>
          ))}
        </CommandGroup>
      </CommandList>
    </CommandDialog>
  );
}

/** Global Cmd+K / Ctrl+K listener. */
export function useCommandPalette() {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key.toLowerCase() === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setOpen((v) => !v);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  return { open, setOpen };
}
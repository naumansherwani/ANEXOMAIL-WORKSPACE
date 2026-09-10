import { useNavigate } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import {
  Building2,
  CalendarDays,
  CheckSquare,
  Inbox,
  KanbanSquare,
  Mail,
  MessageSquare,
  Search,
  Shield,
  UserCircle2,
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
import { useAuth } from "@/lib/auth";
import { useUniversalSearch } from "@/lib/contacts";
import { founderSurfaceAllowed } from "@/lib/host";
import { ADMIN_SECTIONS, MAIL_FOLDERS } from "@/lib/ia";
import {
  platformPlan,
  showAdmin,
  showChat,
  showCrm,
  showOrg,
  showWork,
} from "@/lib/plan-surface";

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
  const { session } = useAuth();
  const [term, setTerm] = useState("");
  const results = useUniversalSearch(term, open);
  const [founderHost] = useState(founderSurfaceAllowed);
  const plan = platformPlan(session?.user.workspace_plan, session?.user.ai_plan);
  const workOpen = founderHost || showWork(plan);
  const crmOpen = founderHost || showCrm(plan);
  const chatOpen = founderHost || showChat(plan);
  const orgOpen = founderHost || showOrg(plan);
  const adminOpen = showAdmin({
    founder: Boolean(session?.user.is_founder),
    founderHost,
  });

  const go = (to: string) => {
    onOpenChange(false);
    void navigate({ to });
  };

  const jump = (
    to: "/app/people" | "/app/mail/$folder/$threadId",
    options: Record<string, unknown>,
  ) => {
    onOpenChange(false);
    void navigate({ to, ...options } as never);
  };

  return (
    <CommandDialog open={open} onOpenChange={onOpenChange}>
      <CommandInput
        value={term}
        onValueChange={setTerm}
        placeholder="Jump to a person, company, thread, folder or setting…"
      />
      <CommandList>
        <CommandEmpty>Nothing matches that yet.</CommandEmpty>

        {(results.data?.people.length ?? 0) > 0 && (
          <CommandGroup heading="People">
            {results.data?.people.slice(0, 5).map((person) => (
              <CommandItem
                key={person.id}
                value={`person ${person.display_name ?? ""} ${person.primary_address}`}
                onSelect={() =>
                  jump("/app/people", {
                    search: { view: "people", id: person.id, q: "", filter: "all", tag: "" },
                  })
                }
              >
                <Users className="size-4" />
                {person.display_name || person.primary_address}
                <span className="ml-auto text-xs text-muted-foreground">
                  {person.company_name || person.primary_address}
                </span>
              </CommandItem>
            ))}
          </CommandGroup>
        )}

        {(results.data?.companies.length ?? 0) > 0 && (
          <CommandGroup heading="Companies">
            {results.data?.companies.slice(0, 4).map((company) => (
              <CommandItem
                key={company.domain}
                value={`company ${company.name ?? ""} ${company.domain}`}
                onSelect={() =>
                  jump("/app/people", {
                    search: {
                      view: "companies",
                      id: company.domain,
                      q: "",
                      filter: "all",
                      tag: "",
                    },
                  })
                }
              >
                <Building2 className="size-4" />
                {company.name || company.domain}
                <span className="ml-auto text-xs text-muted-foreground">
                  {company.people_count} people
                </span>
              </CommandItem>
            ))}
          </CommandGroup>
        )}

        {(results.data?.threads.length ?? 0) > 0 && (
          <CommandGroup heading="Threads">
            {results.data?.threads.slice(0, 5).map((thread) => (
              <CommandItem
                key={thread.id}
                value={`thread ${thread.subject} ${thread.from_address}`}
                onSelect={() =>
                  jump("/app/mail/$folder/$threadId", {
                    params: { folder: thread.folder || "inbox", threadId: thread.id },
                  })
                }
              >
                <Mail className="size-4" />
                {thread.subject || "(no subject)"}
                <span className="ml-auto text-xs text-muted-foreground">{thread.from_address}</span>
              </CommandItem>
            ))}
          </CommandGroup>
        )}

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
          {workOpen ? (
            <CommandItem value="work tasks notes" onSelect={() => go("/app/work")}>
              <CheckSquare className="size-4" />
              Work
            </CommandItem>
          ) : null}
          {crmOpen ? (
            <CommandItem value="crm leads pipeline deals" onSelect={() => go("/app/crm")}>
              <KanbanSquare className="size-4" />
              CRM
            </CommandItem>
          ) : null}
          {chatOpen ? (
            <CommandItem value="anexochat chat" onSelect={() => go("/app/chat")}>
              <MessageSquare className="size-4" />
              ANEXOChat
            </CommandItem>
          ) : null}
          {orgOpen ? (
            <CommandItem value="organisation org members" onSelect={() => go("/app/org")}>
              <Building2 className="size-4" />
              Organisation
            </CommandItem>
          ) : null}
          <CommandItem value="search everything" onSelect={() => go("/app/search")}>
            <Search className="size-4" />
            Search everything
          </CommandItem>
          <CommandItem
            value="account sessions devices sign out"
            onSelect={() => go("/app/account")}
          >
            <UserCircle2 className="size-4" />
            Account &amp; sessions
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

        {adminOpen ? (
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
        ) : null}
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

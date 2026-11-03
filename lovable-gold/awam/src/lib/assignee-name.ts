import { useAuth } from "@/lib/auth";
import { useOrgMembers } from "@/lib/org";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Shared-inbox owner label: the thread stores the owner's user id, people must see a name.
 * "You" for yourself, the member's display name (or e-mail) for a teammate, "Teammate" if the
 * member list is not available — never a raw id.
 */
export function useAssigneeName(): (id: string | null | undefined) => string {
  const { session } = useAuth();
  const members = useOrgMembers("active");
  const me = session?.user?.id;
  return (id) => {
    if (!id) return "";
    if (!UUID.test(id)) return id;
    if (id === me) return "You";
    const m = members.data?.members.find((x) => x.user_id === id);
    return m ? m.display_name?.trim() || m.email : "Teammate";
  };
}

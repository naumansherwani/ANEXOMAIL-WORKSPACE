// Asli ComposeStudio ke hooks ke nakli (sirf layout dekhne ke liye) — compose, mail, mail-predict, mail-identity, host ek hi file.
export type ComposeTone = "warm" | "direct" | "formal" | "short" | "apologetic";
export type DraftPayload = Record<string, unknown>;
const noop = () => undefined;
const mut = () => ({ mutate: noop, mutateAsync: async () => ({}), isPending: false, isError: false, data: undefined as undefined | { issues: { severity: string; message: string }[] } });
const h = () => location.hash;

export const applyVariables = (b: string, _v: Record<string, string>) => b;
export const findVariables = (b: string): string[] => [...b.matchAll(/\{\{(\w+)\}\}/g)].map((m) => m[1]!);
export const readingStats = (b: string) => ({ words: b.trim() ? b.trim().split(/\s+/).length : 0, seconds: 4, level: "easy" });
export const useTemplates = () => ({ data: { templates: [{ id: "t1", name: "Intro call", scope: "team", subject: "Quick intro", body: "Hi {{name}}," }] }, isError: false });
export const useSnippets = () => ({ data: { snippets: [{ id: "s1", shortcut: "/thanks", body: "Thanks!" }, { id: "s2", shortcut: "/meeting", body: "Can we meet?" }, { id: "s3", shortcut: "/sig", body: "— N" }] } });
export const useDraftVersions = (_id?: string) => ({ data: undefined as undefined | { versions: { id: string; saved_at: string; body: string }[] }, isError: false, isPending: false });
export const useSaveDraft = mut;
// Succeeds immediately so "after send" states (e.g. the Domains first-email card) can be photographed.
const mutOk = () => ({
  mutate: (_a?: unknown, o?: { onSuccess?: (r: unknown) => void }) => o?.onSuccess?.({ issues: [], id: "stub" }),
  mutateAsync: async () => ({}),
  isPending: false,
  isError: false,
  data: undefined as undefined | { issues: { severity: string; message: string }[] },
});
export const useSendConfidence = mutOk;
export const useScheduleSend = mutOk;
export const useLeoCompose = mut;
export const useAskJimmy = mut;
export const useCreateFollowUp = mut;

export const learnWritingPattern = async (_t: string) => undefined;
export const usePredictionController = (_o: unknown) => ({ ghost: "", insertion: "", accept: noop, dismiss: noop });

export const useIdentities = (_ok: boolean) => ({
  data: h().includes("oneid") ? { default: "you@acme-studio.com", identities: [] } : { default: "you@acme-studio.com", identities: [{ address: "you@acme-studio.com" }, { address: "sales@acme-studio.com" }, { address: "pro.buyer@anexomail.com" }] },
});
export const useSendMail = mut;
export const addressTone = (a: string | null | undefined) => (a ? { address: a, color: "#7c9cff" } : null);
export const isAiHost = () => h().includes("aihost");
export const isPublicMailHost = () => true;
export const founderSurfaceAllowed = () => false; // gate harness: the mail workspace host, never the founder host

// People / Calendar harness: relative time label used by ContactProfile, rails and timelines.
export const relativeTime = (iso: string | null | undefined) => {
  if (!iso) return "never";
  const m = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
  if (m < 60) return `${Math.max(m, 1)}m ago`;
  if (m < 1440) return `${Math.round(m / 60)}h ago`;
  return `${Math.round(m / 1440)}d ago`;
};

// Thread view harness (#thread): one HTML mail with a script + tracking pixel (must NOT run / load), one text reply.
export const formatBytes = (n: number) => `${Math.round(n / 1024)} KB`;
export const useThread = (_id?: string) => ({
  isPending: false,
  error: null,
  refetch: noop,
  data: {
    id: "t1",
    subject: "Quarterly numbers",
    status: "open",
    assignee: null,
    labels: [],
    snoozed_until: null,
    account_address: "you@acme-studio.com",
    messages: [
      {
        id: "m1", direction: "in", from_name: "Sara Khan", from_address: "sara@client.co.uk", to: ["you@acme-studio.com"], cc: ["ali@client.co.uk"],
        subject: "Quarterly numbers", body_text: "", sent_at: new Date(Date.now() - 3600e3).toISOString(), scheduled_at: null, attachments: [],
        body_html: '<div style="font-family:Arial"><h2 style="color:#0b5">Q3 summary</h2><p>Hi, numbers attached. <a href="https://example.com/report">Open report</a></p><img src="https://tracker.example.com/pixel.gif" width="1" height="1"><script>parent.document.body.setAttribute("data-pwned","1")</script><img src="x" onerror="parent.document.body.setAttribute(\'data-pwned\',\'2\')"><table border="1" style="width:900px"><tr><td>Revenue</td><td>£120k</td></tr></table></div>',
      },
      {
        id: "m2", direction: "out", from_name: null, from_address: "you@acme-studio.com", to: ["sara@client.co.uk"], cc: [],
        subject: "Re: Quarterly numbers", body_text: "Thanks Sara — looks great.", body_html: null, sent_at: new Date(Date.now() - 1800e3).toISOString(), scheduled_at: null, attachments: [],
      },
    ],
  },
});

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

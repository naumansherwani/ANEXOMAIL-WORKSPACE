// Thread view harness: header actions / insights / quote-in-chat are photographed elsewhere — here only their footprint.
export const ThreadHeaderActions = (_p: unknown) => (
  <div className="flex items-center gap-1.5 text-[12px] text-muted-foreground">
    {["Done", "Archive", "Meeting", "Label"].map((l) => (
      <span key={l} className="rounded-full border border-border px-2.5 py-1">{l}</span>
    ))}
  </div>
);
export const ThreadInsights = (_p: unknown) => (
  <div className="ax-plane rounded-2xl px-4 py-3 text-[12px] text-muted-foreground">Thread insight · Best time to send: 02:00</div>
);
export const QuoteInChat = (_p: unknown) => null;
export const measureMotion = (_a: string, _b: string) => () => undefined;

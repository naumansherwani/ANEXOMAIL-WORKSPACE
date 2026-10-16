// ComposeStudio stand-in: To / Subject / body / Send — only to test the OVERLAY container on phone/tablet.
export function ComposeStudio({ onSent }: { variant?: string; initialTo?: string; onSent?: () => void }) {
  return (
    <div className="flex min-h-0 flex-1 flex-col gap-3 p-4">
      <input className="h-11 w-full rounded-md border border-input bg-transparent px-3 text-[13px]" placeholder="To" />
      <input className="h-11 w-full rounded-md border border-input bg-transparent px-3 text-[13px]" placeholder="Subject" />
      <textarea className="min-h-[14rem] w-full flex-1 rounded-md border border-input bg-transparent p-3 text-[13px]" placeholder="Write your message" />
      <button type="button" onClick={onSent} className="ax-tap rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground">Send</button>
    </div>
  );
}

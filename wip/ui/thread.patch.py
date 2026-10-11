import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()
pairs = [
 ('import { ThreadSkeleton } from "@/components/state/Skeletons";',
  'import { AddressChip } from "@/components/app/mail/AddressChip";\nimport { ThreadSkeleton } from "@/components/state/Skeletons";'),
 ('''          {thread.account_address && (
            <p className="truncate text-[11px] text-muted-foreground">
              {thread.account_address}
              {thread.assignee ? ` · ${thread.assignee}` : ""}
            </p>
          )}''',
  '''          {thread.account_address && (
            <div className="mt-0.5 flex min-w-0 items-center gap-1.5">
              <AddressChip
                address={thread.account_address}
                dir={folder === "sent" ? "out" : "in"}
              />
              {thread.assignee ? (
                <span className="truncate text-[11px] text-muted-foreground">
                  · {thread.assignee}
                </span>
              ) : null}
            </div>
          )}'''),
 ('''          <span className="text-[11px] text-muted-foreground">{message.from_address}</span>''',
  '''          <span className="text-[11px] text-muted-foreground">{message.from_address}</span>
          <span className="rounded bg-secondary/60 px-1.5 py-0.5 text-[10px] font-medium text-muted-foreground">
            {message.direction === "out" ? "Sent" : "Received"}
          </span>'''),
]
for a, b in pairs:
    if s.count(a) != 1:
        print("ANCHOR_FAIL", repr(a[:50]), s.count(a)); sys.exit(2)
    s = s.replace(a, b)
open(dst, "w").write(s)
print("THREAD_PATCH_OK")

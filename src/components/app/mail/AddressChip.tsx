import { ArrowDownLeft, ArrowUpRight } from "lucide-react";

import { addressTone } from "@/lib/mail-identity";

/**
 * "Kaun sa address" ka chip. dir="in"  → is address par aayi.
 *                           dir="out" → is address se gayi.
 */
export function AddressChip({
  address,
  dir = "in",
}: {
  address: string | null | undefined;
  dir?: "in" | "out";
}) {
  const tone = addressTone(address);
  if (!tone) return null;
  const Icon = dir === "out" ? ArrowUpRight : ArrowDownLeft;
  return (
    <span
      title={dir === "out" ? `Sent from ${tone.address}` : `Received at ${tone.address}`}
      className="inline-flex max-w-full items-center gap-1 rounded-md px-1.5 py-0.5 text-[10px] font-medium"
      style={{ color: tone.color, background: tone.soft }}
    >
      <Icon className="size-2.5 shrink-0" aria-hidden="true" />
      <span className="truncate">{tone.address}</span>
    </span>
  );
}

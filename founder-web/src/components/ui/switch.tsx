import * as React from "react";
import * as SwitchPrimitive from "@radix-ui/react-switch";
import { cn } from "@/lib/utils";

/** shadcn Switch (Radix). It renders with the founder's existing `.switch` look (ui.css), so nothing changes visually; Radix adds the keyboard/ARIA behaviour. */
export const Switch = React.forwardRef<React.ComponentRef<typeof SwitchPrimitive.Root>, React.ComponentPropsWithoutRef<typeof SwitchPrimitive.Root>>(
  ({ className, checked, ...props }, ref) => (
    <SwitchPrimitive.Root ref={ref} checked={checked} className={cn("switch", checked && "on", className)} {...props}>
      <SwitchPrimitive.Thumb asChild><i /></SwitchPrimitive.Thumb>
    </SwitchPrimitive.Root>
  ),
);
Switch.displayName = "Switch";

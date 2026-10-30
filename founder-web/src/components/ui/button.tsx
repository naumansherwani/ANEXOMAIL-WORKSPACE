import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

/** shadcn Button (cva + Slot). Variants map to the founder's existing button classes, so the cinematic look is unchanged. */
const button = cva("", {
  variants: { variant: { default: "", ghost: "ghost" }, size: { default: "", mini: "mini" } },
  defaultVariants: { variant: "default", size: "default" },
});
export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement>, VariantProps<typeof button> { asChild?: boolean }
export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(({ className, variant, size, asChild, ...props }, ref) => {
  const C = asChild ? Slot : "button";
  return <C ref={ref} className={cn(button({ variant, size }), className)} {...props} />;
});
Button.displayName = "Button";

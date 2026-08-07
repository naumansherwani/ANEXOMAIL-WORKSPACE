import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "ax-focus inline-flex cursor-pointer items-center justify-center gap-2 whitespace-nowrap rounded-xl text-sm font-semibold transition-[background-color,border-color,color,box-shadow,transform] duration-500 ease-[var(--ease-cine)] disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
  {
    variants: {
      variant: {
        // Primary action — navy plane, platinum text, key light on hover.
        default:
          "bg-primary text-primary-foreground shadow-elev-1 hover:bg-primary/90 hover:shadow-elev-2",
        // Signature call to action — used once per surface, never twice.
        seal: "bg-primary text-primary-foreground shadow-stage hover:bg-primary/90 hover:-translate-y-px",
        destructive:
          "bg-destructive text-destructive-foreground shadow-elev-1 hover:bg-destructive/90",
        outline:
          "border border-border bg-transparent text-foreground hover:border-ring/45 hover:bg-secondary",
        secondary: "bg-secondary text-secondary-foreground hover:bg-accent",
        // Quiet action — lives inside a plane, only shows itself on hover.
        quiet: "text-steel hover:bg-secondary hover:text-foreground",
        ghost: "text-foreground hover:bg-secondary",
        link: "text-foreground underline-offset-4 hover:underline",
      },
      size: {
        default: "h-10 px-4",
        sm: "h-8 rounded-lg px-3 text-xs",
        lg: "h-11 px-6",
        xl: "h-12 px-7 text-[0.9375rem]",
        icon: "size-9 rounded-lg",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  },
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>, VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return (
      <Comp className={cn(buttonVariants({ variant, size, className }))} ref={ref} {...props} />
    );
  },
);
Button.displayName = "Button";

export { Button, buttonVariants };

import * as React from "react";
export const Slot = React.forwardRef<HTMLElement, React.HTMLAttributes<HTMLElement> & { children?: React.ReactNode }>(
  ({ children, ...p }, ref) =>
    React.isValidElement(children)
      ? React.cloneElement(children as React.ReactElement<Record<string, unknown>>, { ...p, ref } as Record<string, unknown>)
      : null,
);

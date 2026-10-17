// Harness stand-in for @radix-ui/react-checkbox (Root = button role=checkbox, Indicator = span when checked).
import * as React from "react";

type RootProps = Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, "onChange"> & {
  checked?: boolean | "indeterminate";
  defaultChecked?: boolean;
  onCheckedChange?: (v: boolean) => void;
};
const Ctx = React.createContext(false);
export const Root = React.forwardRef<HTMLButtonElement, RootProps>(
  ({ checked, defaultChecked, onCheckedChange, children, ...rest }, ref) => {
    const [inner, setInner] = React.useState(Boolean(defaultChecked));
    const on = checked === undefined ? inner : checked === true;
    return (
      <Ctx.Provider value={on}>
        <button
          ref={ref}
          type="button"
          role="checkbox"
          aria-checked={on}
          data-state={on ? "checked" : "unchecked"}
          onClick={() => {
            setInner(!on);
            onCheckedChange?.(!on);
          }}
          {...rest}
        >
          {children}
        </button>
      </Ctx.Provider>
    );
  },
);
export const Indicator = ({ children, className }: { children?: React.ReactNode; className?: string }) =>
  React.useContext(Ctx) ? <span className={className}>{children}</span> : null;

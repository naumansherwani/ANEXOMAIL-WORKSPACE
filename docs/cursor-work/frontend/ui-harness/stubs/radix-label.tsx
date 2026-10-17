import * as React from "react";
export const Root = React.forwardRef<HTMLLabelElement, React.LabelHTMLAttributes<HTMLLabelElement>>((p, ref) => <label ref={ref} {...p} />);

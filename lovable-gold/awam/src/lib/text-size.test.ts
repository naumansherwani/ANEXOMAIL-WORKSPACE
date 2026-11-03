import { describe, expect, test } from "bun:test";

import { cleanTextSize, paintTextSize, TEXT_SIZES } from "./text-size";

function fakeEl() {
  const attrs = new Map<string, string>();
  const props = new Map<string, string>();
  return {
    attrs,
    props,
    setAttribute: (k: string, v: string) => void attrs.set(k, v),
    removeAttribute: (k: string) => void attrs.delete(k),
    style: {
      setProperty: (k: string, v: string) => void props.set(k, v),
      removeProperty: (k: string) => void props.delete(k),
    },
  };
}

describe("text size", () => {
  test("only known sizes are accepted, everything else is 100", () => {
    expect(cleanTextSize("115")).toBe(115);
    expect(cleanTextSize(150)).toBe(150);
    expect(cleanTextSize("999")).toBe(100);
    expect(cleanTextSize(null)).toBe(100);
    expect(cleanTextSize("abc")).toBe(100);
    expect(TEXT_SIZES).toContain(100);
  });
  test("100 leaves no trace on the page; others set attribute and variable", () => {
    const el = fakeEl();
    paintTextSize(130, el as unknown as HTMLElement);
    expect(el.attrs.get("data-ax-ts")).toBe("130");
    expect(el.props.get("--ax-ts")).toBe("1.3");
    paintTextSize(100, el as unknown as HTMLElement);
    expect(el.attrs.has("data-ax-ts")).toBe(false);
    expect(el.props.has("--ax-ts")).toBe(false);
  });
});

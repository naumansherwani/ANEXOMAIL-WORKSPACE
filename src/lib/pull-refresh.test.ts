import { describe, expect, test } from "bun:test";

import {
  canStartPull,
  damped,
  isPullGesture,
  PULL_MAX,
  PULL_THRESHOLD,
  pullReady,
} from "./pull-refresh";

type Box = NonNullable<Parameters<typeof canStartPull>[0]> & { overflowY: string };
const el = (
  o: Partial<{
    scrollTop: number;
    scrollHeight: number;
    clientHeight: number;
    oy: string;
    block: boolean;
  }>,
  parent: Box | null = null,
): Box => ({
  scrollTop: o.scrollTop ?? 0,
  scrollHeight: o.scrollHeight ?? 100,
  clientHeight: o.clientHeight ?? 100,
  parentElement: parent,
  overflowY: o.oy ?? "visible",
  matches: () => !!o.block,
});
const oy = (e: Box) => e.overflowY;

describe("pull-to-refresh", () => {
  test("damping is resistive and capped", () => {
    expect(damped(-5)).toBe(0);
    expect(damped(100)).toBe(50);
    expect(damped(1000)).toBe(PULL_MAX);
    expect(pullReady(PULL_THRESHOLD - 1)).toBe(false);
    expect(pullReady(PULL_THRESHOLD)).toBe(true);
  });
  test("only a mostly-vertical downward drag counts", () => {
    expect(isPullGesture(2, 30)).toBe(true);
    expect(isPullGesture(30, 30)).toBe(false);
    expect(isPullGesture(0, -30)).toBe(false);
    expect(isPullGesture(0, 4)).toBe(false);
  });
  test("starts only when every scroll box is at the top", () => {
    const main = el({ oy: "auto", scrollHeight: 900, clientHeight: 500, scrollTop: 0 });
    const inner = el({ oy: "auto", scrollHeight: 900, clientHeight: 500, scrollTop: 0 }, main);
    expect(canStartPull(inner, oy)).toBe(true);
    const scrolled = el({ oy: "auto", scrollHeight: 900, clientHeight: 500, scrollTop: 40 }, main);
    expect(canStartPull(scrolled, oy)).toBe(false);
    const noOverflow = el({ oy: "auto", scrollHeight: 100, clientHeight: 100, scrollTop: 0 }, main);
    expect(canStartPull(noOverflow, oy)).toBe(true);
  });
  test("never inside inputs, editors or dialogs", () => {
    const main = el({});
    expect(canStartPull(el({ block: true }, main), oy)).toBe(false);
  });
});

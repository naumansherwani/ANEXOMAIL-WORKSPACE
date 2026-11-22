/* tslint:disable */
/* eslint-disable */

/**
 * Phase C2: true when a track's last verified frame is older than 12 s.
 */
export function frame_is_stale(last_frame_ts: number, now: number): boolean;

/**
 * D5a-5 (phase 1i): the ONLY door from a lookup answer to a screen. Returns JSON {"state":"data","body":"..."} | {"state":"refused"} | {"state":"unavailable"}.
 * status = HTTP status the browser saw (0 for a network error); every doubt, stale, replayed, other-request or malformed answer is "unavailable".
 */
export function lookup_view(pinned_pub_hex: string, nonce_hex: string, now: number, request_id: string, company: string, status: number, envelope: string): string;

/**
 * Build the three request headers (nonce, ts, mac). nonce_hex = 16 random bytes from crypto.getRandomValues (JS), ts = unix seconds.
 */
export function request_headers(token: string, method: string, path: string, nonce_hex: string, ts: number, body: string): string;

/**
 * Phase C2: the hello line of the live stream (nonce_hex = 16 random bytes from crypto.getRandomValues, ts = unix seconds).
 */
export function stream_hello(token: string, nonce_hex: string, ts: number): string;

/**
 * Verify a Desk answer envelope against the pinned public key. Returns the BODY string only when the signature, path, method, nonce and clock all match.
 */
export function verify_answer(pinned_pub_hex: string, method: string, path: string, nonce_hex: string, now: number, envelope: string): string;

/**
 * Phase C2: verify ONE stream line. Returns the frame JSON {"seq","track","data"} only when signature, track, clock and seq (== last_seq + 1) all pass.
 */
export function verify_frame(pinned_pub_hex: string, now: number, last_seq: number, line: string): string;

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly frame_is_stale: (a: number, b: number) => number;
    readonly lookup_view: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: number, l: number, m: number) => void;
    readonly request_headers: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: number, l: number) => void;
    readonly stream_hello: (a: number, b: number, c: number, d: number, e: number, f: number) => void;
    readonly verify_answer: (a: number, b: number, c: number, d: number, e: number, f: number, g: number, h: number, i: number, j: number, k: number, l: number) => void;
    readonly verify_frame: (a: number, b: number, c: number, d: number, e: number, f: number, g: number) => void;
    readonly __wbindgen_externrefs: WebAssembly.Table;
    readonly __wbindgen_add_to_stack_pointer: (a: number) => number;
    readonly __wbindgen_export: (a: number, b: number) => number;
    readonly __wbindgen_export2: (a: number, b: number, c: number, d: number) => number;
    readonly __wbindgen_export3: (a: number, b: number, c: number) => void;
    readonly __wbindgen_export4: (a: number) => void;
    readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;

/**
 * Instantiates the given `module`, which can either be bytes or
 * a precompiled `WebAssembly.Module`.
 *
 * @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
 *
 * @returns {InitOutput}
 */
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
 * If `module_or_path` is {RequestInfo} or {URL}, makes a request and
 * for everything else, calls `WebAssembly.instantiate` directly.
 *
 * @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
 *
 * @returns {Promise<InitOutput>}
 */
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;

// Harness stand-in for @tanstack/react-query (not installed in the sandbox). Runs `queryFn` once per key on mount and exposes
// the same fields the app reads: data, error, isPending, isLoading, isFetching, refetch. Mutations only record that they ran.
import { useCallback, useEffect, useRef, useState } from "react";

type Opts<T> = { queryKey?: unknown[]; queryFn?: () => Promise<T>; enabled?: boolean };
export function useQuery<T, E = Error>(opts: Opts<T>) {
  const [state, setState] = useState<{ data?: T; error: E | null; pending: boolean }>({ error: null, pending: opts.enabled !== false });
  const fnRef = useRef(opts.queryFn);
  fnRef.current = opts.queryFn;
  const key = JSON.stringify(opts.queryKey ?? []);
  const run = useCallback(() => {
    if (opts.enabled === false || !fnRef.current) return;
    setState((s) => ({ ...s, pending: true }));
    fnRef.current().then(
      (data) => setState({ data, error: null, pending: false }),
      (error) => setState({ error: error as E, pending: false }),
    );
  }, [opts.enabled]);
  useEffect(() => { run(); /* eslint-disable-next-line react-hooks/exhaustive-deps */ }, [key, opts.enabled]);
  return { data: state.data, error: state.error, isPending: state.pending, isLoading: state.pending, isFetching: state.pending, isError: !!state.error, refetch: run };
}
export function useMutation<V = unknown, R = unknown>(opts: { mutationFn?: (v: V) => Promise<R>; onSuccess?: (r: R) => void } = {}) {
  const [pending, setPending] = useState(false);
  const mutate = (v: V, cbs?: { onSuccess?: (r: R) => void; onError?: (e: Error) => void }) => {
    setPending(true);
    Promise.resolve(opts.mutationFn ? opts.mutationFn(v) : undefined).then(
      (r) => { setPending(false); opts.onSuccess?.(r as R); cbs?.onSuccess?.(r as R); },
      (e) => { setPending(false); cbs?.onError?.(e as Error); },
    );
  };
  return { mutate, mutateAsync: async (v: V) => (opts.mutationFn ? opts.mutationFn(v) : undefined), isPending: pending, error: null, reset: () => {} };
}
export const useQueryClient = () => ({ invalidateQueries: async () => {}, setQueryData: () => {}, getQueryData: () => undefined, cancelQueries: async () => {} });

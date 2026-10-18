// Harness stand-in for @tanstack/react-query (not installed in the sandbox). Runs `queryFn` once per key on mount and exposes
// the same fields the app reads: data, error, isPending, isLoading, isFetching, refetch. Mutations only record that they ran.
import { useCallback, useEffect, useRef, useState } from "react";

const runners = new Set<() => void>();
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
  useEffect(() => { runners.add(run); return () => { runners.delete(run); }; }, [run]);
  return { data: state.data, error: state.error, isPending: state.pending, isLoading: state.pending && state.data === undefined, isFetching: state.pending, isError: !!state.error, refetch: run };
}
export function useMutation<R = unknown, E = Error, V = unknown>(opts: { mutationFn?: (v: V) => Promise<R>; onSuccess?: (r: R) => void; onSettled?: () => void } = {}) {
  const [st, setSt] = useState<{ pending: boolean; data?: R; error: E | null; variables?: V }>({ pending: false, error: null });
  const mutate = (v: V, cbs?: { onSuccess?: (r: R) => void; onError?: (e: E) => void }) => {
    setSt({ pending: true, error: null, variables: v });
    Promise.resolve(opts.mutationFn ? opts.mutationFn(v) : undefined).then(
      (r) => { setSt({ pending: false, data: r as R, error: null, variables: v }); opts.onSuccess?.(r as R); cbs?.onSuccess?.(r as R); opts.onSettled?.(); },
      (e) => { setSt({ pending: false, error: e as E, variables: v }); cbs?.onError?.(e as E); opts.onSettled?.(); },
    );
  };
  return { mutate, mutateAsync: async (v: V) => (opts.mutationFn ? opts.mutationFn(v) : undefined), isPending: st.pending, variables: st.variables, data: st.data, error: st.error, reset: () => setSt({ pending: false, error: null }) };
}
export const useQueryClient = () => ({ invalidateQueries: async () => { setTimeout(() => runners.forEach((r) => r()), 0); }, setQueryData: () => {}, getQueryData: () => undefined, cancelQueries: async () => {} });

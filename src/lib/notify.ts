import { toast } from "sonner";

/**
 * Toast system — Phase 4.
 * One voice for every transient message. Rules:
 * - a toast reports something that already happened, never a question
 * - success is short and silent-ish (2.6s), errors stay until dismissed
 * - every failure toast carries a retry action when a retry is possible
 * - never used for validation inside a form — that belongs on the field
 */

const DURATION_OK = 2600;

export const notify = {
  done(message: string, description?: string) {
    return toast.success(message, { description, duration: DURATION_OK });
  },

  info(message: string, description?: string) {
    return toast(message, { description, duration: DURATION_OK });
  },

  failed(
    message: string,
    options?: { description?: string; retry?: () => void; retryLabel?: string },
  ) {
    return toast.error(message, {
      description: options?.description,
      duration: Infinity,
      action: options?.retry
        ? { label: options.retryLabel ?? "Retry", onClick: options.retry }
        : undefined,
    });
  },

  /** Work in flight — resolves into a single success or failure toast. */
  working<T>(
    promise: Promise<T>,
    copy: { loading: string; success: string; error: string },
  ) {
    return toast.promise(promise, {
      loading: copy.loading,
      success: copy.success,
      error: copy.error,
    });
  },

  dismiss(id?: string | number) {
    toast.dismiss(id);
  },
};
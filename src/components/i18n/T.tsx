import { useLocale } from "@/lib/i18n";

/**
 * Future pages: wrap visible English in <T>English source</T>.
 * Same contract as t("English source") — missing locale = this English.
 */
export function T({ children }: { children: string }) {
  const { t } = useLocale();
  return <>{t(children)}</>;
}

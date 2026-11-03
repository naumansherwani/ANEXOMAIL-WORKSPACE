/**
 * Mail identity — har address ka apna rang (domain ke hisaab se).
 * Login address (@anexomail.com) hamesha ek hi neela rang; company domain ka
 * apna rang, taake info@ aur sales@ ek hi "family" lagen.
 */

const COMPANY_HUES = [38, 152, 268, 340, 174, 24] as const;
const LOGIN_DOMAIN = "anexomail.com";
const LOGIN_HUE = 200;

export type AddressTone = {
  address: string;
  local: string;
  domain: string;
  /** True for the free @anexomail.com login address. */
  isLogin: boolean;
  color: string;
  soft: string;
};

export function addressTone(address: string | null | undefined): AddressTone | null {
  const a = (address ?? "").trim().toLowerCase();
  const at = a.lastIndexOf("@");
  if (!a || at < 1) return null;
  const local = a.slice(0, at);
  const domain = a.slice(at + 1);
  const isLogin = domain === LOGIN_DOMAIN;
  let hash = 0;
  for (let i = 0; i < domain.length; i++) hash = domain.charCodeAt(i) + ((hash << 5) - hash);
  const hue = isLogin ? LOGIN_HUE : (COMPANY_HUES[Math.abs(hash) % COMPANY_HUES.length] ?? 38);
  return {
    address: a,
    local,
    domain,
    isLogin,
    color: `hsl(${hue} 85% 62%)`,
    soft: `hsl(${hue} 85% 62% / 0.14)`,
  };
}

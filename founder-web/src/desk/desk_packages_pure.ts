// ADMIN DESK 1m-8 (card B9b, plan detail), 23 Nov 2026. The package card facts shown on a plan's detail page. SOURCE: the founder's package decisions of 7 Nov 2026 (docs/claude/AWAM-PACKAGES-PROPOSAL-07NOV.md, sections 1 and 6: his chart + FINAL decisions A-G).
// Values marked starred in the decisions (Premium and Max storage, transfer, file limits) are recommendations, not a public promise until Hetzner capacity is verified: the screen says so. B9c moves these facts into the database
// (plan catalogue with versions) and pushes every change to the Desk within one second; until then this file is the one place they live, and a change to it is a reviewed commit.
import type { PKGS } from "./desk_customers_pure";
export type PlanKey = (typeof PKGS)[number];
export type PlanFacts = { name: string; price: string; users: string; storage: string; attachment: string; chat_file: string; transfer: string; features: string[]; unverified: boolean };
export const FACTS: Record<PlanKey, PlanFacts> = {
  basic: { name: "Basic", price: "£40 a month, flat for the whole company", users: "5 users", storage: "15 GB shared", attachment: "25 MB", chat_file: "Not included", transfer: "250 GB a month", unverified: false,
    features: ["Email, calendar, contacts and Pass in the package", "One-click import from Google, Microsoft and Proton", "48-hour trial, then only the package changes"] },
  pro: { name: "Pro", price: "£105 a month, flat for the whole company", users: "20 users", storage: "300 GB shared", attachment: "35 MB", chat_file: "Not included", transfer: "1 TB a month", unverified: false,
    features: ["Everything in Basic", "Team scheduling and shared calendars", "More admin controls"] },
  business: { name: "Business", price: "£360 a month, flat for the whole company", users: "60 users", storage: "1.5 TB shared", attachment: "45 MB", chat_file: "500 MB", transfer: "3 TB a month", unverified: false,
    features: ["Everything in Pro", "Team chat and file sharing", "Organisation admin", "Pooled outbound transfer with 70 and 85 percent alerts"] },
  business_pro: { name: "Business Pro", price: "£2,850 a month, flat for the whole company", users: "570 users", storage: "10 TB shared", attachment: "60 MB", chat_file: "1.5 GB", transfer: "28.5 TB a month", unverified: false,
    features: ["Everything in Business", "Multiple teams", "Advanced admin and audit", "Uptime promise and named support"] },
  business_premium: { name: "Business Premium", price: "£21,000 a month, flat for the whole company", users: "7,000 users", storage: "70 TB shared*", attachment: "100 MB", chat_file: "4 GB", transfer: "350 TB a month", unverified: true,
    features: ["Everything in Business Pro", "Central policies", "Migration help", "Priority support"] },
  business_max: { name: "Business Max", price: "£125,000 a month, flat for the whole company", users: "Unlimited users (seats only, never unlimited storage or traffic)", storage: "250 TB shared*", attachment: "250 MB*", chat_file: "10 GB*", transfer: "500 TB a month included*", unverified: true,
    features: ["Everything in Business Premium", "Named migration and named support", "Agreed capacity"] },
};
export const SOURCE_NOTE = "Package card as the founder decided on 7 Nov 2026. No automatic extra charge: beyond the pool only an agreed capacity pack.";
export const STAR_NOTE = "* A recommendation, not a public promise until the Hetzner capacity and cost are verified.";
export const NONE_FACTS = { name: "No plan yet", about: "Companies that have an account but no subscription. They can start the 48-hour trial; it is the only free entry." };
export const UNKNOWN_FACTS = { name: "Plan not recognised", about: "A subscription whose plan name is not one of the six packages. This should be zero; any number here needs a look at the subscription data." };

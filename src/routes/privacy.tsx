import { createFileRoute, Link } from "@tanstack/react-router";

export const Route = createFileRoute("/privacy")({
  head: () => ({
    meta: [
      { title: "Privacy & account integrity — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "How ANEXOMAIL seals a device record from five coarse signals, our fair-use ladder, and what happens to your data on exit.",
      },
      { property: "og:title", content: "Privacy & account integrity — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content:
          "One person, one account. No biometric fingerprinting, no third-party moderation, 72-hour export on exit.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: PrivacyPage,
});

function PrivacyPage() {
  return (
    <main className="ax-container py-16">
      <p className="text-xs font-semibold tracking-wider text-muted-foreground uppercase">Policy</p>
      <h1 className="ax-display mt-3 text-foreground">Privacy &amp; account integrity</h1>

      <section className="mt-10 max-w-3xl space-y-4">
        <h2 className="ax-heading text-foreground">Account integrity &amp; privacy</h2>
        <p className="text-sm leading-relaxed text-muted-foreground">
          One person, one account. When you sign in we seal a device record built from five coarse
          signals only — platform, browser, timezone bucket, screen bucket and language. It is
          hashed, stored encrypted and carries a deletion date. We do not use biometric
          fingerprinting, and we do not probe canvas, audio, fonts or graphics hardware.
        </p>
        <p className="text-sm leading-relaxed text-muted-foreground">
          This exists for one reason: to stop one device farming many accounts for spam, abuse or
          fraud. You can see and revoke your own devices at any time, and revoking one ends its live
          sessions immediately.
        </p>
      </section>

      <section className="mt-12 max-w-3xl space-y-4">
        <h2 className="ax-heading text-foreground">Fair use &amp; your data on exit</h2>
        <ul className="space-y-3 text-sm leading-relaxed text-muted-foreground">
          <li>
            A device used to reach 3 or more accounts, or to create 3 or more accounts within 24
            hours, is marked suspicious and reviewed.
          </li>
          <li>
            A confirmed violation receives one written final warning before any account is blocked.
          </li>
          <li>
            A repeat violation blocks the account, and a severe pattern adds the device to the ban
            list so it cannot create new accounts.
          </li>
          <li>
            A blocked account keeps full export access for 72 hours. After that window the data is
            permanently deleted, as committed.
          </li>
          <li>
            Your conversations are never sent to any AI or third-party moderation service. File
            safety runs on our own infrastructure.
          </li>
        </ul>
      </section>

      <p className="mt-14 text-sm">
        <Link to="/" className="text-muted-foreground transition-colors hover:text-foreground">
          ← Back to home
        </Link>
      </p>
    </main>
  );
}

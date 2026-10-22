import { createFileRoute, Link } from "@tanstack/react-router";

export const Route = createFileRoute("/privacy")({
  head: () => ({
    meta: [
      { title: "Privacy & account integrity — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "What ANEXOMAIL checks when an account is created, how it protects against repeat abuse, our fair-use ladder, and what happens to your data on exit.",
      },
      { property: "og:title", content: "Privacy & account integrity — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content:
          "One person, one account. One-way hashed technical signals, human review before any browser-only match blocks anyone, no third-party moderation, 72-hour export on exit.",
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
          One person, one account. ANEXOMAIL is a business mail and calendar service, and it only
          works if a person who has been removed for abuse cannot simply return under a new name. To
          protect every other customer, we compare each new sign-up against records of people who
          have been blocked.
        </p>
        <h3 className="text-sm font-semibold text-foreground">What we check</h3>
        <ul className="space-y-3 text-sm leading-relaxed text-muted-foreground">
          <li>
            <span className="text-foreground">Account details:</span> your sign-in address, your
            recovery address and, if you subscribe, your payment method reference.
          </li>
          <li>
            <span className="text-foreground">A device key:</span> a cryptographic key your browser
            creates for itself. Its private half never leaves your browser.
          </li>
          <li>
            <span className="text-foreground">
              Technical characteristics of your browser and computer:
            </span>{" "}
            for example platform, screen size, the capability limits of the graphics hardware, which
            system fonts are installed, how the browser renders text and audio, time zone and
            language. These are technical settings, not biometric data, and nothing is read from
            your body, camera, microphone or contacts.
          </li>
          <li>
            <span className="text-foreground">The network a sign-up comes from</span>, to notice
            many accounts being created in a short time.
          </li>
          <li>
            <span className="text-foreground">Temporary email addresses</span> are not accepted as a
            recovery address.
          </li>
        </ul>
        <h3 className="text-sm font-semibold text-foreground">How it is protected</h3>
        <p className="text-sm leading-relaxed text-muted-foreground">
          Your browser reduces each group of characteristics to a one-way digest before anything is
          sent; the raw values never leave your device. Our server then protects every value with a
          secret key that exists only on our servers, so what we store cannot be turned back into
          the original information, and cannot be matched by anyone without that key. We keep device
          and browser records for 180 days and network records for 30 days. Records tied to an
          address or payment method last as long as the account. If you delete your account, its
          records are deleted with it. Records of a blocked person are kept for two years by
          default, and permanently only for severe abuse, so that the block cannot be sidestepped.
        </p>
        <p className="text-sm leading-relaxed text-muted-foreground">
          This is used for one purpose only: to stop abuse, spam and fraud at sign-up. It is not
          used for advertising, profiling or tracking you across other sites. You can see and revoke
          your own devices at any time, and revoking one ends its live sessions immediately.
        </p>
      </section>

      <section className="mt-12 max-w-3xl space-y-4">
        <h2 className="ax-heading text-foreground">What happens when something matches</h2>
        <ul className="space-y-3 text-sm leading-relaxed text-muted-foreground">
          <li>
            A sign-up that reuses a verified detail of a blocked person (the same email, recovery
            address, payment method or device key) is refused. The person can appeal in writing and
            a human reads it.
          </li>
          <li>
            Browser and hardware characteristics alone never block anyone, because many people own
            identical devices. A sign-up that closely resembles a blocked person&rsquo;s browser is
            created but kept on hold until a member of our team reviews it. A held account cannot be
            used and cannot sign in. If a review is not completed within 30 days, the hold is closed
            and the account stays locked.
          </li>
          <li>
            Some privacy-focused browsers deliberately hide these characteristics. A sign-up from
            such a browser may also be placed in review. If your account is approved, we email you
            at your recovery address.
          </li>
          <li>
            During the first 7 days a new account has limits: messages to up to 20 people at a time,
            up to 50 messages a day, and no invitations, public links or bulk imports. The limits
            end after 7 days, or immediately when you subscribe to a plan.
          </li>
          <li>
            Every block can be appealed in writing, up to 20,000 characters, with up to five
            evidence files (screenshots, PDF, text, email or Office documents). Files are scanned,
            visible only to the reviewers who decide your appeal, and deleted 90 days after the
            decision. Every reviewer download is logged.
          </li>
        </ul>
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
            safety runs on our own infrastructure. The checks above never read the content of your
            mail or calendar.
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

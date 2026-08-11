import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/app/admin/addresses")({
  head: () => ({
    meta: [
      { title: "Addresses — ANEXOMAIL Admin" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AddressesPage,
});

const kinds = [
  {
    title: "Personal address",
    body: "One person, one mailbox. name@yourcompany.com with a private inbox nobody else can read.",
  },
  {
    title: "Shared address",
    body: "sales@, support@, accounts@ — a team inbox where every thread has an owner, a status and a visible reply-in-progress so two people never answer the same customer.",
  },
  {
    title: "Alias",
    body: "Another spelling delivered to an existing mailbox, with no extra seat and no extra cost.",
  },
];

function AddressesPage() {
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-10 md:px-10">
      <p className="ax-eyebrow">Routing</p>
      <h2 className="mt-3 text-3xl text-foreground">Addresses</h2>
      <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
        Shared addresses are part of the workspace, not an add-on product.
      </p>

      <ul className="mt-8 space-y-3">
        {kinds.map((k) => (
          <li key={k.title} className="ax-plane rounded-2xl p-5">
            <h2 className="text-base font-bold text-foreground">{k.title}</h2>
            <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
              {k.body}
            </p>
          </li>
        ))}
      </ul>

      <p className="mt-8 text-sm text-muted-foreground">
        No addresses yet — add a domain to create the first one.
      </p>
    </div>
  );
}
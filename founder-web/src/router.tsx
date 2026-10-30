// TanStack Router (Rule 61): code-based routes with HASH history, so the URLs stay exactly as before (#/finance, #/settings) and every deep link keeps working.
// One dynamic page route `/$view`; the shell (App) is the root layout and renders the routed page body through <Outlet />.
import { createRootRoute, createRoute, createRouter, createHashHistory, redirect, Navigate } from "@tanstack/react-router";
import App, { KNOWN, ViewBody } from "./App";

const root = createRootRoute({ component: App, notFoundComponent: () => <Navigate to="/$view" params={{ view: "dashboard" }} replace /> });
const index = createRoute({ getParentRoute: () => root, path: "/", beforeLoad: () => { throw redirect({ to: "/$view", params: { view: "dashboard" } }); } });
const page = createRoute({
  getParentRoute: () => root,
  path: "/$view",
  beforeLoad: ({ params }) => { if (!KNOWN.has(params.view)) throw redirect({ to: "/$view", params: { view: "dashboard" } }); },
  component: ViewBody,
});

export const router = createRouter({ routeTree: root.addChildren([index, page]), history: createHashHistory(), defaultPreload: false });
declare module "@tanstack/react-router" { interface Register { router: typeof router } }

import { QueryClient } from "@tanstack/react-query";
import { createRouter } from "@tanstack/react-router";
import { PageLoader } from "@/components/state/BrandLoader";
import { routeTree } from "./routeTree.gen";

export const getRouter = () => {
  const queryClient = new QueryClient();

  const router = createRouter({
    routeTree,
    context: { queryClient },
    scrollRestoration: true,
    defaultPreloadStaleTime: 0,
    // Route load dheema ho (>250 ms) to asli A wala loader; jaldi ho to kuch flash nahi (min 450 ms taake jhalak na ho)
    defaultPendingComponent: () => <PageLoader />,
    defaultPendingMs: 250,
    defaultPendingMinMs: 450,
  });

  return router;
};

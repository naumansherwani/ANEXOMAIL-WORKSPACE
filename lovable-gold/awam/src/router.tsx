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
    // Sirf asli dheemi load par loader (>400 ms); khatam hote hi chala jaye (min 0) — pehle 450 ms atka rehta tha aur "dobara loading" lagti thi.
    defaultPendingMs: 400,
    defaultPendingMinMs: 0,
  });

  return router;
};

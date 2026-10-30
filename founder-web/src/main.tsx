import { createRoot } from "react-dom/client";
import { RouterProvider } from "@tanstack/react-router";
import { router } from "./router";
import "./styles.css";
import "./ui.css";
import "./cinema.css";
import "./tailwind.css";
createRoot(document.getElementById("root") as HTMLElement).render(<RouterProvider router={router} />);

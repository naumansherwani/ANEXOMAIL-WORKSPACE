import { createRoot } from "react-dom/client";
import { RouterProvider } from "@tanstack/react-router";
import { router } from "./router";
import "./styles.css";
import "./ui.css";
import "./cinema.css";
import "./tailwind.css";
import "./dx.css";
import "./devices.css";
import { kernelRpcStart } from "./kernel";

void kernelRpcStart(); // K8d: open the kernel WebTransport RPC session at boot
createRoot(document.getElementById("root") as HTMLElement).render(<RouterProvider router={router} />);

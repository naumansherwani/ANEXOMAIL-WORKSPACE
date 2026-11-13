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
import { startPathProbe } from "./pathprobe";

void kernelRpcStart(); // K8d: open the kernel WebTransport RPC session at boot
startPathProbe(); // KP3 step 3: a tiny ping every 15 s = the honest path round trip
createRoot(document.getElementById("root") as HTMLElement).render(<RouterProvider router={router} />);

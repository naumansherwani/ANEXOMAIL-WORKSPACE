import { createRoot } from "react-dom/client";
import "../styles.css";
import "../ui.css";
import "../cinema.css";
import "../tailwind.css";
import "../dx.css";
import { DeskApp } from "./DeskPages";

createRoot(document.getElementById("root") as HTMLElement).render(<DeskApp />);

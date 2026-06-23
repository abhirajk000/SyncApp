import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import { initAppUpdate } from "./lib/appUpdate";
import "./index.css";

initAppUpdate();

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);

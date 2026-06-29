import { useState } from "react";
import { AppTabs } from "../components";
import { ClipboardTimelinePage } from "./ClipboardTimelinePage";
import { PinnedPage } from "./ClipboardPage";

type Section = "history" | "pinned";

export function ClipboardHubPage() {
  const [section, setSection] = useState<Section>("history");

  return (
    <div className="sb-page-stack">
      <div>
        <h1 className="ds-page-title">Clipboard</h1>
        <p className="ds-page-lead">Instant sync across all your devices.</p>
      </div>
      <AppTabs
        tabs={[
          { id: "history", label: "Clipboard" },
          { id: "pinned", label: "Pinned" },
        ]}
        active={section}
        onChange={(id) => setSection(id as Section)}
      />
      {section === "history" ? (
        <ClipboardTimelinePage embedded />
      ) : (
        <PinnedPage embedded />
      )}
    </div>
  );
}

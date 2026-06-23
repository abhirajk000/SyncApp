/** Build id injected by Vite at compile time — compared to /version.json on focus. */
export const BUILD_ID: string = import.meta.env.VITE_BUILD_ID ?? "dev";

let registered = false;

export function initAppUpdate(): void {
  if (registered || typeof window === "undefined") return;
  registered = true;

  if ("serviceWorker" in navigator) {
    void navigator.serviceWorker
      .register("/sw.js", { scope: "/", updateViaCache: "none" })
      .then((reg) => {
        void reg.update();
        window.setInterval(() => void reg.update(), 60_000);
      })
      .catch(() => {
        /* SW optional — version.json check still runs */
      });

    navigator.serviceWorker.addEventListener("controllerchange", () => {
      window.location.reload();
    });
  }

  void checkForNewBuild();
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") void checkForNewBuild();
  });
  window.addEventListener("focus", () => void checkForNewBuild());
}

async function checkForNewBuild(): Promise<void> {
  try {
    const res = await fetch(`/version.json?t=${Date.now()}`, {
      cache: "no-store",
      headers: { "Cache-Control": "no-cache" },
    });
    if (!res.ok) return;
    const data = (await res.json()) as { build?: string };
    if (data.build && data.build !== BUILD_ID) {
      window.location.reload();
    }
  } catch {
    /* offline */
  }
}

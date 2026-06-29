import { createContext, useContext, useEffect, useSyncExternalStore, type ReactNode } from "react";
import { localSendService, type LocalSendSnapshot } from "../lib/localSendService";

const LocalSendContext = createContext<LocalSendSnapshot | null>(null);

export function LocalSendProvider({ children }: { children: ReactNode }) {
  const snapshot = useSyncExternalStore(
    localSendService.subscribe,
    localSendService.getSnapshot,
    localSendService.getSnapshot,
  );

  useEffect(() => {
    localSendService.start();
    return () => localSendService.stop();
  }, []);

  return (
    <LocalSendContext.Provider value={snapshot}>{children}</LocalSendContext.Provider>
  );
}

export function useLocalSend(): LocalSendSnapshot {
  const ctx = useContext(LocalSendContext);
  if (!ctx) throw new Error("useLocalSend must be used within LocalSendProvider");
  return ctx;
}

export { localSendService };

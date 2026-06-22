import { createContext, useContext, useSyncExternalStore, type ReactNode } from "react";
import { networkService, type NetworkSnapshot } from "../lib/networkService";

const NetworkContext = createContext<NetworkSnapshot | null>(null);

export function NetworkProvider({ children }: { children: ReactNode }) {
  const snapshot = useSyncExternalStore(
    networkService.subscribe,
    networkService.getSnapshot,
    networkService.getSnapshot,
  );
  return (
    <NetworkContext.Provider value={snapshot}>{children}</NetworkContext.Provider>
  );
}

export function useNetwork(): NetworkSnapshot {
  const ctx = useContext(NetworkContext);
  if (!ctx) throw new Error("useNetwork must be used within NetworkProvider");
  return ctx;
}

export { networkService };

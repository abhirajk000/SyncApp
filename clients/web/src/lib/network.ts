/** Network helpers — discovery display and transfer badges. */

export type TransferRoute = "cloud" | "direct_lan" | "webrtc";

/** Clipboard always relays through the server (text + images). */
export const CLIPBOARD_TRANSFER_ROUTE: TransferRoute = "cloud";

/** Files are routed automatically by size/batch; user never picks a mode. */
export function systemTransferModeLabel(wsConnected: boolean): string {
  if (!wsConnected) return "Offline";
  return "Automatic";
}

/** Map server transfer_mode to display badge (files only). */
export function transferRouteFromMode(transferMode: string | undefined): TransferRoute {
  if (transferMode === "webrtc") return "webrtc";
  return "cloud";
}

export const TRANSFER_BADGE: Record<
  TransferRoute,
  { emoji: string; label: string; className: string }
> = {
  cloud: { emoji: "☁", label: "Cloud Relay", className: "ds-transfer-badge--cloud" },
  direct_lan: { emoji: "⚡", label: "Direct LAN", className: "ds-transfer-badge--lan" },
  webrtc: { emoji: "🌐", label: "WebRTC", className: "ds-transfer-badge--webrtc" },
};

/** Web clients cannot bind LAN ports; use diagnostics client IP for peer queries. */
export function peerQueryAddrs(clientIp: string | undefined): string {
  if (!clientIp || clientIp === "127.0.0.1" || clientIp.startsWith("::")) return "";
  return clientIp;
}

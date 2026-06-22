/**
 * File transfer routing — automatic, no user choice.
 * Clipboard (text/images) always uses HTTP relay; never WebRTC.
 */

export const FILE_RELAY_MAX_BYTES = 100 * 1024 * 1024;

export type FileTransferRoute = "cloud" | "webrtc";

export interface FileRouteContext {
  fileSizeBytes: number;
  fileCount?: number;
  isFolder?: boolean;
}

export function resolveFileUploadRoute(ctx: FileRouteContext): {
  transferMode: "relay" | "webrtc";
  route: FileTransferRoute;
  fallbackReason?: string;
} {
  const fileCount = ctx.fileCount ?? 1;
  const attemptWebRtc =
    ctx.fileSizeBytes > FILE_RELAY_MAX_BYTES ||
    fileCount > 1 ||
    ctx.isFolder === true;

  if (!attemptWebRtc) {
    return { transferMode: "relay", route: "cloud" };
  }

  return {
    transferMode: "webrtc",
    route: "webrtc",
    fallbackReason: "WebRTC attempted — automatic relay fallback if P2P unavailable",
  };
}

/** Folder pick via webkitdirectory sets webkitRelativePath with slashes. */
export function isFolderUpload(files: File[]): boolean {
  return files.some((f) => {
    const rel = (f as File & { webkitRelativePath?: string }).webkitRelativePath;
    return Boolean(rel?.includes("/"));
  });
}

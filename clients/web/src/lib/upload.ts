import { getAccessToken, getServerUrl, initFileUpload, completeFileUpload } from "../api";
import { networkService } from "./networkService";
import { isFolderUpload } from "./fileRouting";

const CHUNK_SIZE = 4 * 1024 * 1024;

export interface UploadProgress {
  progress: number;
  status: "uploading" | "success" | "error";
  error?: string;
}

export async function sha256Hex(data: ArrayBuffer): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function mimeTypeForFile(file: File): string {
  if (file.type) return file.type;
  const ext = file.name.split(".").pop()?.toLowerCase() ?? "";
  const map: Record<string, string> = {
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    png: "image/png",
    gif: "image/gif",
    webp: "image/webp",
    heic: "image/heic",
    heif: "image/heif",
    mp4: "video/mp4",
    mov: "video/quicktime",
    pdf: "application/pdf",
    txt: "text/plain",
    zip: "application/zip",
  };
  return map[ext] ?? "application/octet-stream";
}

async function uploadChunk(
  fileId: string,
  chunkIndex: number,
  data: ArrayBuffer,
  chunkHash: string,
): Promise<void> {
  const base = getServerUrl().replace(/\/$/, "");
  const token = getAccessToken();
  if (!token) throw new Error("Not authenticated");

  const res = await fetch(`${base}/api/v1/files/${fileId}/chunks/${chunkIndex}`, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/octet-stream",
      "X-Chunk-Hash": chunkHash,
    },
    body: data,
  });

  if (!res.ok) {
    let message = res.statusText;
    try {
      const err = await res.json();
      if (err.error) message = err.error;
    } catch {
      /* ignore */
    }
    throw new Error(message);
  }
}

export interface UploadResult {
  localId: string;
  fileId?: string;
  name: string;
  mimeType: string;
  status: "success" | "error";
  error?: string;
  transferRoute?: string;
}

export async function uploadFiles(
  files: File[],
  onFileProgress: (fileId: string, update: UploadProgress) => void,
): Promise<{ succeeded: number; failed: number; results: UploadResult[] }> {
  let succeeded = 0;
  let failed = 0;
  const results: UploadResult[] = [];
  const batchFolder = isFolderUpload(files);

  for (const file of files) {
    const localId = `${file.name}-${file.size}-${file.lastModified}`;
    const mime = mimeTypeForFile(file);
    onFileProgress(localId, { progress: 0, status: "uploading" });
    const t0 = performance.now();

    try {
      const buffer = await file.arrayBuffer();
      const fileHash = await sha256Hex(buffer);
      const chunkCount = Math.ceil(buffer.byteLength / CHUNK_SIZE) || 1;

      const routing = networkService.resolveUploadRoute({
        fileSizeBytes: buffer.byteLength,
        fileCount: files.length,
        isFolder: batchFolder,
      });
      let transferMode = routing.transferMode;
      let route = routing.route;
      let fallbackReason = routing.fallbackReason;

      const tryInit = async (mode: "relay" | "webrtc") =>
        initFileUpload({
          name: file.name,
          mime_type: mime,
          total_size: buffer.byteLength,
          chunk_size: CHUNK_SIZE,
          file_hash: fileHash,
          transfer_mode: mode,
          force_relay: false,
        });

      let init;
      try {
        init = await tryInit(transferMode);
      } catch (e) {
        if (transferMode === "webrtc") {
          fallbackReason = `Direct init failed: ${e instanceof Error ? e.message : "error"} — cloud relay`;
          transferMode = "relay";
          route = "cloud";
          init = await tryInit("relay");
        } else {
          throw e;
        }
      }

      let uploaded = 0;
      for (let index = 0; index < chunkCount; index++) {
        const start = index * CHUNK_SIZE;
        const end = Math.min(start + CHUNK_SIZE, buffer.byteLength);
        const chunk = buffer.slice(start, end);
        const chunkHash = await sha256Hex(chunk);
        await uploadChunk(init.file_id, index, chunk, chunkHash);
        uploaded += 1;
        onFileProgress(localId, {
          progress: uploaded / chunkCount,
          status: "uploading",
        });
      }

      await completeFileUpload(init.file_id);
      const elapsed = (performance.now() - t0) / 1000;
      const bytesPerSec = elapsed > 0 ? buffer.byteLength / elapsed : undefined;

      networkService.logTransfer({
        name: file.name,
        method: route,
        fallbackReason,
        bytesPerSec,
      });

      onFileProgress(localId, { progress: 1, status: "success" });
      results.push({
        localId,
        fileId: init.file_id,
        name: file.name,
        mimeType: mime,
        status: "success",
        transferRoute: route,
      });
      succeeded += 1;
    } catch (e) {
      networkService.logTransfer({
        name: file.name,
        method: "cloud",
        fallbackReason: e instanceof Error ? e.message : "Upload failed",
      });
      onFileProgress(localId, {
        progress: 0,
        status: "error",
        error: e instanceof Error ? e.message : "Upload failed",
      });
      results.push({
        localId,
        name: file.name,
        mimeType: mime,
        status: "error",
        error: e instanceof Error ? e.message : "Upload failed",
      });
      failed += 1;
    }
  }

  return { succeeded, failed, results };
}

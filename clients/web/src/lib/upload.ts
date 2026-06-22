import { getAccessToken, getServerUrl, initFileUpload, completeFileUpload } from "../api";

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

export async function uploadFiles(
  files: File[],
  onFileProgress: (fileId: string, update: UploadProgress) => void,
): Promise<{ succeeded: number; failed: number }> {
  let succeeded = 0;
  let failed = 0;

  for (const file of files) {
    const localId = `${file.name}-${file.size}-${file.lastModified}`;
    onFileProgress(localId, { progress: 0, status: "uploading" });

    try {
      const buffer = await file.arrayBuffer();
      const fileHash = await sha256Hex(buffer);
      const chunkCount = Math.ceil(buffer.byteLength / CHUNK_SIZE) || 1;

      const init = await initFileUpload({
        name: file.name,
        mime_type: mimeTypeForFile(file),
        total_size: buffer.byteLength,
        chunk_size: CHUNK_SIZE,
        file_hash: fileHash,
        transfer_mode: "relay",
        force_relay: false,
      });

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
      onFileProgress(localId, { progress: 1, status: "success" });
      succeeded += 1;
    } catch (e) {
      onFileProgress(localId, {
        progress: 0,
        status: "error",
        error: e instanceof Error ? e.message : "Upload failed",
      });
      failed += 1;
    }
  }

  return { succeeded, failed };
}

import type { ClipboardEntry } from "../api";
import { fetchClipboardEntry, getAccessToken, getServerUrl } from "../api";

export function isImageContentType(contentType: string): boolean {
  return contentType.startsWith("image/");
}

export function isImageMime(mime: string): boolean {
  return mime.startsWith("image/");
}

export function imageDataUrl(entry: ClipboardEntry): string {
  if (!entry.content) return "";
  if (entry.content.startsWith("data:")) return entry.content;
  return `data:${entry.content_type};base64,${entry.content}`;
}

export async function fetchClipboardThumbnail(entryId: string): Promise<Blob | null> {
  const base = getServerUrl().replace(/\/$/, "");
  const token = getAccessToken();
  if (!token) return null;

  const res = await fetch(`${base}/api/v1/clipboard/${entryId}/thumbnail`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) return null;
  return res.blob();
}

export async function fileToBase64(file: File): Promise<string> {
  const buffer = await file.arrayBuffer();
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

export async function blobToBase64(blob: Blob): Promise<string> {
  return fileToBase64(new File([blob], "clipboard", { type: blob.type }));
}

export async function copyBlobToClipboard(blob: Blob): Promise<void> {
  const type = blob.type || "image/png";
  await navigator.clipboard.write([new ClipboardItem({ [type]: blob })]);
}

export async function copyEntryToClipboard(entry: ClipboardEntry): Promise<void> {
  if (isImageContentType(entry.content_type)) {
    let content = entry.content;
    if (!content) {
      const full = await fetchClipboardEntry(entry.id);
      content = full.content;
    }
    if (content) {
      try {
        const dataUrl = content.startsWith("data:")
          ? content
          : `data:${entry.content_type};base64,${content}`;
        const res = await fetch(dataUrl);
        const blob = await res.blob();
        await copyBlobToClipboard(blob);
        return;
      } catch {
        /* try thumbnail below */
      }
    }
    const thumb = await fetchClipboardThumbnail(entry.id);
    if (thumb) {
      await copyBlobToClipboard(thumb);
      return;
    }
    throw new Error("Image unavailable");
  }
  await navigator.clipboard.writeText(entry.content);
}

export async function copyFileToClipboard(fileId: string, mimeType: string): Promise<void> {
  const base = getServerUrl().replace(/\/$/, "");
  const token = getAccessToken();
  if (!token) throw new Error("Not authenticated");

  const res = await fetch(`${base}/api/v1/files/${fileId}/download`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new Error("Download failed");

  const blob = await res.blob();
  const typed = blob.type ? blob : new Blob([blob], { type: mimeType });
  await copyBlobToClipboard(typed);
}

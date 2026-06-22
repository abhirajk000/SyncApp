import type { ClipboardEntry } from "../api";
import { getAccessToken, getServerUrl } from "../api";

export function isImageContentType(contentType: string): boolean {
  return contentType.startsWith("image/");
}

export function isImageMime(mime: string): boolean {
  return mime.startsWith("image/");
}

export function imageDataUrl(entry: ClipboardEntry): string {
  if (entry.content.startsWith("data:")) return entry.content;
  return `data:${entry.content_type};base64,${entry.content}`;
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
    const res = await fetch(imageDataUrl(entry));
    const blob = await res.blob();
    await copyBlobToClipboard(blob);
    return;
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

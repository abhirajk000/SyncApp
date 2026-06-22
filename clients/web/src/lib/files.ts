import { getAccessToken, getServerUrl } from "../api";
import { isImageMime } from "./clipboard";

export async function fetchFileBlob(fileId: string): Promise<Blob> {
  const base = getServerUrl().replace(/\/$/, "");
  const token = getAccessToken();
  if (!token) throw new Error("Not authenticated");

  const res = await fetch(`${base}/api/v1/files/${fileId}/download`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new Error("Download failed");
  return res.blob();
}

export async function fetchFileThumbnail(fileId: string): Promise<Blob | null> {
  const base = getServerUrl().replace(/\/$/, "");
  const token = getAccessToken();
  if (!token) return null;

  const res = await fetch(`${base}/api/v1/files/${fileId}/thumbnail`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) return null;
  return res.blob();
}

export async function downloadFile(fileId: string, filename: string): Promise<void> {
  const blob = await fetchFileBlob(fileId);
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

export async function copyTextFile(fileId: string): Promise<void> {
  const blob = await fetchFileBlob(fileId);
  const text = await blob.text();
  await navigator.clipboard.writeText(text);
}

export function isTextMime(mime: string): boolean {
  return mime.startsWith("text/") || mime === "application/json";
}

export type FilePreviewKind = "image" | "text" | "video" | "pdf" | "archive" | "document" | "generic";

const TEXT_EXTENSIONS = new Set(["txt", "md", "markdown", "csv", "json", "log", "xml", "yaml", "yml"]);

export function getFileExtension(name: string): string {
  const dot = name.lastIndexOf(".");
  if (dot <= 0) return "";
  return name.slice(dot + 1).toLowerCase();
}

export function getFilePreviewKind(mime: string, name: string): FilePreviewKind {
  const ext = getFileExtension(name);

  if (isImageMime(mime)) return "image";
  if (isTextMime(mime) || TEXT_EXTENSIONS.has(ext)) return "text";
  if (mime.startsWith("video/")) return "video";
  if (mime === "application/pdf") return "pdf";
  if (
    mime.includes("zip") ||
    mime.includes("tar") ||
    mime.includes("gzip") ||
    mime.includes("7z") ||
    ["zip", "rar", "7z", "tar", "gz"].includes(ext)
  ) {
    return "archive";
  }
  if (
    mime.includes("word") ||
    mime.includes("excel") ||
    mime.includes("powerpoint") ||
    mime.includes("spreadsheet") ||
    mime.includes("presentation") ||
    ["doc", "docx", "xls", "xlsx", "ppt", "pptx"].includes(ext)
  ) {
    return "document";
  }
  return "generic";
}

export const TEXT_PREVIEW_MAX_BYTES = 512 * 1024;

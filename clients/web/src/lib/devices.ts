import type { LucideIcon } from "lucide-react";
import { Laptop, Monitor, Smartphone, Tablet } from "lucide-react";
import type { DeviceEntry } from "../api";
import { relativeTime } from "./format";

const DEVICE_NAME_KEY = "syncbridge.deviceName";

export function defaultWebDeviceName(): string {
  const ua = navigator.userAgent;
  if (/iPhone/.test(ua)) return "iPhone";
  if (/iPad/.test(ua)) return "iPad";
  if (/Android/.test(ua)) {
    const model = ua.match(/;\s*([^;)]+)\s+Build\//);
    if (model?.[1]) return model[1].trim();
    return "Android Phone";
  }
  if (/Macintosh/.test(ua)) return "Mac";
  if (/Windows/.test(ua)) return "Windows PC";
  if (/Linux/.test(ua)) return "Linux PC";
  return "Web Browser";
}

export function getLocalDeviceName(): string {
  return localStorage.getItem(DEVICE_NAME_KEY) || defaultWebDeviceName();
}

export function setLocalDeviceName(name: string): void {
  localStorage.setItem(DEVICE_NAME_KEY, name.trim());
}

export function platformLabel(platform: string): string {
  switch (platform) {
    case "macos":
      return "Mac";
    case "android":
      return "Android";
    case "ios":
      return "iPhone";
    case "web":
      return "Web";
    default:
      return platform;
  }
}

export function platformIcon(platform: string): LucideIcon {
  switch (platform) {
    case "macos":
      return Laptop;
    case "android":
      return Smartphone;
    case "ios":
      return Smartphone;
    case "web":
      return Monitor;
    default:
      return Tablet;
  }
}

export function lastSeenLabel(device: DeviceEntry): string {
  if (device.online) return "Online now";
  if (device.last_seen_at) return `Last seen ${relativeTime(device.last_seen_at)}`;
  return "Never seen";
}

export function onlineStatusLabel(device: DeviceEntry): string {
  return device.online ? "Online" : "Offline";
}

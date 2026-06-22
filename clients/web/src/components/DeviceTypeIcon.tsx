import type { LucideIcon } from "lucide-react";
import { platformIcon } from "../lib/devices";

interface Props {
  platform: string;
  size?: number;
  className?: string;
}

export function DeviceTypeIcon({ platform, size = 20, className }: Props) {
  const Icon: LucideIcon = platformIcon(platform);
  return <Icon size={size} strokeWidth={1.75} className={className} />;
}

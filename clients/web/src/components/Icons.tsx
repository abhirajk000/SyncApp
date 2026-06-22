import type { LucideIcon, LucideProps } from "lucide-react";
import {
  Clipboard,
  Code,
  FileText,
  Folder,
  Image,
  Laptop,
  LayoutDashboard,
  Link,
  LogOut,
  Monitor,
  Moon,
  Pin,
  RefreshCw,
  Send,
  Settings,
  Sparkles,
  Sun,
  Type,
  Upload,
  Wifi,
} from "lucide-react";

export type IconProps = LucideProps & { size?: number };

function icon(IconComponent: LucideIcon) {
  return function Wrapped({ size = 20, strokeWidth = 1.75, ...rest }: IconProps) {
    return <IconComponent size={size} strokeWidth={strokeWidth} {...rest} />;
  };
}

export const IconSync = icon(RefreshCw);
export const IconDashboard = icon(LayoutDashboard);
export const IconClipboard = icon(Clipboard);
export const IconPin = icon(Pin);
export const IconFolder = icon(Folder);
export const IconImage = icon(Image);
export const IconDevices = icon(Laptop);
export const IconSettings = icon(Settings);
export const IconLogout = icon(LogOut);
export const IconUpload = icon(Upload);
export const IconSpark = icon(Sparkles);
export const IconSend = icon(Send);
export const IconSun = icon(Sun);
export const IconMoon = icon(Moon);
export const IconWifi = icon(Wifi);
export const IconFile = icon(FileText);
export const IconLink = icon(Link);
export const IconCode = icon(Code);
export const IconText = icon(Type);
export const IconMonitor = icon(Monitor);

interface ContentTypeIconProps extends IconProps {
  contentType: string;
}

export function ContentTypeIcon({ contentType, size = 16, className, ...rest }: ContentTypeIconProps) {
  if (contentType.startsWith("image/")) {
    return <Image size={size} strokeWidth={1.75} className={className} {...rest} />;
  }
  if (contentType.includes("uri")) {
    return <Link size={size} strokeWidth={1.75} className={className} {...rest} />;
  }
  if (contentType.includes("html")) {
    return <Code size={size} strokeWidth={1.75} className={className} {...rest} />;
  }
  return <Type size={size} strokeWidth={1.75} className={className} {...rest} />;
}

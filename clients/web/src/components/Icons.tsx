import type { SVGProps } from "react";

type IconProps = SVGProps<SVGSVGElement> & { size?: number };

function Icon({ size = 20, className, children, ...rest }: IconProps & { children: React.ReactNode }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      aria-hidden
      {...rest}
    >
      {children}
    </svg>
  );
}

export function IconSync({ size, className }: IconProps) {
  return (
    <Icon size={size} className={className}>
      <path d="M21 12a9 9 0 1 1-2.64-6.36" />
      <path d="M21 3v6h-6" />
    </Icon>
  );
}

export function IconDashboard({ size, className }: IconProps) {
  return (
    <Icon size={size} className={className}>
      <rect x="3" y="3" width="7" height="9" rx="2" />
      <rect x="14" y="3" width="7" height="5" rx="2" />
      <rect x="14" y="12" width="7" height="9" rx="2" />
      <rect x="3" y="16" width="7" height="5" rx="2" />
    </Icon>
  );
}

export function IconClipboard({ size, className }: IconProps) {
  return (
    <Icon size={size} className={className}>
      <rect x="8" y="4" width="8" height="4" rx="1" />
      <path d="M9 4H8a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2h-1" />
      <path d="M9 12h6M9 16h4" />
    </Icon>
  );
}

export function IconPin({ size, className }: IconProps) {
  return (
    <Icon size={size} className={className}>
      <path d="M12 17v5" />
      <path d="M9 3h6l1 7h4l-7 7-7-7h4z" />
    </Icon>
  );
}

export function IconFolder({ size, className }: IconProps) {
  return (
    <Icon size={size} className={className}>
      <path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
    </Icon>
  );
}

export function IconImage({ size, className }: IconProps) {
  return (
    <Icon size={size} className={className}>
      <rect x="3" y="5" width="18" height="14" rx="2" />
      <circle cx="9" cy="10" r="1.5" fill="currentColor" stroke="none" />
      <path d="m21 17-5-5-4 4-2-2-5 5" />
    </Icon>
  );
}

export function IconDevices({ size, className }: IconProps) {
  return (
    <Icon size={size} className={className}>
      <rect x="2" y="5" width="14" height="10" rx="2" />
      <path d="M18 9h2a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H8" />
    </Icon>
  );
}

export function IconSettings({ size, className }: IconProps) {
  return (
    <Icon size={size} className={className}>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41" />
    </Icon>
  );
}

export function IconLogout({ size, className }: IconProps) {
  return (
    <Icon size={size} className={className}>
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
      <path d="m16 17 5-5-5-5" />
      <path d="M21 12H9" />
    </Icon>
  );
}

export function IconUpload({ size, className }: IconProps) {
  return (
    <Icon size={size} className={className}>
      <path d="M12 16V4" />
      <path d="m8 8 4-4 4 4" />
      <path d="M4 20h16" />
    </Icon>
  );
}

export function IconSpark({ size, className }: IconProps) {
  return (
    <Icon size={size} className={className}>
      <path d="M12 3 9.5 9.5 3 12l6.5 2.5L12 21l2.5-6.5L21 12l-6.5-2.5z" />
    </Icon>
  );
}

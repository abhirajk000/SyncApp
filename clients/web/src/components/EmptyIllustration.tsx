import type { ReactElement } from "react";

export type EmptyIllustrationVariant =
  | "clipboard"
  | "files"
  | "send"
  | "devices"
  | "pinned"
  | "inbox";

interface Props {
  variant?: EmptyIllustrationVariant;
  className?: string;
}

function ClipboardArt() {
  return (
    <svg viewBox="0 0 48 48" fill="none" aria-hidden>
      <rect x="10" y="8" width="28" height="34" rx="6" stroke="currentColor" strokeWidth="2" opacity="0.9" />
      <path d="M18 8V6a6 6 0 0112 0v2" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
      <path d="M16 22h16M16 28h11" stroke="currentColor" strokeWidth="2" strokeLinecap="round" opacity="0.7" />
      <circle cx="34" cy="34" r="8" fill="currentColor" opacity="0.15" />
      <path d="M31 34l2 2 4-4" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function FilesArt() {
  return (
    <svg viewBox="0 0 48 48" fill="none" aria-hidden>
      <path d="M14 6h14l8 8v28a4 4 0 01-4 4H14a4 4 0 01-4-4V10a4 4 0 014-4z" stroke="currentColor" strokeWidth="2" />
      <path d="M28 6v8h8" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" />
      <path d="M16 26h16M16 32h12" stroke="currentColor" strokeWidth="2" strokeLinecap="round" opacity="0.65" />
    </svg>
  );
}

function SendArt() {
  return (
    <svg viewBox="0 0 48 48" fill="none" aria-hidden>
      <circle cx="24" cy="24" r="18" stroke="currentColor" strokeWidth="2" opacity="0.35" />
      <path d="M12 24l20-10-4 10 4 10-20-10z" fill="currentColor" opacity="0.2" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" />
      <path d="M16 24h14" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
    </svg>
  );
}

function DevicesArt() {
  return (
    <svg viewBox="0 0 48 48" fill="none" aria-hidden>
      <rect x="6" y="12" width="22" height="16" rx="3" stroke="currentColor" strokeWidth="2" />
      <rect x="20" y="20" width="22" height="16" rx="3" stroke="currentColor" strokeWidth="2" opacity="0.75" />
      <circle cx="17" cy="36" r="1.5" fill="currentColor" />
      <circle cx="31" cy="36" r="1.5" fill="currentColor" opacity="0.75" />
    </svg>
  );
}

function PinnedArt() {
  return (
    <svg viewBox="0 0 48 48" fill="none" aria-hidden>
      <path d="M24 6l3 9h9l-7 5 3 9-8-6-8 6 3-9-7-5h9l3-9z" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" fill="currentColor" opacity="0.12" />
      <circle cx="24" cy="38" r="3" fill="currentColor" opacity="0.35" />
    </svg>
  );
}

function InboxArt() {
  return (
    <svg viewBox="0 0 48 48" fill="none" aria-hidden>
      <path d="M8 14h32l-4 22H12L8 14z" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" />
      <path d="M8 14l6 8h20l6-8" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" />
      <path d="M20 22h8l3 6H17l3-6z" fill="currentColor" opacity="0.15" stroke="currentColor" strokeWidth="1.5" />
    </svg>
  );
}

const art: Record<EmptyIllustrationVariant, () => ReactElement> = {
  clipboard: ClipboardArt,
  files: FilesArt,
  send: SendArt,
  devices: DevicesArt,
  pinned: PinnedArt,
  inbox: InboxArt,
};

export function EmptyIllustration({ variant = "inbox", className = "" }: Props) {
  const Art = art[variant];
  return (
    <div className={`ds-empty-illustration ${className}`.trim()} aria-hidden>
      <Art />
    </div>
  );
}

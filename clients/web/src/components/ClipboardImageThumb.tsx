import { useEffect, useState } from "react";
import { fetchClipboardThumbnail } from "../lib/clipboard";

interface Props {
  entryId: string;
  alt?: string;
  className?: string;
}

export function ClipboardImageThumb({ entryId, alt = "", className = "ds-activity-thumb" }: Props) {
  const [src, setSrc] = useState<string | null>(null);

  useEffect(() => {
    let objectUrl: string | null = null;
    let cancelled = false;

    void fetchClipboardThumbnail(entryId).then((blob) => {
      if (cancelled || !blob) return;
      objectUrl = URL.createObjectURL(blob);
      setSrc(objectUrl);
    });

    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [entryId]);

  if (!src) {
    return <span className={`${className} ds-thumb-placeholder`} aria-hidden />;
  }

  return <img src={src} alt={alt} className={className} draggable={false} loading="lazy" />;
}

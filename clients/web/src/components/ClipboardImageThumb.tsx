import { useEffect, useState } from "react";
import { fetchClipboardThumbnail, getCachedThumbnailUrl, cacheThumbnailBlob } from "../lib/clipboard";
import { ImagePlaceholder } from "./ImagePlaceholder";

interface Props {
  entryId: string;
  alt?: string;
  className?: string;
}

export function ClipboardImageThumb({ entryId, alt = "", className = "ds-activity-thumb" }: Props) {
  const [src, setSrc] = useState<string | null>(() => getCachedThumbnailUrl(entryId));

  useEffect(() => {
    const cached = getCachedThumbnailUrl(entryId);
    if (cached) {
      setSrc(cached);
      return;
    }

    let cancelled = false;

    void fetchClipboardThumbnail(entryId).then((blob) => {
      if (cancelled || !blob) return;
      setSrc(cacheThumbnailBlob(entryId, blob));
    });

    return () => {
      cancelled = true;
    };
  }, [entryId]);

  if (!src) {
    return <ImagePlaceholder className={className} aspectRatio="16/10" />;
  }

  return <img src={src} alt={alt} className={className} draggable={false} loading="lazy" />;
}

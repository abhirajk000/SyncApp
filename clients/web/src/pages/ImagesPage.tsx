import { AppEmptyState } from "../components";
import { IconImage } from "../components/Icons";

export function ImagesPage() {
  return (
    <AppEmptyState
      icon={<IconImage size={24} />}
      title="No images yet"
      description="Screenshot and image clipboard sync will appear here when available on your devices."
    />
  );
}

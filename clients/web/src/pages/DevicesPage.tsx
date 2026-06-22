import { AppEmptyState } from "../components";
import { IconDevices } from "../components/Icons";

export function DevicesPage() {
  return (
    <AppEmptyState
      icon={<IconDevices size={24} />}
      title="Device management"
      description="View and manage your connected devices from the macOS menu bar app. Web device management coming soon."
    />
  );
}

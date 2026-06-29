import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ClipboardEntry,
  DeviceEntry,
  deleteClipboardEntry,
  fetchClipboardHistory,
  fetchDevices,
  getAccessToken,
  pinClipboard,
} from "../api";
import {
  AppBottomSheet,
  AppButton,
  AppEmptyState,
  AppSearchField,
  AppSkeleton,
  ClipboardCard,
} from "../components";
import { ClipboardImageThumb } from "../components/ClipboardImageThumb";
import { copyEntryToClipboard, imageDataUrl, isImageContentType } from "../lib/clipboard";
import { useToast } from "../design/ToastProvider";
import { useNetwork } from "../design/NetworkProvider";

type FilterId = "all" | "text" | "images";

const FILTERS: { id: FilterId; label: string }[] = [
  { id: "all", label: "All" },
  { id: "text", label: "Text" },
  { id: "images", label: "Images" },
];

type DayGroup = { label: string; items: ClipboardEntry[] };

function dayLabel(iso: string): string {
  const d = new Date(iso);
  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startOfDay = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const diff = (startOfToday.getTime() - startOfDay.getTime()) / 86_400_000;
  if (diff === 0) return "Today";
  if (diff === 1) return "Yesterday";
  if (diff < 7) {
    return d.toLocaleDateString(undefined, { weekday: "long" });
  }
  return d.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
}

function groupByDay(entries: ClipboardEntry[]): DayGroup[] {
  const map = new Map<string, ClipboardEntry[]>();
  for (const entry of entries) {
    const label = dayLabel(entry.created_at);
    const bucket = map.get(label) ?? [];
    bucket.push(entry);
    map.set(label, bucket);
  }
  return Array.from(map.entries()).map(([label, items]) => ({ label, items }));
}

function matchesFilter(entry: ClipboardEntry, filter: FilterId): boolean {
  if (filter === "images") return isImageContentType(entry.content_type);
  if (filter === "text") return !isImageContentType(entry.content_type);
  return true;
}

function matchesSearch(entry: ClipboardEntry, query: string): boolean {
  const q = query.trim().toLowerCase();
  if (!q) return true;
  if (isImageContentType(entry.content_type)) return "image".includes(q);
  return entry.content.toLowerCase().includes(q);
}

export function ClipboardTimelinePage({ embedded = false }: { embedded?: boolean }) {
  const { toast } = useToast();
  const net = useNetwork();
  const [entries, setEntries] = useState<ClipboardEntry[]>([]);
  const [devices, setDevices] = useState<DeviceEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<FilterId>("all");
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [insertingIds, setInsertingIds] = useState<Set<string>>(new Set());
  const [preview, setPreview] = useState<ClipboardEntry | null>(null);
  const peerIds = useRef(new Set<string>());

  useEffect(() => {
    peerIds.current = new Set(net.peers.map((p) => p.device_id));
  }, [net.peers]);

  const deviceNameById = useMemo(() => {
    const map = new Map<string, string>();
    const source = devices.length ? devices : net.devices;
    for (const d of source) map.set(d.id, d.name);
    return map;
  }, [devices, net.devices]);

  const load = useCallback(async () => {
    if (!getAccessToken()) return;
    setLoading(true);
    try {
      const [clip, deviceData] = await Promise.all([
        fetchClipboardHistory(),
        fetchDevices().catch(() => ({ devices: [] as DeviceEntry[], total: 0 })),
      ]);
      setEntries(
        [...clip.entries].sort(
          (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
        ),
      );
      setDevices(deviceData.devices);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    function onNew(e: Event) {
      const entry = (e as CustomEvent<ClipboardEntry>).detail;
      if (!entry) return;
      setEntries((prev) => [entry, ...prev.filter((x) => x.id !== entry.id)]);
      setInsertingIds((prev) => new Set(prev).add(entry.id));
      window.setTimeout(() => {
        setInsertingIds((prev) => {
          const next = new Set(prev);
          next.delete(entry.id);
          return next;
        });
      }, 600);
      setLoading(false);
    }
    function onPin(e: Event) {
      const detail = (e as CustomEvent<{ entry_id?: string; pinned?: boolean }>).detail;
      if (!detail?.entry_id || detail.pinned === undefined) {
        void load();
        return;
      }
      setEntries((prev) =>
        prev.map((x) => (x.id === detail.entry_id ? { ...x, pinned: detail.pinned! } : x)),
      );
    }
    function onRefresh() {
      void load();
    }
    window.addEventListener("syncbridge:clipboard-new", onNew);
    window.addEventListener("syncbridge:clipboard-pin", onPin);
    window.addEventListener("syncbridge:app-refresh", onRefresh);
    return () => {
      window.removeEventListener("syncbridge:clipboard-new", onNew);
      window.removeEventListener("syncbridge:clipboard-pin", onPin);
      window.removeEventListener("syncbridge:app-refresh", onRefresh);
    };
  }, [load]);

  const filtered = useMemo(() => {
    return entries.filter((e) => matchesFilter(e, filter) && matchesSearch(e, search));
  }, [entries, filter, search]);

  const groups = useMemo(() => groupByDay(filtered), [filtered]);

  async function copyEntry(entry: ClipboardEntry) {
    try {
      await copyEntryToClipboard(entry);
      setCopiedId(entry.id);
      window.setTimeout(() => setCopiedId((id) => (id === entry.id ? null : id)), 850);
      toast(isImageContentType(entry.content_type) ? "Image copied" : "Copied", "success");
    } catch {
      toast("Could not copy", "danger");
    }
  }

  async function togglePin(entry: ClipboardEntry) {
    try {
      await pinClipboard(entry.id, !entry.pinned);
      setEntries((prev) =>
        prev.map((x) => (x.id === entry.id ? { ...x, pinned: !entry.pinned } : x)),
      );
      toast(entry.pinned ? "Unpinned" : "Pinned", "success");
    } catch {
      toast("Could not update pin", "danger");
    }
  }

  async function remove(entry: ClipboardEntry) {
    try {
      await deleteClipboardEntry(entry);
      setEntries((prev) => prev.filter((x) => x.id !== entry.id));
      if (preview?.id === entry.id) setPreview(null);
      toast("Deleted", "success");
    } catch {
      toast("Could not delete", "danger");
    }
  }

  function transferRoute(entry: ClipboardEntry): string {
    if (entry.transfer_route) return entry.transfer_route;
    return peerIds.current.has(entry.source_device_id) ? "direct_lan" : "relay";
  }

  function deviceLabel(entry: ClipboardEntry): string | undefined {
    const name = deviceNameById.get(entry.source_device_id);
    return name ?? (entry.source_device_id ? "Device" : undefined);
  }

  function renderCard(entry: ClipboardEntry) {
    const isImage = isImageContentType(entry.content_type);
    const large = !isImage && entry.content.length > 180;

    return (
      <ClipboardCard
        key={entry.id}
        content={isImage ? "" : entry.content}
        createdAt={entry.created_at}
        pinned={entry.pinned}
        deviceName={deviceLabel(entry)}
        transferRoute={transferRoute(entry)}
        copied={copiedId === entry.id}
        inserting={insertingIds.has(entry.id)}
        large={large}
        isImage={isImage}
        onCopy={() => void copyEntry(entry)}
        onDelete={() => void remove(entry)}
        onPin={() => void togglePin(entry)}
        onPreview={() => setPreview(entry)}
      >
        {isImage &&
          (entry.has_thumbnail || !entry.content ? (
            <ClipboardImageThumb
              entryId={entry.id}
              className="ds-clipboard-card__image ds-image-preview"
            />
          ) : (
            <img
              src={imageDataUrl(entry)}
              alt=""
              className="ds-clipboard-card__image"
              loading="lazy"
              draggable={false}
            />
          ))}
      </ClipboardCard>
    );
  }

  if (loading && entries.length === 0) {
    return embedded ? (
      <AppSkeleton rows={8} />
    ) : (
      <div className="sb-page-stack">
        <div>
          <h1 className="ds-page-title">Clipboard</h1>
          <p className="ds-page-lead">Your synced clipboard history across all devices.</p>
        </div>
        <AppSkeleton rows={8} />
      </div>
    );
  }

  return (
    <>
      <div className={`sb-page-stack ds-clipboard-timeline ${embedded ? "ds-clipboard-timeline--embedded" : ""}`}>
        {!embedded && (
          <div>
            <h1 className="ds-page-title">Clipboard</h1>
            <p className="ds-page-lead">Your synced clipboard history across all devices.</p>
          </div>
        )}
        <div className="ds-clipboard-timeline__toolbar">
          <AppSearchField
            value={search}
            onChange={setSearch}
            placeholder="Search clipboard…"
            aria-label="Search clipboard"
          />
          <div className="ds-clipboard-timeline__filters" role="tablist" aria-label="Filter clipboard">
            {FILTERS.map((f) => (
              <button
                key={f.id}
                type="button"
                role="tab"
                aria-selected={filter === f.id}
                className={`ds-chip ds-chip--${filter === f.id ? "primary" : "neutral"}`}
                onClick={() => setFilter(f.id)}
              >
                {f.label}
              </button>
            ))}
          </div>
        </div>

        {filtered.length === 0 ? (
          <AppEmptyState
            illustration="clipboard"
            title={search ? "No matches" : "No clipboard items"}
            description={
              search
                ? "Try a different search or filter."
                : "Copy text or an image on any device — it appears here instantly."
            }
          />
        ) : (
          groups.map((group) => (
            <section key={group.label} className="ds-clipboard-timeline__group">
              <h2 className="ds-clipboard-timeline__date">{group.label}</h2>
              <div className="sb-oneui-container sb-oneui-container--glass ds-clipboard-timeline__rail sb-stagger">
                {group.items.map((entry) => renderCard(entry))}
              </div>
            </section>
          ))
        )}
      </div>

      <AppBottomSheet
        open={!!preview}
        title="Preview"
        onClose={() => setPreview(null)}
      >
        {preview && (
          <>
            {isImageContentType(preview.content_type) ? (
              preview.has_thumbnail || !preview.content ? (
                <ClipboardImageThumb
                  entryId={preview.id}
                  className="ds-clipboard-preview__image"
                />
              ) : (
                <img
                  src={imageDataUrl(preview)}
                  alt=""
                  className="ds-clipboard-preview__image"
                />
              )
            ) : (
              <p className="ds-clipboard-preview__text">{preview.content}</p>
            )}
            <AppButton
              block
              className="sb-mt-4"
              onClick={() => void copyEntry(preview)}
            >
              {isImageContentType(preview.content_type) ? "Copy image" : "Copy"}
            </AppButton>
          </>
        )}
      </AppBottomSheet>
    </>
  );
}

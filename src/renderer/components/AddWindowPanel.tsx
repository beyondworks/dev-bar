import { useState, useRef, useEffect } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import type { WindowInfo, InstalledApp } from '@shared/types';
import { useDockStore } from '../stores/dock-store';
import { useWindowList } from '../hooks/use-window-list';

interface AddWindowPanelProps {
  onClose: () => void;
}

export function AddWindowPanel({ onClose }: AddWindowPanelProps) {
  const addItem = useDockStore((s) => s.addItem);
  const dockItems = useDockStore((s) => s.items);
  const [query, setQuery] = useState('');
  const [selectedIdx, setSelectedIdx] = useState(0);
  const { windows, loading, error } = useWindowList(true);
  const inputRef = useRef<HTMLInputElement>(null);
  const [iconCache, setIconCache] = useState<Record<string, string>>({});
  const [installedApps, setInstalledApps] = useState<InstalledApp[]>([]);

  // Fetch installed apps on mount
  useEffect(() => {
    if (!window.devdock?.listInstalledApps) return;
    window.devdock.listInstalledApps().then(setInstalledApps).catch(() => {});
  }, []);

  // Fetch icons for all unique bundleIds
  useEffect(() => {
    const bundleIds = [
      ...new Set([
        ...windows.map((w) => w.bundleId).filter(Boolean),
        ...installedApps.map((a) => a.bundleId).filter(Boolean),
      ]),
    ];
    bundleIds.forEach(async (bid) => {
      if (iconCache[bid]) return;
      try {
        const icon = await window.devdock.getAppIcon(bid);
        if (icon) setIconCache((prev) => ({ ...prev, [bid]: icon }));
      } catch { /* ignore */ }
    });
  }, [windows, installedApps]);

  // Filter out windows already in the dock (by windowId)
  const existingWindowIds = new Set(dockItems.map((i) => i.windowId));
  const existingBundleIds = new Set(dockItems.map((i) => i.bundleId));
  // bundleIds of running windows (to exclude from installed list)
  const runningBundleIds = new Set(windows.map((w) => w.bundleId).filter(Boolean));

  const filtered = windows.filter((w) => {
    if (existingWindowIds.has(w.windowId)) return false;
    if (w.bundleId === 'com.electron.devdock' || w.ownerName === 'Electron') return false;
    const q = query.toLowerCase();
    return (
      w.ownerName.toLowerCase().includes(q) ||
      w.windowName.toLowerCase().includes(q)
    );
  });

  // Installed apps not already in dock and not currently running
  const filteredApps = installedApps.filter((a) => {
    if (existingBundleIds.has(a.bundleId)) return false;
    if (runningBundleIds.has(a.bundleId)) return false;
    const q = query.toLowerCase();
    return a.appName.toLowerCase().includes(q) || a.bundleId.toLowerCase().includes(q);
  });

  const totalItems = filtered.length + filteredApps.length;

  // Reset selection when filter changes
  useEffect(() => {
    setSelectedIdx(0);
  }, [query]);

  // Auto-focus input
  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  const handleAddWindow = async (w: WindowInfo) => {
    let iconBase64 = '';
    if (w.bundleId) {
      iconBase64 = await window.devdock.getAppIcon(w.bundleId);
    }
    addItem({
      windowId: w.windowId,
      pid: w.pid,
      bundleId: w.bundleId,
      ownerName: w.ownerName,
      windowName: w.windowName,
      customName: '',
      notes: '',
      iconBase64,
      isAlive: true,
    });
    onClose();
  };

  const handleAddApp = async (app: InstalledApp) => {
    let iconBase64 = '';
    iconBase64 = iconCache[app.bundleId] || '';
    if (!iconBase64) {
      try { iconBase64 = await window.devdock.getAppIcon(app.bundleId); } catch { /* */ }
    }
    addItem({
      windowId: 0,
      pid: 0,
      bundleId: app.bundleId,
      ownerName: app.appName,
      windowName: '',
      customName: '',
      notes: '',
      iconBase64,
      isAlive: false,
    });
    onClose();
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setSelectedIdx((i) => Math.min(i + 1, totalItems - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setSelectedIdx((i) => Math.max(i - 1, 0));
    } else if (e.key === 'Enter') {
      if (selectedIdx < filtered.length) {
        if (filtered[selectedIdx]) handleAddWindow(filtered[selectedIdx]);
      } else {
        const appIdx = selectedIdx - filtered.length;
        if (filteredApps[appIdx]) handleAddApp(filteredApps[appIdx]);
      }
    } else if (e.key === 'Escape') {
      onClose();
    }
  };

  const handleBackdropClick = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) onClose();
  };

  return (
    <div style={styles.backdrop} onClick={handleBackdropClick}>
      <motion.div
        style={styles.panel}
        initial={{ opacity: 0, y: 10, scale: 0.96 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        exit={{ opacity: 0, y: 10, scale: 0.96 }}
        transition={{ type: 'spring', stiffness: 420, damping: 30 }}
      >
        {/* Specular top edge */}
        <div style={styles.specularEdge} />

        {/* Search bar - Spotlight style */}
        <div style={styles.searchRow}>
          <svg style={styles.searchIcon} width="14" height="14" viewBox="0 0 16 16" fill="none">
            <circle cx="6.5" cy="6.5" r="5" stroke="rgba(255,255,255,0.38)" strokeWidth="1.5"/>
            <path d="M10.5 10.5l3 3" stroke="rgba(255,255,255,0.38)" strokeWidth="1.5" strokeLinecap="round"/>
          </svg>
          <input
            ref={inputRef}
            style={styles.searchInput}
            type="text"
            placeholder="Search apps or windows…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={handleKeyDown}
          />
          {query && (
            <button
              style={styles.clearBtn}
              onClick={() => { setQuery(''); inputRef.current?.focus(); }}
              tabIndex={-1}
            >
              <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
                <circle cx="5" cy="5" r="4.5" fill="rgba(255,255,255,0.18)"/>
                <path d="M3.2 3.2l3.6 3.6M6.8 3.2L3.2 6.8" stroke="rgba(255,255,255,0.65)" strokeWidth="1.2" strokeLinecap="round"/>
              </svg>
            </button>
          )}
        </div>

        {/* Separator */}
        <div style={styles.separator} />

        {/* Results list */}
        <div style={styles.list}>
          {loading && (
            <div style={styles.emptyState}>
              <div style={styles.spinner} />
              <span style={styles.emptyText}>Loading windows…</span>
            </div>
          )}
          {error && (
            <div style={styles.emptyState}>
              <span style={{ ...styles.emptyText, color: 'rgba(255,80,70,0.85)' }}>
                {error}
              </span>
            </div>
          )}
          {!loading && !error && totalItems === 0 && (
            <div style={styles.emptyState}>
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" style={{ opacity: 0.25 }}>
                <circle cx="11" cy="11" r="7.5" stroke="white" strokeWidth="1.5"/>
                <path d="M16.5 16.5l4 4" stroke="white" strokeWidth="1.5" strokeLinecap="round"/>
              </svg>
              <span style={styles.emptyText}>No windows or apps found</span>
            </div>
          )}

          {/* Running windows section */}
          <AnimatePresence initial={false}>
            {filtered.map((w, idx) => {
              const sameAppWindows = filtered.filter((f) => f.ownerName === w.ownerName);
              const windowIndex = sameAppWindows.length > 1
                ? sameAppWindows.indexOf(w) + 1
                : 0;
              return (
                <WindowRow
                  key={`${w.pid}-${w.windowId}`}
                  window={w}
                  windowIndex={windowIndex}
                  isSelected={idx === selectedIdx}
                  onSelect={() => setSelectedIdx(idx)}
                  onAdd={() => handleAddWindow(w)}
                  iconBase64={w.bundleId ? iconCache[w.bundleId] : undefined}
                />
              );
            })}
          </AnimatePresence>

          {/* Divider between windows and installed apps */}
          {filtered.length > 0 && filteredApps.length > 0 && (
            <div style={styles.sectionDivider}>
              <div style={styles.separator} />
              <span style={styles.sectionLabel}>Installed Apps</span>
            </div>
          )}

          {/* Installed apps section */}
          {filteredApps.length > 0 && filtered.length === 0 && !loading && (
            <div style={styles.sectionDivider}>
              <span style={styles.sectionLabel}>Installed Apps</span>
            </div>
          )}
          <AnimatePresence initial={false}>
            {filteredApps.map((app, idx) => {
              const globalIdx = filtered.length + idx;
              return (
                <AppRow
                  key={app.bundleId}
                  app={app}
                  isSelected={globalIdx === selectedIdx}
                  onSelect={() => setSelectedIdx(globalIdx)}
                  onAdd={() => handleAddApp(app)}
                  iconBase64={iconCache[app.bundleId]}
                />
              );
            })}
          </AnimatePresence>
        </div>

        {/* Footer hint */}
        {totalItems > 0 && (
          <div style={styles.footer}>
            <KbdHint keys={['↑', '↓']} label="navigate" />
            <KbdHint keys={['↵']} label="add" />
            <KbdHint keys={['esc']} label="close" />
          </div>
        )}
      </motion.div>
    </div>
  );
}

// ─── Window row ──────────────────────────────────────────────────
function WindowRow({
  window: w,
  windowIndex,
  isSelected,
  onSelect,
  onAdd,
  iconBase64,
}: {
  window: WindowInfo;
  windowIndex: number;
  isSelected: boolean;
  onSelect: () => void;
  onAdd: () => void;
  iconBase64?: string;
}) {
  const initial = w.ownerName.charAt(0).toUpperCase();

  let subtitle = '';
  if (w.windowName && w.windowName !== w.ownerName) {
    subtitle = w.windowName;
  } else if (windowIndex > 0) {
    subtitle = `Window #${windowIndex}`;
  }

  return (
    <motion.button
      style={{
        ...styles.windowItem,
        background: isSelected ? 'rgba(0,122,255,0.18)' : 'transparent',
        borderColor: isSelected ? 'rgba(0,122,255,0.30)' : 'transparent',
      }}
      onHoverStart={onSelect}
      onClick={onAdd}
      layout
      transition={{ duration: 0.1 }}
    >
      {iconBase64 ? (
        <img
          src={`data:image/png;base64,${iconBase64}`}
          alt={w.ownerName}
          style={styles.appAvatarIcon}
        />
      ) : (
        <div style={styles.appAvatar}>
          <span style={styles.appAvatarLetter}>{initial}</span>
        </div>
      )}

      <div style={styles.windowTextCol}>
        <div style={styles.appName}>
          {w.ownerName}
          {windowIndex > 0 && !subtitle.startsWith('Window') && (
            <span style={{ color: 'rgba(255,255,255,0.35)', fontWeight: 400 }}> #{windowIndex}</span>
          )}
        </div>
        {subtitle && (
          <div style={styles.windowName}>{subtitle}</div>
        )}
      </div>

      {isSelected && (
        <motion.div
          style={styles.addIndicator}
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.8 }}
        >
          <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
            <path d="M5 1.5v7M1.5 5h7" stroke="rgba(255,255,255,0.85)" strokeWidth="1.5" strokeLinecap="round"/>
          </svg>
        </motion.div>
      )}
    </motion.button>
  );
}

// ─── App row (installed but not running) ─────────────────────────
function AppRow({
  app,
  isSelected,
  onSelect,
  onAdd,
  iconBase64,
}: {
  app: InstalledApp;
  isSelected: boolean;
  onSelect: () => void;
  onAdd: () => void;
  iconBase64?: string;
}) {
  const initial = app.appName.charAt(0).toUpperCase();

  return (
    <motion.button
      style={{
        ...styles.windowItem,
        background: isSelected ? 'rgba(0,122,255,0.18)' : 'transparent',
        borderColor: isSelected ? 'rgba(0,122,255,0.30)' : 'transparent',
      }}
      onHoverStart={onSelect}
      onClick={onAdd}
      layout
      transition={{ duration: 0.1 }}
    >
      {iconBase64 ? (
        <img
          src={`data:image/png;base64,${iconBase64}`}
          alt={app.appName}
          style={styles.appAvatarIcon}
        />
      ) : (
        <div style={styles.appAvatar}>
          <span style={styles.appAvatarLetter}>{initial}</span>
        </div>
      )}

      <div style={styles.windowTextCol}>
        <div style={styles.appName}>{app.appName}</div>
        <div style={styles.windowName}>Not running</div>
      </div>

      {isSelected && (
        <motion.div
          style={styles.addIndicator}
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.8 }}
        >
          <svg width="10" height="10" viewBox="0 0 10 10" fill="none">
            <path d="M5 1.5v7M1.5 5h7" stroke="rgba(255,255,255,0.85)" strokeWidth="1.5" strokeLinecap="round"/>
          </svg>
        </motion.div>
      )}
    </motion.button>
  );
}

// ─── Keyboard hint ───────────────────────────────────────────────
function KbdHint({ keys, label }: { keys: string[]; label: string }) {
  return (
    <div style={styles.kbdGroup}>
      {keys.map((k) => (
        <kbd key={k} style={styles.kbd}>{k}</kbd>
      ))}
      <span style={styles.kbdLabel}>{label}</span>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  backdrop: {
    position: 'fixed',
    inset: 0,
    zIndex: 500,
  },
  panel: {
    position: 'absolute',
    bottom: 176,  // DOCK_BAR_HEIGHT(76) + TOOLTIP_OVERFLOW(100)
    left: 10,
    right: 10,
    maxWidth: 360,
    maxHeight: 420,
    margin: '0 auto',
    display: 'flex',
    flexDirection: 'column',
    overflow: 'hidden',
    background:
      'linear-gradient(180deg, rgba(255,255,255,0.10) 0%, rgba(255,255,255,0.04) 60%, rgba(255,255,255,0.02) 100%), rgba(16,16,22,0.82)',
    backdropFilter: 'blur(60px) saturate(220%) brightness(1.06)',
    WebkitBackdropFilter: 'blur(60px) saturate(220%) brightness(1.06)',
    border: '0.5px solid rgba(255,255,255,0.20)',
    borderRadius: 16,
    boxShadow:
      '0 4px 16px rgba(0,0,0,0.28), 0 20px 60px rgba(0,0,0,0.36), inset 0 0.5px 0 rgba(255,255,255,0.28)',
  },
  specularEdge: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 1,
    background:
      'linear-gradient(90deg, transparent 0%, rgba(255,255,255,0.30) 30%, rgba(255,255,255,0.30) 70%, transparent 100%)',
    borderRadius: '16px 16px 0 0',
    pointerEvents: 'none',
    zIndex: 2,
  },
  searchRow: {
    display: 'flex',
    alignItems: 'center',
    padding: '11px 14px',
    gap: 8,
    position: 'relative',
  },
  searchIcon: {
    flexShrink: 0,
  },
  searchInput: {
    flex: 1,
    background: 'transparent',
    border: 'none',
    color: 'rgba(255,255,255,0.90)',
    fontSize: 14,
    fontWeight: 400,
    outline: 'none',
    letterSpacing: '-0.01em',
    padding: 0,
    boxShadow: 'none',
  },
  clearBtn: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: 'none',
    border: 'none',
    cursor: 'pointer',
    padding: 2,
    flexShrink: 0,
    opacity: 0.8,
  },
  separator: {
    height: '0.5px',
    background:
      'linear-gradient(90deg, transparent, rgba(255,255,255,0.14) 20%, rgba(255,255,255,0.14) 80%, transparent)',
    flexShrink: 0,
  },
  sectionDivider: {
    padding: '8px 10px 4px',
    display: 'flex',
    flexDirection: 'column',
    gap: 6,
  },
  sectionLabel: {
    fontSize: 10,
    fontWeight: 600,
    color: 'rgba(255,255,255,0.35)',
    textTransform: 'uppercase',
    letterSpacing: '0.04em',
  },
  list: {
    overflowY: 'auto',
    flex: 1,
    padding: '6px 6px',
  },
  emptyState: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
    padding: '32px 20px',
  },
  emptyText: {
    fontSize: 12,
    color: 'rgba(255,255,255,0.35)',
    textAlign: 'center',
    letterSpacing: '-0.01em',
  },
  spinner: {
    width: 18,
    height: 18,
    border: '2px solid rgba(255,255,255,0.12)',
    borderTopColor: 'rgba(255,255,255,0.55)',
    borderRadius: '50%',
    animation: 'spin 0.7s linear infinite',
  },
  windowItem: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    width: '100%',
    textAlign: 'left',
    padding: '7px 10px',
    borderRadius: 10,
    cursor: 'pointer',
    border: '0.5px solid transparent',
    color: 'rgba(255,255,255,0.90)',
    transition: 'background 0.10s, border-color 0.10s',
    marginBottom: 1,
    position: 'relative',
  },
  appAvatarIcon: {
    width: 28,
    height: 28,
    borderRadius: 7,
    objectFit: 'cover' as const,
    flexShrink: 0,
  },
  appAvatar: {
    width: 28,
    height: 28,
    borderRadius: 7,
    background: 'rgba(255,255,255,0.10)',
    border: '0.5px solid rgba(255,255,255,0.14)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  appAvatarLetter: {
    fontSize: 12,
    fontWeight: 600,
    color: 'rgba(255,255,255,0.75)',
    letterSpacing: '-0.01em',
  },
  windowTextCol: {
    flex: 1,
    minWidth: 0,
  },
  appName: {
    fontSize: 13,
    fontWeight: 500,
    color: 'rgba(255,255,255,0.90)',
    letterSpacing: '-0.01em',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
  },
  windowName: {
    fontSize: 11,
    color: 'rgba(255,255,255,0.40)',
    marginTop: 1,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
    letterSpacing: '-0.01em',
  },
  addIndicator: {
    width: 20,
    height: 20,
    borderRadius: 6,
    background: 'rgba(0,122,255,0.75)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  footer: {
    display: 'flex',
    alignItems: 'center',
    gap: 14,
    padding: '7px 14px',
    borderTop: '0.5px solid rgba(255,255,255,0.08)',
    flexShrink: 0,
  },
  kbdGroup: {
    display: 'flex',
    alignItems: 'center',
    gap: 4,
  },
  kbd: {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: 'rgba(255,255,255,0.10)',
    border: '0.5px solid rgba(255,255,255,0.18)',
    borderRadius: 4,
    padding: '1px 5px',
    fontSize: 10,
    color: 'rgba(255,255,255,0.50)',
    fontFamily: 'inherit',
    minWidth: 18,
  },
  kbdLabel: {
    fontSize: 10,
    color: 'rgba(255,255,255,0.30)',
    letterSpacing: '-0.01em',
  },
};

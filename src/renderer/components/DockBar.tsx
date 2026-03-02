import { useEffect, useRef, useState, useCallback } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { useDockStore } from '../stores/dock-store';
import { useDockDrag } from '../hooks/use-dock-drag';
import { DockItem } from './DockItem';
import { AddWindowPanel } from './AddWindowPanel';

// ─── Layout constants ────────────────────────────────────────────
const ITEM_BASE_WIDTH = 48;   // px per item slot at rest (icon 40 + padding 4*2)
const ADD_BTN_WIDTH = 38;
const PADDING = 20;           // left + right padding total
const DIVIDER_WIDTH = 17;     // divider + margins
const DOCK_BAR_HEIGHT = 76;   // visual dock bar height
const TOOLTIP_OVERFLOW = 100; // extra space above dock for tooltips + magnified icons
const SIDE_OVERFLOW = 24;     // extra width each side for box-shadow + magnification
const WINDOW_HEIGHT = DOCK_BAR_HEIGHT + TOOLTIP_OVERFLOW; // total BrowserWindow height
const MIN_WIDTH = 200;
const PANEL_HEIGHT = 440;     // space reserved for AddWindowPanel above dock

function calcDockWidth(itemCount: number): number {
  const raw =
    itemCount * ITEM_BASE_WIDTH +
    (itemCount > 0 ? DIVIDER_WIDTH : 0) +
    ADD_BTN_WIDTH +
    PADDING;
  const screenMax = window.screen.width - 100;
  return Math.min(Math.max(raw, MIN_WIDTH), screenMax) + SIDE_OVERFLOW * 2;
}

export function DockBar() {
  const items = useDockStore((s) => s.items);
  const isAddPanelOpen = useDockStore((s) => s.isAddPanelOpen);
  const toggleAddPanel = useDockStore((s) => s.toggleAddPanel);
  const refreshFromWindows = useDockStore((s) => s.refreshFromWindows);
  const reorderItems = useDockStore((s) => s.reorderItems);
  const setBadge = useDockStore((s) => s.setBadge);
  const { isDragging: isWindowDragging, onDockMouseDown } = useDockDrag();

  const sorted = [...items].sort((a, b) => a.order - b.order);

  // Track previous panel open state for position restore
  const prevPanelOpenRef = useRef(false);

  // Periodically sync dock items with live window data
  useEffect(() => {
    const sync = async () => {
      try {
        const windows = await window.devdock.listWindows();
        refreshFromWindows(windows);
      } catch { /* ignore */ }
    };
    sync(); // initial sync
    const interval = setInterval(sync, 5000);
    return () => clearInterval(interval);
  }, [refreshFromWindows]);

  // Listen for new-window badge events from main process
  useEffect(() => {
    if (!window.devdock?.onNewWindows) return;
    const cleanup = window.devdock.onNewWindows((bundleId, count) => {
      setBadge(bundleId, count);
    });
    return cleanup;
  }, [setBadge]);

  // ── Magnification state ──────────────────────────────────────
  const [mouseX, setMouseX] = useState<number | null>(null);
  const itemCenterXMap = useRef<Map<string, number>>(new Map());
  const dockRef = useRef<HTMLDivElement>(null);

  // ── Drag-to-reorder state ────────────────────────────────────
  const [dragItemId, setDragItemId] = useState<string | null>(null);
  const [dragTranslateX, setDragTranslateX] = useState(0);
  const dragTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const dragStartXRef = useRef(0);

  const handleItemPointerDown = useCallback((e: React.PointerEvent, itemId: string) => {
    if (e.button !== 0) return;
    dragStartXRef.current = e.clientX;
    if (dragTimerRef.current) clearTimeout(dragTimerRef.current);
    dragTimerRef.current = setTimeout(() => {
      dragTimerRef.current = null;
      setDragItemId(itemId);
      setDragTranslateX(0);
    }, 180);
  }, []);

  // Global pointer events for drag (pre-drag cancel + active drag move/up)
  useEffect(() => {
    const move = (e: PointerEvent) => {
      // Pre-drag: cancel timer if moved too much (it's a click)
      if (dragTimerRef.current && Math.abs(e.clientX - dragStartXRef.current) > 8) {
        clearTimeout(dragTimerRef.current);
        dragTimerRef.current = null;
      }
      // Active drag: follow pointer + check reorder
      if (!dragItemId || !dockRef.current) return;
      const dx = e.clientX - dragStartXRef.current;
      setDragTranslateX(dx);

      const els = dockRef.current.querySelectorAll('[data-dock-item-id]');
      for (const el of els) {
        const id = (el as HTMLElement).dataset.dockItemId!;
        if (id === dragItemId) continue;
        const rect = el.getBoundingClientRect();
        const centerX = rect.left + rect.width / 2;
        if (Math.abs(e.clientX - centerX) < rect.width * 0.35) {
          reorderItems(dragItemId, id);
          // Reset origin so translate stays at 0 after swap
          dragStartXRef.current = e.clientX;
          setDragTranslateX(0);
          break;
        }
      }
    };

    const up = () => {
      if (dragTimerRef.current) {
        clearTimeout(dragTimerRef.current);
        dragTimerRef.current = null;
      }
      if (dragItemId) {
        setDragItemId(null);
        setDragTranslateX(0);
      }
    };

    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', up);
    return () => {
      window.removeEventListener('pointermove', move);
      window.removeEventListener('pointerup', up);
    };
  }, [dragItemId, reorderItems]);

  const handleDockMouseMove = useCallback((e: React.MouseEvent) => {
    setMouseX(e.clientX);
  }, []);

  const handleDockMouseLeave = useCallback(() => {
    setMouseX(null);
  }, []);

  // Measure item centers after layout changes
  useEffect(() => {
    if (!dockRef.current) return;
    const frame = requestAnimationFrame(() => {
      const itemEls = dockRef.current?.querySelectorAll('[data-dock-item-id]');
      itemEls?.forEach((el) => {
        const id = (el as HTMLElement).dataset.dockItemId!;
        const rect = el.getBoundingClientRect();
        itemCenterXMap.current.set(id, rect.left + rect.width / 2);
      });
    });
    return () => cancelAnimationFrame(frame);
  }, [sorted.length]);

  // Resize window whenever item count or panel state changes
  useEffect(() => {
    const dockWidth = calcDockWidth(sorted.length);
    if (isAddPanelOpen) {
      const oldW = window.innerWidth;
      const newW = Math.max(dockWidth, 380);
      const curY = window.screenY;
      // Compensate X to keep dock visually centered
      const dx = Math.round((newW - oldW) / 2);
      window.devdock?.resizeDock(newW, WINDOW_HEIGHT + PANEL_HEIGHT);
      window.devdock?.setPosition(window.screenX - dx, curY - PANEL_HEIGHT);
    } else {
      const oldW = window.innerWidth;
      const newW = dockWidth;
      window.devdock?.resizeDock(newW, WINDOW_HEIGHT);
      if (prevPanelOpenRef.current) {
        const dx = Math.round((oldW - newW) / 2);
        window.devdock?.setPosition(window.screenX + dx, window.screenY + PANEL_HEIGHT);
      }
    }
    prevPanelOpenRef.current = isAddPanelOpen;
  }, [sorted.length, isAddPanelOpen]);

  return (
    <>
      <div style={styles.outerWrapper}>
        <div style={styles.dockContainer}>
          <motion.div
            ref={dockRef}
            className="glass-panel"
            style={{
              ...styles.dock,
              cursor: isWindowDragging ? 'grabbing' : 'default',
            }}
            layout
            onMouseDown={onDockMouseDown}
            onMouseMove={handleDockMouseMove}
            onMouseLeave={handleDockMouseLeave}
          >
            {/* Subtle inner gradient overlay - Liquid Glass depth */}
            <div style={styles.glassOverlay} />

            <AnimatePresence initial={false}>
              {sorted.map((item) => {
                const isDragged = dragItemId === item.id;
                return (
                <motion.div
                  key={item.id}
                  data-dock-item-id={item.id}
                  initial={{ opacity: 0, scale: 0.6, y: 6 }}
                  animate={{
                    opacity: isDragged ? 0.8 : 1,
                    scale: isDragged ? 1.05 : 1,
                    x: isDragged ? dragTranslateX : 0,
                    y: 0,
                  }}
                  exit={{ opacity: 0, scale: 0.6, y: 6 }}
                  transition={isDragged
                    ? { x: { duration: 0 }, opacity: { duration: 0.12 }, scale: { duration: 0.12 } }
                    : { type: 'spring', stiffness: 380, damping: 26 }
                  }
                  layout={!isDragged}
                  style={{
                    flexShrink: 0,
                    zIndex: isDragged ? 10 : 1,
                    cursor: isDragged ? 'grabbing' : dragItemId ? 'default' : undefined,
                    filter: isDragged ? 'drop-shadow(0 4px 12px rgba(0,0,0,0.35))' : undefined,
                  }}
                  onPointerDown={(e) => handleItemPointerDown(e, item.id)}
                >
                  <DockItem
                    item={item}
                    mouseX={dragItemId ? null : mouseX}
                    itemCenterX={itemCenterXMap.current.get(item.id) ?? null}
                  />
                </motion.div>
                );
              })}
            </AnimatePresence>

            {/* Divider - only when items exist */}
            {sorted.length > 0 && <div style={styles.divider} />}

            {/* Add button */}
            <AddButton onClick={toggleAddPanel} isOpen={isAddPanelOpen} />
          </motion.div>
        </div>
      </div>

      <AnimatePresence>
        {isAddPanelOpen && (
          <AddWindowPanel onClose={toggleAddPanel} />
        )}
      </AnimatePresence>
    </>
  );
}

// ─── Add Button ──────────────────────────────────────────────────
function AddButton({ onClick, isOpen }: { onClick: () => void; isOpen: boolean }) {
  const [hovered, setHovered] = useState(false);
  const active = isOpen || hovered;

  return (
    <motion.button
      style={{
        ...styles.addBtn,
        background: isOpen
          ? 'rgba(0,122,255,0.70)'
          : hovered
          ? 'rgba(255,255,255,0.16)'
          : 'rgba(255,255,255,0.09)',
        borderColor: isOpen
          ? 'rgba(0,122,255,0.45)'
          : hovered
          ? 'rgba(255,255,255,0.28)'
          : 'rgba(255,255,255,0.16)',
        boxShadow: isOpen
          ? '0 0 0 3px rgba(0,122,255,0.18), inset 0 0.5px 0 rgba(255,255,255,0.22)'
          : hovered
          ? 'inset 0 0.5px 0 rgba(255,255,255,0.20)'
          : 'inset 0 0.5px 0 rgba(255,255,255,0.12)',
      }}
      onClick={onClick}
      onHoverStart={() => setHovered(true)}
      onHoverEnd={() => setHovered(false)}
      whileTap={{ scale: 0.88 }}
      transition={{ type: 'spring', stiffness: 360, damping: 24 }}
      title="Add window to dock"
    >
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
        <path
          d="M6 1.5v9M1.5 6h9"
          stroke={active ? 'rgba(255,255,255,0.95)' : 'rgba(255,255,255,0.55)'}
          strokeWidth="1.5"
          strokeLinecap="round"
        />
      </svg>
    </motion.button>
  );
}

const styles: Record<string, React.CSSProperties> = {
  outerWrapper: {
    width: '100%',
    height: '100%',
    display: 'flex',
    alignItems: 'flex-end',
    justifyContent: 'center',
    overflow: 'visible',
    padding: `0 ${SIDE_OVERFLOW}px`,
  },
  dockContainer: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'stretch',
  },
  dock: {
    display: 'flex',
    flexDirection: 'row',
    alignItems: 'flex-end',  // bottom-align so magnified icons grow upward
    gap: 2,
    padding: '8px 10px 6px',
    minHeight: DOCK_BAR_HEIGHT - 4,
    flexShrink: 0,
    position: 'relative',
    overflow: 'visible',     // allow magnified icons to overflow upward
  },
  // Liquid Glass depth overlay - subtle bottom fade
  glassOverlay: {
    position: 'absolute',
    inset: 0,
    borderRadius: 'inherit',
    background:
      'linear-gradient(180deg, rgba(255,255,255,0.04) 0%, rgba(0,0,0,0.04) 100%)',
    pointerEvents: 'none',
    zIndex: 0,
  },
  divider: {
    width: '0.5px',
    height: 28,
    background:
      'linear-gradient(180deg, transparent, rgba(255,255,255,0.22) 30%, rgba(255,255,255,0.22) 70%, transparent)',
    margin: '0 4px',
    flexShrink: 0,
    alignSelf: 'center',
    zIndex: 1,
  },
  addBtn: {
    width: 30,
    height: 30,
    borderRadius: 9,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    border: '0.5px solid rgba(255,255,255,0.16)',
    color: 'rgba(255,255,255,0.72)',
    cursor: 'pointer',
    flexShrink: 0,
    zIndex: 1,
    marginBottom: 14,  // center-align with icon (dotRow 9px + (40-30)/2 = 14px)
    transition: 'background 0.16s, border-color 0.16s, box-shadow 0.16s',
  },
};

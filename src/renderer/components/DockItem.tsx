import { useState, useRef, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { motion, useSpring, useTransform } from 'framer-motion';
import type { DockItem as DockItemType } from '@shared/types';
import { useDockStore } from '../stores/dock-store';
import { EditItemModal } from './EditItemModal';

interface DockItemProps {
  item: DockItemType;
  mouseX: number | null;
  itemCenterX: number | null;
}

const BASE_SIZE = 40;
const MAX_SIZE = 58;
const REACH = 96;
const MODAL_EXPAND = 440;

function getMagnifiedSize(mouseX: number | null, centerX: number | null): number {
  if (mouseX === null || centerX === null) return BASE_SIZE;
  const dist = Math.abs(mouseX - centerX);
  if (dist >= REACH) return BASE_SIZE;
  const t = Math.cos((dist / REACH) * (Math.PI / 2));
  return BASE_SIZE + (MAX_SIZE - BASE_SIZE) * t;
}

export function DockItem({ item, mouseX, itemCenterX }: DockItemProps) {
  const removeItem = useDockStore((s) => s.removeItem);
  const clearBadge = useDockStore((s) => s.clearBadge);
  const [showEdit, setShowEdit] = useState(false);
  const [isHovered, setIsHovered] = useState(false);
  const [tooltipPos, setTooltipPos] = useState({ left: 0, top: 0, maxW: 200 });
  const itemRef = useRef<HTMLDivElement>(null);

  const displayName = item.customName || item.ownerName;
  // Show window title in tooltip when available (helps distinguish same-app windows)
  const tooltipText = item.customName
    ? item.customName
    : item.windowName && item.windowName !== item.ownerName
      ? `${item.ownerName} — ${item.windowName}`
      : item.ownerName;

  const targetSize = getMagnifiedSize(mouseX, itemCenterX);
  const springSize = useSpring(targetSize, { stiffness: 340, damping: 26, mass: 0.8 });

  useEffect(() => {
    springSize.set(targetSize);
  }, [targetSize, springSize]);

  const borderRadius = useTransform(springSize, [BASE_SIZE, MAX_SIZE], [9, 14]);

  const handleClick = () => {
    if (item.badge) clearBadge(item.id);
    window.devdock.toggleWindow(item.pid, item.windowName || undefined);
  };

  // Native macOS context menu via IPC
  const handleContextMenu = async (e: React.MouseEvent) => {
    e.preventDefault();
    const action = await window.devdock.showContextMenu();
    if (action === 'edit') {
      openEditModal();
    } else if (action === 'remove') {
      removeItem(item.id);
    }
  };

  // Expand window for edit modal
  const openEditModal = () => {
    const curY = window.screenY;
    window.devdock?.resizeDock(
      Math.max(window.innerWidth, 360),
      window.innerHeight + MODAL_EXPAND,
    );
    window.devdock?.setPosition(window.screenX, curY - MODAL_EXPAND);
    setShowEdit(true);
  };

  const closeEditModal = () => {
    setShowEdit(false);
    // Collapse window back
    window.devdock?.setPosition(window.screenX, window.screenY + MODAL_EXPAND);
    window.devdock?.resizeDock(window.innerWidth, window.innerHeight - MODAL_EXPAND);
  };

  const handleMouseEnter = (e: React.MouseEvent) => {
    setIsHovered(true);
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const winW = window.innerWidth;
    const margin = 8;
    const maxW = Math.min(200, winW - margin * 2);
    const centerX = rect.left + rect.width / 2;
    // Compute left edge so tooltip stays within window
    let left = centerX - maxW / 2;
    left = Math.max(margin, Math.min(left, winW - maxW - margin));
    const top = Math.max(2, rect.top - 44);
    setTooltipPos({ left, top, maxW });
  };

  const handleMouseLeave = () => {
    setIsHovered(false);
  };

  return (
    <>
      <div
        ref={itemRef}
        style={{
          ...styles.itemOuter,
          opacity: item.isAlive ? 1 : 0.42,
        }}
        onClick={handleClick}
        onContextMenu={handleContextMenu}
        onMouseEnter={handleMouseEnter}
        onMouseLeave={handleMouseLeave}
      >
        <motion.div
          style={{
            ...styles.iconContainer,
            width: springSize,
            height: springSize,
          }}
          whileTap={{ scale: 0.90 }}
          transition={{ type: 'spring', stiffness: 400, damping: 22 }}
        >
          {isHovered && (
            <motion.div
              style={styles.hoverRing}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.12 }}
            />
          )}

          {item.iconBase64 ? (
            <motion.img
              src={`data:image/png;base64,${item.iconBase64}`}
              alt={displayName}
              style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
              animate={{ borderRadius: borderRadius.get() }}
            />
          ) : (
            <motion.div
              style={{
                ...styles.iconFallback,
                background: colorFromName(item.ownerName),
                borderRadius: borderRadius.get(),
                width: '100%',
                height: '100%',
              }}
            >
              {item.ownerName.charAt(0).toUpperCase()}
            </motion.div>
          )}

          {!item.isAlive && <div style={styles.deadIndicator} />}

          {item.badge && item.badge.count > 0 && (
            <div className="badge-pulse" style={styles.badge}>
              {item.badge.count > 99 ? '99+' : item.badge.count}
            </div>
          )}
        </motion.div>

        <div style={styles.dotRow}>
          {item.isAlive && <div style={styles.activeDot} />}
        </div>
      </div>

      {isHovered && createPortal(
        <div
          className="dock-tooltip"
          style={{
            left: tooltipPos.left,
            top: tooltipPos.top,
            position: 'fixed',
            maxWidth: tooltipPos.maxW,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
            animation: 'tooltipFade 0.14s cubic-bezier(0.16,1,0.3,1) both',
          }}
        >
          {tooltipText}
        </div>,
        document.body,
      )}

      {showEdit && (
        <EditItemModal item={item} onClose={closeEditModal} />
      )}
    </>
  );
}

function colorFromName(name: string): string {
  const colors = [
    'linear-gradient(135deg, rgba(0,80,180,0.75), rgba(0,40,120,0.75))',
    'linear-gradient(135deg, rgba(90,0,180,0.75), rgba(50,0,120,0.75))',
    'linear-gradient(135deg, rgba(180,0,90,0.75), rgba(120,0,50,0.75))',
    'linear-gradient(135deg, rgba(0,160,90,0.75), rgba(0,100,50,0.75))',
    'linear-gradient(135deg, rgba(180,120,0,0.75), rgba(120,70,0,0.75))',
    'linear-gradient(135deg, rgba(0,150,150,0.75), rgba(0,90,110,0.75))',
  ];
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash);
  }
  return colors[Math.abs(hash) % colors.length];
}

const styles: Record<string, React.CSSProperties> = {
  itemOuter: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: 0,
    cursor: 'pointer',
    userSelect: 'none',
    padding: '2px 2px 0',
    position: 'relative',
  },
  iconContainer: {
    position: 'relative',
    flexShrink: 0,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'visible',
  },
  hoverRing: {
    position: 'absolute',
    inset: -2,
    borderRadius: 16,
    background: 'rgba(255,255,255,0.08)',
    border: '0.5px solid rgba(255,255,255,0.18)',
    zIndex: 0,
    pointerEvents: 'none',
  },
  iconFallback: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: 16,
    fontWeight: 700,
    color: 'rgba(255,255,255,0.92)',
    border: '0.5px solid rgba(255,255,255,0.18)',
    boxShadow: '0 2px 8px rgba(0,0,0,0.30), inset 0 0.5px 0 rgba(255,255,255,0.20)',
    flexShrink: 0,
  },
  deadIndicator: {
    position: 'absolute',
    bottom: 1,
    right: 1,
    width: 9,
    height: 9,
    borderRadius: '50%',
    background: 'rgba(255,59,48,0.95)',
    border: '1.5px solid rgba(0,0,0,0.35)',
    boxShadow: '0 0 4px rgba(255,59,48,0.5)',
    zIndex: 2,
  },
  dotRow: {
    height: 6,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 3,
  },
  activeDot: {
    width: 4,
    height: 4,
    borderRadius: '50%',
    background: 'rgba(255,255,255,0.70)',
    boxShadow: '0 0 4px rgba(255,255,255,0.40)',
  },
  badge: {
    position: 'absolute',
    top: -4,
    right: -4,
    minWidth: 16,
    height: 16,
    borderRadius: 8,
    background: 'rgba(255,59,48,0.95)',
    border: '1.5px solid rgba(0,0,0,0.30)',
    boxShadow: '0 1px 4px rgba(255,59,48,0.50)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    fontSize: 9,
    fontWeight: 700,
    color: '#fff',
    padding: '0 3px',
    zIndex: 3,
    lineHeight: 1,
    letterSpacing: '0.02em',
  },
};

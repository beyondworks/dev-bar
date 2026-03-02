import { useState } from 'react';
import { motion } from 'framer-motion';
import type { DockItem } from '@shared/types';
import { useDockStore } from '../stores/dock-store';

interface EditItemModalProps {
  item: DockItem;
  onClose: () => void;
}

export function EditItemModal({ item, onClose }: EditItemModalProps) {
  const updateItem = useDockStore((s) => s.updateItem);
  const [customName, setCustomName] = useState(item.customName || '');
  const [notes, setNotes] = useState(item.notes || '');

  const handleSave = () => {
    updateItem(item.id, { customName, notes });
    onClose();
  };

  const handleBackdropClick = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) onClose();
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') onClose();
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) handleSave();
  };

  const initial = item.ownerName.charAt(0).toUpperCase();

  return (
    <div style={styles.backdrop} onClick={handleBackdropClick} onKeyDown={handleKeyDown}>
      <motion.div
        style={styles.modal}
        initial={{ opacity: 0, scale: 0.94, y: 8 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.94, y: 8 }}
        transition={{ type: 'spring', stiffness: 420, damping: 30 }}
      >
        {/* Specular top edge */}
        <div style={styles.specularEdge} />

        {/* Header - Apple Settings panel style */}
        <div style={styles.header}>
          <div style={styles.appIconWrap}>
            <div style={styles.appIcon}>
              <span style={styles.appIconLetter}>{initial}</span>
            </div>
          </div>
          <div style={styles.headerText}>
            <div style={styles.headerTitle}>Edit Item</div>
            <div style={styles.headerSubtitle}>{item.ownerName}</div>
          </div>
          <button style={styles.closeCircle} onClick={onClose} title="Close">
            <svg width="8" height="8" viewBox="0 0 8 8" fill="none">
              <path d="M1 1l6 6M7 1L1 7" stroke="rgba(0,0,0,0.55)" strokeWidth="1.4" strokeLinecap="round"/>
            </svg>
          </button>
        </div>

        <div style={styles.dividerFull} />

        {/* Form fields - Apple System Settings card style */}
        <div style={styles.formSection}>
          <div style={styles.fieldGroup}>
            <div style={styles.fieldRow}>
              <label style={styles.fieldLabel}>Name</label>
              <input
                style={styles.fieldInput}
                type="text"
                value={customName}
                onChange={(e) => setCustomName(e.target.value)}
                placeholder={item.ownerName}
                autoFocus
              />
            </div>
            <div style={styles.fieldSeparator} />
            <div style={styles.fieldRow} >
              <label style={styles.fieldLabel}>Notes</label>
              <textarea
                style={{ ...styles.fieldInput, ...styles.fieldTextarea }}
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Add a note…"
                rows={3}
              />
            </div>
          </div>
        </div>

        {/* Status row - PID / bundle info */}
        <div style={styles.metaRow}>
          <MetaBadge label="PID" value={String(item.pid)} />
          {item.bundleId && <MetaBadge label="Bundle" value={item.bundleId} />}
          <StatusBadge isAlive={item.isAlive} />
        </div>

        {/* Actions */}
        <div style={styles.actions}>
          <button
            style={styles.cancelBtn}
            onClick={onClose}
          >
            Cancel
          </button>
          <motion.button
            style={styles.saveBtn}
            onClick={handleSave}
            whileHover={{ background: 'rgba(0,122,255,0.92)' }}
            whileTap={{ scale: 0.96 }}
            transition={{ duration: 0.12 }}
          >
            Save
          </motion.button>
        </div>

        {/* Cmd+Enter hint */}
        <div style={styles.shortcutHint}>
          <kbd style={styles.kbd}>⌘</kbd>
          <kbd style={styles.kbd}>↵</kbd>
          <span style={styles.shortcutLabel}>to save</span>
        </div>
      </motion.div>
    </div>
  );
}

function MetaBadge({ label, value }: { label: string; value: string }) {
  return (
    <div style={styles.metaBadge}>
      <span style={styles.metaLabel}>{label}</span>
      <span style={styles.metaValue}>{value}</span>
    </div>
  );
}

function StatusBadge({ isAlive }: { isAlive: boolean }) {
  return (
    <div style={{ ...styles.metaBadge, marginLeft: 'auto' }}>
      <div style={{
        width: 6,
        height: 6,
        borderRadius: '50%',
        background: isAlive ? 'rgba(52,199,89,0.90)' : 'rgba(255,59,48,0.85)',
        boxShadow: isAlive ? '0 0 5px rgba(52,199,89,0.50)' : '0 0 5px rgba(255,59,48,0.50)',
        marginRight: 5,
        flexShrink: 0,
      }} />
      <span style={styles.metaValue}>{isAlive ? 'Running' : 'Not running'}</span>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  backdrop: {
    position: 'fixed',
    inset: 0,
    background: 'rgba(0,0,0,0.45)',
    backdropFilter: 'blur(8px)',
    WebkitBackdropFilter: 'blur(8px)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1000,
  },
  modal: {
    position: 'relative',
    width: 320,
    display: 'flex',
    flexDirection: 'column',
    overflow: 'hidden',
    background:
      'linear-gradient(180deg, rgba(255,255,255,0.11) 0%, rgba(255,255,255,0.04) 60%, rgba(255,255,255,0.02) 100%), rgba(18,18,26,0.90)',
    backdropFilter: 'blur(64px) saturate(220%) brightness(1.06)',
    WebkitBackdropFilter: 'blur(64px) saturate(220%) brightness(1.06)',
    border: '0.5px solid rgba(255,255,255,0.22)',
    borderRadius: 18,
    boxShadow:
      '0 4px 20px rgba(0,0,0,0.30), 0 24px 72px rgba(0,0,0,0.40), inset 0 0.5px 0 rgba(255,255,255,0.30)',
  },
  specularEdge: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 1,
    background:
      'linear-gradient(90deg, transparent 5%, rgba(255,255,255,0.32) 25%, rgba(255,255,255,0.32) 75%, transparent 95%)',
    borderRadius: '18px 18px 0 0',
    pointerEvents: 'none',
    zIndex: 2,
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    padding: '16px 16px 14px',
  },
  appIconWrap: {
    flexShrink: 0,
  },
  appIcon: {
    width: 36,
    height: 36,
    borderRadius: 9,
    background: 'linear-gradient(135deg, rgba(0,80,180,0.70), rgba(0,40,120,0.70))',
    border: '0.5px solid rgba(255,255,255,0.18)',
    boxShadow: '0 2px 8px rgba(0,0,0,0.28), inset 0 0.5px 0 rgba(255,255,255,0.20)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
  appIconLetter: {
    fontSize: 16,
    fontWeight: 700,
    color: 'rgba(255,255,255,0.92)',
    letterSpacing: '-0.02em',
  },
  headerText: {
    flex: 1,
    minWidth: 0,
  },
  headerTitle: {
    fontSize: 13,
    fontWeight: 600,
    color: 'rgba(255,255,255,0.92)',
    letterSpacing: '-0.02em',
  },
  headerSubtitle: {
    fontSize: 11,
    color: 'rgba(255,255,255,0.40)',
    letterSpacing: '-0.01em',
    marginTop: 1,
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
  },
  closeCircle: {
    width: 22,
    height: 22,
    borderRadius: '50%',
    background: 'rgba(255,255,255,0.14)',
    border: '0.5px solid rgba(255,255,255,0.18)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
    flexShrink: 0,
    padding: 0,
    transition: 'background 0.12s',
  },
  dividerFull: {
    height: '0.5px',
    background:
      'linear-gradient(90deg, transparent, rgba(255,255,255,0.12) 15%, rgba(255,255,255,0.12) 85%, transparent)',
    flexShrink: 0,
  },
  formSection: {
    padding: '12px 14px',
  },
  fieldGroup: {
    background: 'rgba(255,255,255,0.05)',
    border: '0.5px solid rgba(255,255,255,0.12)',
    borderRadius: 12,
    overflow: 'hidden',
  },
  fieldRow: {
    display: 'flex',
    alignItems: 'flex-start',
    gap: 10,
    padding: '9px 12px',
  },
  fieldSeparator: {
    height: '0.5px',
    background: 'rgba(255,255,255,0.08)',
    marginLeft: 12,
  },
  fieldLabel: {
    fontSize: 12,
    fontWeight: 500,
    color: 'rgba(255,255,255,0.50)',
    width: 48,
    flexShrink: 0,
    paddingTop: 1,
    letterSpacing: '-0.01em',
  },
  fieldInput: {
    flex: 1,
    background: 'transparent',
    border: 'none',
    color: 'rgba(255,255,255,0.90)',
    fontSize: 12,
    padding: 0,
    outline: 'none',
    letterSpacing: '-0.01em',
    boxShadow: 'none',
    borderRadius: 0,
  },
  fieldTextarea: {
    resize: 'none' as const,
    minHeight: 54,
    lineHeight: 1.55,
  },
  metaRow: {
    display: 'flex',
    alignItems: 'center',
    gap: 6,
    padding: '0 14px 10px',
    flexWrap: 'wrap' as const,
  },
  metaBadge: {
    display: 'flex',
    alignItems: 'center',
    gap: 4,
    background: 'rgba(255,255,255,0.07)',
    border: '0.5px solid rgba(255,255,255,0.12)',
    borderRadius: 6,
    padding: '3px 7px',
  },
  metaLabel: {
    fontSize: 10,
    color: 'rgba(255,255,255,0.35)',
    letterSpacing: '-0.01em',
    fontWeight: 500,
  },
  metaValue: {
    fontSize: 10,
    color: 'rgba(255,255,255,0.60)',
    letterSpacing: '-0.01em',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
    maxWidth: 120,
  },
  actions: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: 8,
    padding: '0 14px 10px',
  },
  cancelBtn: {
    padding: '7px 16px',
    borderRadius: 9,
    background: 'rgba(255,255,255,0.08)',
    border: '0.5px solid rgba(255,255,255,0.16)',
    color: 'rgba(255,255,255,0.65)',
    cursor: 'pointer',
    fontSize: 12,
    fontWeight: 500,
    letterSpacing: '-0.01em',
    transition: 'background 0.12s',
  },
  saveBtn: {
    padding: '7px 18px',
    borderRadius: 9,
    background: 'rgba(0,122,255,0.80)',
    border: '0.5px solid rgba(0,122,255,0.45)',
    color: 'rgba(255,255,255,0.96)',
    cursor: 'pointer',
    fontSize: 12,
    fontWeight: 600,
    letterSpacing: '-0.01em',
    boxShadow: '0 2px 8px rgba(0,122,255,0.30)',
    transition: 'background 0.12s',
  },
  shortcutHint: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
    padding: '0 14px 12px',
  },
  kbd: {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: 'rgba(255,255,255,0.09)',
    border: '0.5px solid rgba(255,255,255,0.16)',
    borderRadius: 4,
    padding: '1px 5px',
    fontSize: 10,
    color: 'rgba(255,255,255,0.40)',
    fontFamily: 'inherit',
  },
  shortcutLabel: {
    fontSize: 10,
    color: 'rgba(255,255,255,0.25)',
    letterSpacing: '-0.01em',
  },
};

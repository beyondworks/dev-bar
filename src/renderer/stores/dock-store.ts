import { create } from 'zustand';
import { v4 as uuidv4 } from 'uuid';
import type { DockItem, WindowInfo } from '@shared/types';

interface DockStore {
  items: DockItem[];
  position: { x: number; y: number };
  isAddPanelOpen: boolean;

  addItem: (item: Omit<DockItem, 'id' | 'order' | 'addedAt'>) => void;
  removeItem: (id: string) => void;
  updateItem: (id: string, updates: Partial<DockItem>) => void;
  reorderItems: (fromId: string, toId: string) => void;
  setPosition: (x: number, y: number) => void;
  setItems: (items: DockItem[]) => void;
  toggleAddPanel: () => void;
  refreshFromWindows: (windows: WindowInfo[]) => void;
  setBadge: (bundleId: string, count: number) => void;
  clearBadge: (id: string) => void;
}

// Detect broken iconBase64 (was saved as raw JSON string instead of base64)
function isIconBroken(icon: string): boolean {
  if (!icon) return true;
  if (icon.startsWith('{')) return true; // JSON string, not base64
  if (icon.length < 100) return true;   // too short to be a real icon
  return false;
}

export const useDockStore = create<DockStore>((set, get) => {
  // Load initial state from preload
  if (typeof window !== 'undefined' && window.devdock) {
    window.devdock.loadDock().then(async (state) => {
      if (state) {
        // Migrate old items that lack windowId + fix broken icons
        const items: DockItem[] = [];
        for (const item of state.items) {
          const migrated = {
            ...item,
            windowId: (item as any).windowId ?? 0,
          };
          // Re-fetch icon if broken
          if (isIconBroken(migrated.iconBase64) && migrated.bundleId) {
            try {
              migrated.iconBase64 = await window.devdock.getAppIcon(migrated.bundleId);
            } catch { /* ignore */ }
          }
          items.push(migrated);
        }
        set({ items, position: state.position });
        // Save repaired data
        window.devdock.saveDock({ items, position: state.position });
      }
    });
  }

  return {
    items: [],
    position: { x: 0, y: 0 },
    isAddPanelOpen: false,

    addItem: (item) => {
      const { items } = get();
      const newItem: DockItem = {
        ...item,
        id: uuidv4(),
        order: items.length,
        addedAt: Date.now(),
      };
      const nextItems = [...items, newItem];
      set({ items: nextItems });
      if (window.devdock) {
        const { position } = get();
        window.devdock.saveDock({ items: nextItems, position });
      }
    },

    removeItem: (id) => {
      const { items, position } = get();
      const nextItems = items.filter((i) => i.id !== id);
      set({ items: nextItems });
      if (window.devdock) {
        window.devdock.saveDock({ items: nextItems, position });
      }
    },

    updateItem: (id, updates) => {
      const { items, position } = get();
      const nextItems = items.map((i) =>
        i.id === id ? { ...i, ...updates } : i
      );
      set({ items: nextItems });
      if (window.devdock) {
        window.devdock.saveDock({ items: nextItems, position });
      }
    },

    setPosition: (x, y) => {
      const { items } = get();
      set({ position: { x, y } });
      if (window.devdock) {
        window.devdock.saveDock({ items, position: { x, y } });
      }
    },

    setItems: (items) => {
      set({ items });
    },

    reorderItems: (fromId, toId) => {
      const { items, position } = get();
      const sorted = [...items].sort((a, b) => a.order - b.order);
      const fromIdx = sorted.findIndex((i) => i.id === fromId);
      const toIdx = sorted.findIndex((i) => i.id === toId);
      if (fromIdx === -1 || toIdx === -1 || fromIdx === toIdx) return;
      const [moved] = sorted.splice(fromIdx, 1);
      sorted.splice(toIdx, 0, moved);
      const nextItems = sorted.map((item, i) => ({ ...item, order: i }));
      set({ items: nextItems });
      if (window.devdock) {
        window.devdock.saveDock({ items: nextItems, position });
      }
    },

    toggleAddPanel: () => {
      set((state) => ({ isAddPanelOpen: !state.isAddPanelOpen }));
    },

    // Sync dock items with live window data (windowName, isAlive, icon)
    refreshFromWindows: (windows: WindowInfo[]) => {
      const { items, position } = get();
      let changed = false;
      // Each live window can only match one dock item (1:1 consumed matching)
      const remaining = [...windows];

      const findAndConsume = (
        predicate: (w: WindowInfo) => boolean,
      ): WindowInfo | undefined => {
        const idx = remaining.findIndex(predicate);
        if (idx === -1) return undefined;
        return remaining.splice(idx, 1)[0];
      };

      const nextItems = items.map((item) => {
        // Priority: windowId → pid+bundleId → bundleId+windowName → bundleId
        const match =
          findAndConsume((w) => !!(item.windowId && w.windowId === item.windowId)) ??
          findAndConsume((w) => w.pid === item.pid && w.bundleId === item.bundleId) ??
          findAndConsume((w) => !!(w.bundleId && w.bundleId === item.bundleId &&
                                   w.windowName && w.windowName === item.windowName)) ??
          findAndConsume((w) => !!(w.bundleId && w.bundleId === item.bundleId));

        if (match) {
          const updates: Partial<DockItem> = {};
          if (!item.isAlive) { updates.isAlive = true; changed = true; }
          if (match.windowName && match.windowName !== item.windowName) {
            updates.windowName = match.windowName;
            changed = true;
          }
          if (match.ownerName && match.ownerName !== item.ownerName) {
            updates.ownerName = match.ownerName;
            changed = true;
          }
          if (match.pid !== item.pid) { updates.pid = match.pid; changed = true; }
          if (match.windowId !== item.windowId) { updates.windowId = match.windowId; changed = true; }
          if (Object.keys(updates).length > 0) {
            return { ...item, ...updates };
          }
        } else if (item.isAlive) {
          changed = true;
          return { ...item, isAlive: false };
        }
        return item;
      });
      if (changed) {
        set({ items: nextItems });
        if (window.devdock) {
          window.devdock.saveDock({ items: nextItems, position });
        }
      }
    },

    setBadge: (bundleId, count) => {
      const { items } = get();
      const nextItems = items.map((item) =>
        item.bundleId === bundleId
          ? { ...item, badge: { count, timestamp: Date.now() } }
          : item,
      );
      set({ items: nextItems });
    },

    clearBadge: (id) => {
      const { items, position } = get();
      const nextItems = items.map((item) =>
        item.id === id ? { ...item, badge: undefined } : item,
      );
      set({ items: nextItems });
      if (window.devdock) {
        window.devdock.saveDock({ items: nextItems, position });
      }
    },
  };
});

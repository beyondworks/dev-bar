export interface WindowInfo {
  windowId: number;
  ownerName: string;
  windowName: string;
  bundleId: string;
  pid: number;
  bounds: { x: number; y: number; width: number; height: number };
  isOnScreen: boolean;
}

export interface DockItem {
  id: string;
  windowId: number;
  pid: number;
  bundleId: string;
  ownerName: string;
  windowName: string;
  customName: string;
  notes: string;
  iconBase64: string;
  addedAt: number;
  order: number;
  isAlive: boolean;
  badge?: { count: number; timestamp: number };
}

export interface InstalledApp {
  bundleId: string;
  appName: string;
}

export interface DockState {
  items: DockItem[];
  position: { x: number; y: number };
}

export interface PermissionStatus {
  accessibility: boolean;
}

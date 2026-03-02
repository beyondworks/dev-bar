/// <reference types="vite/client" />

import type { DockItem, DockState, PermissionStatus, WindowInfo } from '@shared/types';

export interface DevDockAPI {
  // Permissions
  checkPermissions: () => Promise<PermissionStatus>;
  openPermissionSettings: () => Promise<void>;

  // Dock persistence
  loadDock: () => Promise<DockState>;
  saveDock: (state: DockState) => Promise<void>;

  // Window management
  listWindows: () => Promise<WindowInfo[]>;
  activateWindow: (pid: number, windowName?: string) => Promise<boolean>;
  toggleWindow: (pid: number, windowName?: string) => Promise<boolean>;

  // Installed apps
  listInstalledApps: () => Promise<{ bundleId: string; appName: string }[]>;

  // Position
  setPosition: (x: number, y: number) => Promise<void>;

  // Resize
  resizeDock: (width: number, height: number) => Promise<void>;

  // App icon
  getAppIcon: (bundleId: string) => Promise<string>;

  // Native context menu
  showContextMenu: () => Promise<string | null>;

  // Events
  onAddFrontmost: (callback: (win: WindowInfo) => void) => () => void;
  onNewWindows: (callback: (bundleId: string, count: number) => void) => () => void;
}

declare global {
  interface Window {
    devdock: DevDockAPI;
  }
}

import { contextBridge, ipcRenderer } from 'electron';
import { IPC } from '../shared/ipc-channels';
import type { WindowInfo, DockState, PermissionStatus } from '../shared/types';

const devdock = {
  listWindows: (): Promise<WindowInfo[]> =>
    ipcRenderer.invoke(IPC.WINDOWS_LIST),

  activateWindow: (pid: number, windowName?: string): Promise<boolean> =>
    ipcRenderer.invoke(IPC.WINDOWS_ACTIVATE, pid, windowName),

  saveDock: (state: DockState): Promise<boolean> =>
    ipcRenderer.invoke(IPC.DOCK_SAVE, state),

  loadDock: (): Promise<DockState | null> =>
    ipcRenderer.invoke(IPC.DOCK_LOAD),

  setPosition: (x: number, y: number): Promise<boolean> =>
    ipcRenderer.invoke(IPC.DOCK_SET_POSITION, x, y),

  resizeDock: (width: number, height: number): Promise<void> =>
    ipcRenderer.invoke(IPC.DOCK_RESIZE, width, height),

  checkPermissions: (): Promise<PermissionStatus> =>
    ipcRenderer.invoke(IPC.PERMISSIONS_CHECK),

  openPermissionSettings: (): Promise<boolean> =>
    ipcRenderer.invoke(IPC.PERMISSIONS_OPEN_SETTINGS),

  getAppIcon: (bundleId: string): Promise<string> =>
    ipcRenderer.invoke(IPC.APP_ICON, bundleId),

  showContextMenu: (): Promise<string | null> =>
    ipcRenderer.invoke(IPC.DOCK_CONTEXT_MENU),

  toggleWindow: (pid: number, windowName?: string): Promise<boolean> =>
    ipcRenderer.invoke(IPC.WINDOWS_TOGGLE, pid, windowName),

  listInstalledApps: (): Promise<{ bundleId: string; appName: string }[]> =>
    ipcRenderer.invoke(IPC.APPS_LIST_INSTALLED),

  onNewWindows: (callback: (bundleId: string, count: number) => void): (() => void) => {
    const listener = (_event: Electron.IpcRendererEvent, bundleId: string, count: number) => {
      callback(bundleId, count);
    };
    ipcRenderer.on(IPC.WINDOWS_NEW, listener);
    return () => {
      ipcRenderer.removeListener(IPC.WINDOWS_NEW, listener);
    };
  },

  onAddFrontmost: (callback: (window: WindowInfo) => void): (() => void) => {
    const listener = (_event: Electron.IpcRendererEvent, window: WindowInfo) => {
      callback(window);
    };
    ipcRenderer.on(IPC.DOCK_ADD_FRONTMOST, listener);
    // Return cleanup function
    return () => {
      ipcRenderer.removeListener(IPC.DOCK_ADD_FRONTMOST, listener);
    };
  },
};

contextBridge.exposeInMainWorld('devdock', devdock);

// Augment Window interface for TypeScript consumers in renderer
export type DevDockAPI = typeof devdock;

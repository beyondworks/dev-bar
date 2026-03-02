import { ipcMain, BrowserWindow, shell, Menu } from 'electron';
import { IPC } from '../shared/ipc-channels';
import { SwiftBridge } from './services/swift-bridge';
import { saveDockState, loadDockState } from './services/store';
import type { DockState } from '../shared/types';

export function registerIpcHandlers(win: BrowserWindow): void {
  // windows:list - returns all visible windows from Swift bridge
  ipcMain.handle(IPC.WINDOWS_LIST, async () => {
    return SwiftBridge.listWindows();
  });

  // windows:activate - bring window with given pid to front, optionally raise specific window by title
  ipcMain.handle(IPC.WINDOWS_ACTIVATE, async (_event, pid: number, windowName?: string) => {
    return SwiftBridge.activateWindow(pid, windowName);
  });

  // dock:save - persist dock state to electron-store
  ipcMain.handle(IPC.DOCK_SAVE, async (_event, state: DockState) => {
    await saveDockState(state);
    return true;
  });

  // dock:load - retrieve dock state from electron-store
  ipcMain.handle(IPC.DOCK_LOAD, async () => {
    return loadDockState();
  });

  // dock:set-position - move the BrowserWindow to given screen coordinates
  ipcMain.handle(IPC.DOCK_SET_POSITION, (_event, x: number, y: number) => {
    win.setPosition(Math.round(x), Math.round(y));
    return true;
  });

  // permissions:check - query accessibility permission status
  ipcMain.handle(IPC.PERMISSIONS_CHECK, async () => {
    return SwiftBridge.checkPermissions();
  });

  // permissions:open-settings - open System Settings > Accessibility
  ipcMain.handle(IPC.PERMISSIONS_OPEN_SETTINGS, async () => {
    await shell.openExternal(
      'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'
    );
    return true;
  });

  // app:icon - get base64 app icon for a given bundle ID
  ipcMain.handle(IPC.APP_ICON, async (_event, bundleId: string) => {
    return SwiftBridge.getAppIcon(bundleId);
  });

  // dock:context-menu - show native macOS context menu for dock items
  ipcMain.handle(IPC.DOCK_CONTEXT_MENU, async () => {
    return new Promise<string | null>((resolve) => {
      const menu = Menu.buildFromTemplate([
        { label: 'Edit Name & Notes', click: () => resolve('edit') },
        { type: 'separator' },
        { label: 'Remove from Dock', click: () => resolve('remove') },
      ]);
      menu.popup({
        window: win,
        callback: () => {
          // Called when menu is closed; resolve null if no item was clicked
          // Use setTimeout to let the click handler resolve first
          setTimeout(() => resolve(null), 50);
        },
      });
    });
  });

  // dock:resize - programmatically resize the BrowserWindow
  ipcMain.handle(IPC.DOCK_RESIZE, (_event, width: number, height: number) => {
    win.setSize(Math.round(width), Math.round(height));
    win.setContentSize(Math.round(width), Math.round(height));
    return true;
  });

  // windows:toggle - toggle window minimize/activate
  ipcMain.handle(IPC.WINDOWS_TOGGLE, async (_event, pid: number, windowName?: string) => {
    return SwiftBridge.toggleWindow(pid, windowName);
  });

  // apps:list-installed - list installed apps from /Applications
  ipcMain.handle(IPC.APPS_LIST_INSTALLED, async () => {
    return SwiftBridge.listInstalledApps();
  });
}

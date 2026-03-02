import { app, BrowserWindow, globalShortcut } from 'electron';
import * as path from 'path';
import { registerIpcHandlers } from './ipc-handlers';
import { SwiftBridge } from './services/swift-bridge';
import { startTracking, stopTracking } from './services/window-tracker';
import { IPC } from '../shared/ipc-channels';

const INITIAL_WIDTH = 348; // 300 + SIDE_OVERFLOW(24)*2
const INITIAL_HEIGHT = 176; // DOCK_BAR(76) + TOOLTIP_OVERFLOW(100)

let mainWindow: BrowserWindow | null = null;

function createWindow(): BrowserWindow {
  const win = new BrowserWindow({
    width: INITIAL_WIDTH,
    height: INITIAL_HEIGHT,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    hasShadow: false,
    resizable: false,
    type: 'panel',
    webPreferences: {
      preload: path.join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });

  // Always load built renderer files
  win.loadFile(path.join(__dirname, '../renderer/index.html'));

  return win;
}

function registerShortcuts(win: BrowserWindow): void {
  // Cmd+Shift+D: capture frontmost window and send to renderer
  globalShortcut.register('CommandOrControl+Shift+D', async () => {
    try {
      const frontmost = await SwiftBridge.getFrontmost();
      if (frontmost) {
        win.webContents.send(IPC.DOCK_ADD_FRONTMOST, frontmost);
      }
    } catch (err) {
      console.error('[Main] getFrontmost error:', err);
    }
  });
}

app.whenReady().then(() => {
  mainWindow = createWindow();

  registerIpcHandlers(mainWindow);
  registerShortcuts(mainWindow);

  startTracking(
    (closedWindowIds: number[]) => {
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send('windows:closed', closedWindowIds);
      }
    },
    (bundleId: string, count: number) => {
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send(IPC.WINDOWS_NEW, bundleId, count);
      }
    },
  );

  app.on('activate', () => {
    // On macOS re-create window if dock icon clicked and no windows open
    if (BrowserWindow.getAllWindows().length === 0) {
      mainWindow = createWindow();
      registerIpcHandlers(mainWindow);
      registerShortcuts(mainWindow);
    }
  });
});

app.on('window-all-closed', () => {
  stopTracking();
  globalShortcut.unregisterAll();
  // On macOS apps stay in menu bar; quit explicitly
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('will-quit', () => {
  stopTracking();
  globalShortcut.unregisterAll();
});

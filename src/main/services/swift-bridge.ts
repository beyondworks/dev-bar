import { execFile } from 'child_process';
import * as path from 'path';
import { app } from 'electron';
import type { WindowInfo, PermissionStatus } from '../../shared/types';

const TIMEOUT_MS = 5000;

function getBinaryPath(): string {
  if (app.isPackaged) {
    return path.join(process.resourcesPath, 'native', 'DevDockHelper');
  }
  return path.resolve(__dirname, '../../../native/.build/debug/DevDockHelper');
}

function runHelper(args: string[]): Promise<string> {
  return new Promise((resolve, reject) => {
    const binaryPath = getBinaryPath();
    const child = execFile(
      binaryPath,
      args,
      { timeout: TIMEOUT_MS, maxBuffer: 10 * 1024 * 1024 },
      (error, stdout, stderr) => {
        if (error) {
          reject(new Error(`DevDockHelper error: ${error.message}${stderr ? ` | stderr: ${stderr}` : ''}`));
          return;
        }
        resolve(stdout.trim());
      }
    );
    // Ensure process is killed if timeout fires
    child.on('error', reject);
  });
}

export const SwiftBridge = {
  async listWindows(): Promise<WindowInfo[]> {
    try {
      const output = await runHelper(['list']);
      return JSON.parse(output) as WindowInfo[];
    } catch (err) {
      console.error('[SwiftBridge] listWindows failed:', err);
      return [];
    }
  },

  async getFrontmost(): Promise<WindowInfo | null> {
    try {
      const output = await runHelper(['frontmost']);
      return JSON.parse(output) as WindowInfo;
    } catch (err) {
      console.error('[SwiftBridge] getFrontmost failed:', err);
      return null;
    }
  },

  async activateWindow(pid: number, windowName?: string): Promise<boolean> {
    try {
      const args = ['activate', String(pid)];
      if (windowName) args.push(windowName);
      await runHelper(args);
      return true;
    } catch (err) {
      console.error('[SwiftBridge] activateWindow failed:', err);
      return false;
    }
  },

  async checkPermissions(): Promise<PermissionStatus> {
    try {
      const output = await runHelper(['check-perms']);
      return JSON.parse(output) as PermissionStatus;
    } catch (err) {
      console.error('[SwiftBridge] checkPermissions failed:', err);
      return { accessibility: false };
    }
  },

  async getAppIcon(bundleId: string): Promise<string> {
    try {
      const output = await runHelper(['app-icon', bundleId]);
      const parsed = JSON.parse(output);
      return parsed.icon || '';
    } catch (err) {
      console.error('[SwiftBridge] getAppIcon failed:', err);
      return '';
    }
  },

  async toggleWindow(pid: number, windowName?: string): Promise<boolean> {
    try {
      const args = ['toggle', String(pid)];
      if (windowName) args.push(windowName);
      await runHelper(args);
      return true;
    } catch (err) {
      console.error('[SwiftBridge] toggleWindow failed:', err);
      return false;
    }
  },

  async listInstalledApps(): Promise<{ bundleId: string; appName: string }[]> {
    try {
      const output = await runHelper(['list-apps']);
      return JSON.parse(output) as { bundleId: string; appName: string }[];
    } catch (err) {
      console.error('[SwiftBridge] listInstalledApps failed:', err);
      return [];
    }
  },
};

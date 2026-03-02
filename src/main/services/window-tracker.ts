import { SwiftBridge } from './swift-bridge';
import type { WindowInfo } from '../../shared/types';

const POLL_INTERVAL_MS = 5000;

let intervalId: ReturnType<typeof setInterval> | null = null;
let previousWindowIds: Set<number> = new Set();
let previousBundleCounts: Map<string, number> = new Map();
// Only emit new-window events after initial sync completes
let initialized = false;

export function startTracking(
  onWindowClosed: (closedWindowIds: number[]) => void,
  onNewWindows?: (bundleId: string, count: number) => void,
): void {
  if (intervalId !== null) {
    console.warn('[WindowTracker] Already tracking, ignoring startTracking call');
    return;
  }

  // Initialize with current windows before starting poll
  SwiftBridge.listWindows().then((windows: WindowInfo[]) => {
    previousWindowIds = new Set(windows.map((w) => w.windowId));
    previousBundleCounts = countByBundle(windows);
    initialized = true;
  }).catch((err: unknown) => {
    console.error('[WindowTracker] Initial window list failed:', err);
    initialized = true; // still allow polling to start
  });

  intervalId = setInterval(async () => {
    // Skip polling until initial sync is done
    if (!initialized) return;

    try {
      const currentWindows = await SwiftBridge.listWindows();
      const currentIds = new Set(currentWindows.map((w) => w.windowId));

      const closedIds: number[] = [];
      for (const prevId of previousWindowIds) {
        if (!currentIds.has(prevId)) {
          closedIds.push(prevId);
        }
      }

      if (closedIds.length > 0) {
        onWindowClosed(closedIds);
      }

      // Detect new windows per bundleId (only genuinely new ones)
      if (onNewWindows) {
        const currentCounts = countByBundle(currentWindows);
        for (const [bundleId, count] of currentCounts) {
          const prev = previousBundleCounts.get(bundleId) ?? 0;
          if (count > prev) {
            onNewWindows(bundleId, count - prev);
          }
        }
        previousBundleCounts = currentCounts;
      }

      previousWindowIds = currentIds;
    } catch (err) {
      console.error('[WindowTracker] Poll failed:', err);
    }
  }, POLL_INTERVAL_MS);
}

export function stopTracking(): void {
  if (intervalId !== null) {
    clearInterval(intervalId);
    intervalId = null;
  }
  previousWindowIds = new Set();
  previousBundleCounts = new Map();
  initialized = false;
}

function countByBundle(windows: WindowInfo[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const w of windows) {
    if (w.bundleId) {
      counts.set(w.bundleId, (counts.get(w.bundleId) ?? 0) + 1);
    }
  }
  return counts;
}

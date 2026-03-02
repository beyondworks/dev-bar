import { useEffect, useState } from 'react';
import { DockBar } from './components/DockBar';
import { PermissionGuide } from './components/PermissionGuide';
import { useDockStore } from './stores/dock-store';

type AppState = 'loading' | 'no-permission' | 'ready';

export function App() {
  const [appState, setAppState] = useState<AppState>('loading');
  const addItem = useDockStore((s) => s.addItem);

  useEffect(() => {
    // Check permissions on mount
    window.devdock.checkPermissions().then((status) => {
      setAppState(status.accessibility ? 'ready' : 'no-permission');
    });
  }, []);

  useEffect(() => {
    if (appState !== 'ready') return;

    // Listen for frontmost window events (WindowInfo → DockItem fields)
    const unlisten = window.devdock.onAddFrontmost(async (win) => {
      let iconBase64 = '';
      if (win.bundleId) {
        iconBase64 = await window.devdock.getAppIcon(win.bundleId);
      }
      addItem({
        windowId: win.windowId,
        pid: win.pid,
        bundleId: win.bundleId,
        ownerName: win.ownerName,
        windowName: win.windowName,
        customName: '',
        notes: '',
        iconBase64,
        isAlive: true,
      });
    });

    return unlisten;
  }, [appState, addItem]);

  if (appState === 'loading') {
    return null;
  }

  if (appState === 'no-permission') {
    return (
      <PermissionGuide onGranted={() => setAppState('ready')} />
    );
  }

  return <DockBar />;
}

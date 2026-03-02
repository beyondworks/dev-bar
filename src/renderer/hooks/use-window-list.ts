import { useCallback, useEffect, useState } from 'react';
import type { WindowInfo } from '@shared/types';

interface UseWindowListReturn {
  windows: WindowInfo[];
  loading: boolean;
  error: string | null;
  refresh: () => void;
}

export function useWindowList(active: boolean): UseWindowListReturn {
  const [windows, setWindows] = useState<WindowInfo[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const list = await window.devdock.listWindows();
      setWindows(list);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to list windows');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (active) {
      refresh();
    }
  }, [active, refresh]);

  return { windows, loading, error, refresh };
}

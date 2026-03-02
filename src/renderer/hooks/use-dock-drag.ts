import { useCallback, useRef, useState } from 'react';

interface UseDockDragReturn {
  isDragging: boolean;
  onDockMouseDown: (e: React.MouseEvent) => void;
}

export function useDockDrag(): UseDockDragReturn {
  const [isDragging, setIsDragging] = useState(false);
  const startScreenRef = useRef<{ mouseX: number; mouseY: number; winX: number; winY: number } | null>(null);

  const onDockMouseDown = useCallback((e: React.MouseEvent) => {
    // Only drag when clicking on dock background — skip items, buttons, inputs
    const target = e.target as HTMLElement;
    if (target.closest('button, [data-dock-item-id], input, [data-no-drag]')) return;

    e.preventDefault();
    setIsDragging(true);

    startScreenRef.current = {
      mouseX: e.screenX,
      mouseY: e.screenY,
      winX: window.screenX,
      winY: window.screenY,
    };

    const handleMouseMove = (moveEvent: MouseEvent) => {
      if (!startScreenRef.current) return;
      const dx = moveEvent.screenX - startScreenRef.current.mouseX;
      const dy = moveEvent.screenY - startScreenRef.current.mouseY;
      window.devdock?.setPosition(
        startScreenRef.current.winX + dx,
        startScreenRef.current.winY + dy,
      );
    };

    const handleMouseUp = () => {
      setIsDragging(false);
      startScreenRef.current = null;
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
    };

    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseup', handleMouseUp);
  }, []);

  return { isDragging, onDockMouseDown };
}

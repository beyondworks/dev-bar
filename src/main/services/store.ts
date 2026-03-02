import * as fs from 'fs';
import * as path from 'path';
import { app } from 'electron';
import type { DockState } from '../../shared/types';

const DEFAULT_STATE: DockState = {
  items: [],
  position: { x: 100, y: 100 },
};

function getStorePath(): string {
  return path.join(app.getPath('userData'), 'devdock-state.json');
}

export async function saveDockState(state: DockState): Promise<void> {
  try {
    const filePath = getStorePath();
    fs.writeFileSync(filePath, JSON.stringify(state, null, 2), 'utf-8');
  } catch (err) {
    console.error('[Store] saveDockState failed:', err);
  }
}

export async function loadDockState(): Promise<DockState | null> {
  try {
    const filePath = getStorePath();
    if (!fs.existsSync(filePath)) {
      return DEFAULT_STATE;
    }
    const data = fs.readFileSync(filePath, 'utf-8');
    return JSON.parse(data) as DockState;
  } catch (err) {
    console.error('[Store] loadDockState failed:', err);
    return DEFAULT_STATE;
  }
}

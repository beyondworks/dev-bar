#!/bin/bash
# DevDock development launcher
# Uses macOS open to ensure proper GUI context

DIR="$(cd "$(dirname "$0")/.." && pwd)"
ELECTRON="$DIR/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron"

# Build first
cd "$DIR"
npx tsc -p tsconfig.node.json
npx vite build --config vite.config.ts

# Launch Electron with proper environment
ELECTRON_RUN_AS_NODE=0 "$ELECTRON" "$DIR" 2>&1 &
echo "DevDock launched (PID: $!)"

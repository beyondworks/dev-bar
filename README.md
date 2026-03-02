# DevDock

macOS 플로팅 독 바 - 코딩 작업 공간의 창을 빠르게 전환하고 관리합니다.

A macOS floating dock bar for managing parallel coding workspaces.

![macOS](https://img.shields.io/badge/macOS-13.0+-black?logo=apple)
![Electron](https://img.shields.io/badge/Electron-33-47848F?logo=electron)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## 목차 / Table of Contents

- [개요 / Overview](#개요--overview)
- [기능 / Features](#기능--features)
- [요구 사항 / Requirements](#요구-사항--requirements)
- [설치 / Installation](#설치--installation)
- [사용 방법 / Usage](#사용-방법--usage)
- [단축키 / Shortcuts](#단축키--shortcuts)
- [빌드 / Build](#빌드--build)
- [프로젝트 구조 / Project Structure](#프로젝트-구조--project-structure)
- [권한 / Permissions](#권한--permissions)
- [문제 해결 / Troubleshooting](#문제-해결--troubleshooting)
- [기술 스택 / Tech Stack](#기술-스택--tech-stack)

---

## 개요 / Overview

**한글**

DevDock은 macOS 화면 하단에 떠 있는 미니 독 바입니다. 여러 앱의 창을 독에 등록하고, 클릭 한 번으로 전환하거나 최소화할 수 있습니다. macOS Tahoe 스타일의 Liquid Glass 디자인을 적용했으며, 마우스 호버 시 아이콘이 확대되는 매그니피케이션 효과를 지원합니다.

**English**

DevDock is a floating mini dock bar that sits at the bottom of your macOS screen. Register windows from any app to the dock, then switch or minimize them with a single click. It features a macOS Tahoe-inspired Liquid Glass design with icon magnification on hover.

---

## 기능 / Features

### 창 관리 / Window Management
- **클릭 토글** - 독 아이콘 클릭 시 해당 창을 활성화하거나 최소화합니다
- **Click to toggle** - Click a dock icon to activate or minimize the window

### 앱 추가 / Add Apps
- **실행 중인 창** - 현재 열려 있는 모든 창을 검색하여 독에 추가
- **설치된 앱** - `/Applications`에 설치된 앱도 독에 추가 가능 (실행 중이 아니어도)
- **단축키 캡처** - `Cmd+Shift+D`로 현재 최전면 창을 즉시 추가
- **Running windows** - Search and add any currently open window
- **Installed apps** - Add apps from `/Applications` even if not running
- **Shortcut capture** - Press `Cmd+Shift+D` to instantly add the frontmost window

### 드래그 앤 드롭 / Drag and Drop
- 아이콘을 길게 누르고(180ms) 드래그하여 순서를 변경합니다
- Long-press (180ms) and drag icons to reorder them

### 매그니피케이션 / Magnification
- macOS 독과 동일한 호버 매그니피케이션 효과 (40px → 58px)
- Hover magnification effect identical to macOS Dock (40px → 58px)

### 뱃지 알림 / Badge Notifications
- 등록된 앱에서 새 창/다이얼로그가 열리면 빨간 뱃지로 알림
- Red badge notification when tracked apps open new windows/dialogs

### 편집 / Edit Items
- 우클릭 컨텍스트 메뉴로 이름 변경, 메모 추가, 삭제 가능
- Right-click context menu to rename, add notes, or remove items

### 상태 유지 / Persistence
- 독 아이템과 위치가 자동 저장되어 재시작 후에도 유지됩니다
- Dock items and position are auto-saved and persist across restarts

---

## 요구 사항 / Requirements

| 항목 / Item | 버전 / Version |
|---|---|
| macOS | 13.0 (Ventura) 이상 / or later |
| Node.js | 18.0 이상 / or later |
| npm | 9.0 이상 / or later |
| Xcode Command Line Tools | 최신 / Latest |
| Swift | 5.7 이상 / or later |

---

## 설치 / Installation

### 1. 저장소 클론 / Clone the repository

```bash
git clone https://github.com/beyondworks/devdocs.git
cd devdocs
```

### 2. 의존성 설치 / Install dependencies

```bash
npm install
```

### 3. Swift 네이티브 모듈 빌드 / Build the Swift native module

```bash
cd native
swift build -c debug
cd ..
```

> **참고**: 개발 시에는 `debug` 빌드, 배포 시에는 `release` 빌드를 사용합니다.
>
> **Note**: Use `debug` build for development, `release` for distribution.

### 4. TypeScript 및 렌더러 빌드 / Build TypeScript and renderer

```bash
npm run build
```

이 명령은 다음 두 단계를 순서대로 실행합니다:
This runs the following two steps in sequence:

1. `vite build` - React 렌더러 번들링 / Bundle the React renderer
2. `tsc -p tsconfig.node.json` - 메인 프로세스 컴파일 / Compile the main process

### 5. 실행 / Run

```bash
npm run dev
```

> **VSCode 터미널 사용 시 주의**: VSCode 환경에서는 `ELECTRON_RUN_AS_NODE=1`이 자동 설정되어 Electron이 정상 동작하지 않습니다. `npm run dev`가 이를 자동 처리하지만, 수동 실행 시에는 아래 명령을 사용하세요:
>
> **Note for VSCode terminal users**: VSCode sets `ELECTRON_RUN_AS_NODE=1` which prevents Electron from working properly. `npm run dev` handles this automatically, but for manual execution use:

```bash
env -u ELECTRON_RUN_AS_NODE node_modules/electron/dist/Electron.app/Contents/MacOS/Electron .
```

---

## 사용 방법 / Usage

### 앱 시작 / Starting the app

```bash
npm run dev
```

실행하면 화면 하단 중앙에 투명한 플로팅 독 바가 나타납니다.

When launched, a transparent floating dock bar appears at the bottom center of your screen.

### 창 추가 / Adding windows

**방법 1: + 버튼 / Method 1: + button**

1. 독 바 오른쪽의 **+** 버튼을 클릭합니다 / Click the **+** button on the right side of the dock
2. 상단에 실행 중인 창 목록이 표시됩니다 / Running windows are shown at the top
3. 하단에 설치된 앱 목록이 표시됩니다 / Installed apps are shown at the bottom
4. 검색창에 이름을 입력하여 필터링합니다 / Type in the search box to filter
5. 원하는 항목을 클릭하면 독에 추가됩니다 / Click an item to add it to the dock

**방법 2: 단축키 / Method 2: Keyboard shortcut**

1. 추가하려는 앱의 창을 최전면으로 가져옵니다 / Bring the target window to the front
2. `Cmd+Shift+D`를 누릅니다 / Press `Cmd+Shift+D`
3. 해당 창이 즉시 독에 추가됩니다 / The window is instantly added to the dock

### 창 전환 / Switching windows

- 독 아이콘을 **클릭**하면 해당 창이 활성화됩니다 / **Click** a dock icon to activate the window
- 이미 최전면인 창을 클릭하면 **최소화**됩니다 / Click again if it's already frontmost to **minimize** it

### 순서 변경 / Reordering

1. 아이콘을 **길게 누릅니다** (180ms) / **Long-press** an icon (180ms)
2. 아이콘이 약간 커지고 그림자가 생기면 드래그 모드입니다 / When it scales up with a shadow, drag mode is active
3. 좌우로 드래그하여 원하는 위치에 놓습니다 / Drag left or right to the desired position

### 편집 및 삭제 / Editing and removing

1. 아이콘을 **우클릭**합니다 / **Right-click** an icon
2. 컨텍스트 메뉴에서 선택합니다: / Choose from the context menu:
   - **편집 / Edit** - 이름 변경, 메모 추가 / Rename, add notes
   - **제거 / Remove** - 독에서 삭제 / Remove from dock

### 독 바 이동 / Moving the dock

독 바의 빈 영역을 드래그하여 화면 내 원하는 위치로 이동할 수 있습니다.

Drag the empty area of the dock bar to move it anywhere on screen.

---

## 단축키 / Shortcuts

| 단축키 / Shortcut | 동작 / Action |
|---|---|
| `Cmd+Shift+D` | 최전면 창을 독에 추가 / Add frontmost window to dock |

---

## 빌드 / Build

### 개발 빌드 / Development build

```bash
# Swift 네이티브 모듈 / Swift native module
cd native && swift build -c debug && cd ..

# TypeScript + React
npm run build

# 실행 / Run
npm run dev
```

### 릴리즈 빌드 / Release build

```bash
# Swift 릴리즈 빌드 / Swift release build
npm run build:native

# Electron 앱 패키징 (DMG) / Package Electron app (DMG)
npm run package
```

`release/` 디렉토리에 `.dmg` 파일이 생성됩니다.

The `.dmg` file will be created in the `release/` directory.

> **참고**: 릴리즈 빌드 시 `arm64` (Apple Silicon)과 `x64` (Intel) 두 아키텍처를 모두 지원합니다.
>
> **Note**: Release builds support both `arm64` (Apple Silicon) and `x64` (Intel) architectures.

---

## 프로젝트 구조 / Project Structure

```
devdock/
├── native/                          # Swift CLI (DevDockHelper)
│   ├── Package.swift
│   └── Sources/DevDockHelper/
│       ├── main.swift               # CLI 진입점 / CLI entry point
│       ├── WindowLister.swift        # CG/AX 창 목록 + 설치 앱 / Window listing + installed apps
│       ├── WindowActivator.swift     # 창 활성화/최소화/토글 / Activate/minimize/toggle
│       ├── AppIconExtractor.swift    # 앱 아이콘 추출 / App icon extraction
│       └── PermissionChecker.swift   # 접근성 권한 확인 / Accessibility permission check
├── src/
│   ├── main/                        # Electron 메인 프로세스 / Main process
│   │   ├── index.ts                 # 앱 진입점 / App entry point
│   │   ├── ipc-handlers.ts          # IPC 핸들러 / IPC handlers
│   │   └── services/
│   │       ├── swift-bridge.ts      # Swift CLI 브릿지 / Bridge to Swift CLI
│   │       ├── window-tracker.ts    # 창 변화 추적 / Window change tracking
│   │       └── store.ts             # JSON 파일 저장소 / JSON file storage
│   ├── preload/
│   │   └── index.ts                 # contextBridge API / Preload API
│   ├── renderer/                    # React UI
│   │   ├── App.tsx                  # 루트 컴포넌트 / Root component
│   │   ├── components/
│   │   │   ├── DockBar.tsx          # 독 바 컨테이너 / Dock bar container
│   │   │   ├── DockItem.tsx         # 개별 독 아이콘 / Individual dock icon
│   │   │   ├── AddWindowPanel.tsx   # 창/앱 추가 패널 / Add window/app panel
│   │   │   ├── EditItemModal.tsx    # 아이템 편집 모달 / Item edit modal
│   │   │   └── PermissionGuide.tsx  # 권한 안내 / Permission guide
│   │   ├── stores/
│   │   │   └── dock-store.ts        # Zustand 상태 관리 / Zustand state
│   │   ├── hooks/
│   │   │   ├── use-dock-drag.ts     # 독 바 드래그 이동 / Dock bar dragging
│   │   │   └── use-window-list.ts   # 창 목록 조회 / Window list fetching
│   │   └── styles/
│   │       └── globals.css          # Liquid Glass 디자인 시스템 / Design system
│   └── shared/
│       ├── types.ts                 # 공유 타입 / Shared types
│       └── ipc-channels.ts          # IPC 채널 상수 / IPC channel constants
├── resources/
│   └── entitlements.mac.plist       # macOS 권한 설정 / macOS entitlements
├── scripts/
│   └── dev.sh                       # 개발 실행 스크립트 / Dev launch script
├── package.json
├── tsconfig.json                    # 렌더러 TS 설정 / Renderer TS config
├── tsconfig.node.json               # 메인 프로세스 TS 설정 / Main process TS config
├── vite.config.ts                   # Vite 번들러 설정 / Vite bundler config
└── electron-builder.yml             # 앱 패키징 설정 / App packaging config
```

---

## 권한 / Permissions

DevDock은 **접근성(Accessibility)** 권한이 필요합니다. 이 권한은 다른 앱의 창 목록을 읽고 활성화/최소화하는 데 사용됩니다.

DevDock requires **Accessibility** permission. This is used to read window lists and activate/minimize windows of other apps.

### 권한 설정 방법 / How to grant permission

1. **시스템 설정** > **개인정보 보호 및 보안** > **접근성** 으로 이동합니다
2. DevDock (또는 Electron) 앱을 목록에 추가하고 활성화합니다

---

1. Go to **System Settings** > **Privacy & Security** > **Accessibility**
2. Add DevDock (or Electron) to the list and enable it

> **참고**: Screen Recording 권한은 필요하지 않습니다. DevDock은 앱 아이콘만 사용하며, 화면 캡처는 수행하지 않습니다.
>
> **Note**: Screen Recording permission is NOT required. DevDock only uses app icons and does not capture the screen.

---

## 문제 해결 / Troubleshooting

### 앱이 실행되지 않음 / App doesn't launch

**증상**: Electron이 실행되지만 빈 화면이 나타남

**Symptom**: Electron launches but shows a blank screen

**해결**: 빌드가 완료되었는지 확인합니다.

**Fix**: Ensure the build is complete.

```bash
npm run build
```

### VSCode 터미널에서 실행 실패 / Fails in VSCode terminal

**증상**: `Cannot find module 'electron'` 또는 Electron API 오류

**Symptom**: `Cannot find module 'electron'` or Electron API errors

**원인**: VSCode가 `ELECTRON_RUN_AS_NODE=1` 환경변수를 설정함

**Cause**: VSCode sets `ELECTRON_RUN_AS_NODE=1`

**해결 / Fix**:

```bash
env -u ELECTRON_RUN_AS_NODE node_modules/electron/dist/Electron.app/Contents/MacOS/Electron .
```

또는 `npm run dev`를 사용하세요 (자동 처리됨).

Or use `npm run dev` (handles this automatically).

### 창 목록이 비어 있음 / Window list is empty

**증상**: + 버튼을 눌러도 창이 표시되지 않음

**Symptom**: No windows shown when clicking +

**해결**: 접근성 권한을 확인합니다.

**Fix**: Check Accessibility permission.

1. 시스템 설정 > 개인정보 보호 및 보안 > 접근성
2. System Settings > Privacy & Security > Accessibility

### 아이콘이 표시되지 않음 / Icons not showing

**증상**: 알파벳 한 글자만 표시됨 (폴백 아이콘)

**Symptom**: Only shows a single letter (fallback icon)

**해결**: Swift 네이티브 모듈이 빌드되었는지 확인합니다.

**Fix**: Ensure the Swift native module is built.

```bash
cd native && swift build -c debug && cd ..
```

### 독 바가 잘림 / Dock bar is clipped

**증상**: 그림자나 확대된 아이콘이 잘려 보임

**Symptom**: Shadows or magnified icons appear cut off

**해결**: 이 문제는 v0.1.0에서 수정되었습니다. 최신 버전을 사용하세요.

**Fix**: This was fixed in v0.1.0. Use the latest version.

---

## 기술 스택 / Tech Stack

| 영역 / Layer | 기술 / Technology |
|---|---|
| 프레임워크 / Framework | Electron 33 |
| UI | React 19, framer-motion 12 |
| 상태 관리 / State | Zustand 5 |
| 빌드 / Bundler | Vite 6, TypeScript 5.7 |
| 네이티브 / Native | Swift 5.7 (AXUIElement, CGWindowList, NSWorkspace) |
| 디자인 / Design | Liquid Glass (macOS Tahoe-inspired) |
| 패키징 / Packaging | electron-builder 26 |

---

## 라이선스 / License

MIT

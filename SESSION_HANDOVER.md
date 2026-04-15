# Session Handover

## 날짜: 2026-04-15

## 프로젝트 개요

Dev-bar — 실행 중인 창을 "작업 그룹"으로 묶어 bar에 등록하고 가리기/복원, 재정렬, 상태 뱃지를 지원하는 macOS floating dock 앱. Swift 6 + SwiftPM 실행 파일, macOS 14+ 대상. 원격 레포: https://github.com/beyondworks/dev-bar (main).

## 완료

- **MVP 스캐폴드** (24a6e11): floating NSPanel, 메뉴바 상태 아이템, 앱/창 picker, AX 기반 focus/minimize, 기본 가리기/보이기 토글, SwiftPM 빌드/실행.
- **설정창** (7e68e72 일부): 상/하/좌/우 바 위치, 타겟 디스플레이 선택, 투명도 슬라이더, 테마 7종(Liquid Glass 포함), 톱니 아이콘 바 내부 배치, UserDefaults 영속화.
- **Dock 스타일 상호작용** (7e68e72): `.draggable` 제거 → 단일 `DragGesture(minimumDistance: 0)` + translation threshold(6px)로 탭/드래그 구분. 드래그 중 자석처럼 주변 슬롯 push-away, 스프링 애니메이션. 리사이즈 아티팩트 해결(NSPanel setFrame 동기화, SwiftUI 애니메이션 제거).
- **ActivityMonitor** (7e68e72): AX `kAXTitleChangedNotification` 구독, 작업중(.working) 초록 점 + 3초 idle auto-reset. frontmost 아닐 때 빨간 카운트 뱃지 증가. `UNUserNotificationCenter`는 bundle id 있을 때만 시도(SwiftPM raw binary 크래시 가드).
- **안정적 창 식별** (7e68e72): 슬롯 생성 시 `_AXUIElementGetWindow` 로 CGWindowID 캡처해 저장. 모든 WindowManager 호출이 CGWindowID 우선 매칭, 없으면 타이틀 폴백. Electron 앱 타이틀 변경에도 안정.
- **오프스크린 자동 복구** (7e68e72): `WindowManager.ensureOnScreen` 이 focus 시점에 창이 모든 디스플레이 밖이면 주 디스플레이 중앙으로 당겨옴.
- **빌드 파이프라인** (113dfb9): `tools/generate-icon.swift` (CG로 squircle + 3색 상태점 아이콘 생성), `scripts/build-app.sh` (swift build release → iconset → icns → .app Info.plist + ad-hoc codesign → UDZO DMG). 결과: `build/Dev-bar.app`, `build/Dev-bar.dmg`.
- **⌥+클릭 최소화 + 종료 시 stash 복원** (54b0249): `onEnded` 에서 `NSEvent.modifierFlags.contains(.option)` 판정, `HideMethod.minimize` 경로 추가. `applicationWillTerminate` 에서 모든 `stashedPosition` 있는 창을 원래 자리로 복귀.

## 미완료

- **Electron 앱 오프스크린 stash 클램핑** (최우선, 사용자 차단 중)
  - 증상: 일반 클릭(stash) 시 VS Code/Electron 창이 (-32000,-32000) 대신 (0,0) 근처로 끌려가 왼쪽 귀퉁이에 남음
  - 원인: Electron 이 창 좌표를 화면 안으로 강제 클램프
  - 사용자에게 4가지 선택지 제시 후 답 대기 중 (마지막 메시지):
    1. 기본 동작을 Dock 최소화로 교체 (★ 내가 추천)
    2. Electron 앱 자동 감지해서만 최소화
    3. stash 제거하고 최소화만 사용
    4. 설정창에 "기본 숨기기 방식" 토글 추가
  - 다음 단계: 사용자 답변 받으면 해당 경로 구현. 가장 일관된 해법은 1번.
- **정식 Developer ID 서명** — 지금은 ad-hoc 서명이라 다른 Mac 배포 시 Gatekeeper 경고. 우선순위 낮음.
- **슬롯 영속화** — 재시작 시 슬롯 복원 기능은 없음 (stash 상태만 `applicationWillTerminate` 가 safety-net으로 복구). UserDefaults/JSON 저장은 후속 작업.
- **앱별 특화 이벤트 감지** — ActivityMonitor는 제목 변경만 본다. Claude Code 훅, 권한 모달 생성(`kAXCreatedNotification`) 등은 미구현.

## 에러/학습

- **NSHostingView + NSAnimationContext.animator().setFrame + 빈번한 content 변경 = ghost-double render** — 패널 리사이즈 애니메이션 + SwiftUI content 재레이아웃이 충돌해 중간 프레임에 두 개 바가 겹쳐 보임. **해결**: 패널 프레임은 `animate: false` 동기 리사이즈, 애니메이션은 SwiftUI 측(`.animation(.spring, value: store.slots.map(\.id))`) 에만.
- **SwiftUI Button + `.gesture(composedGesture)`가 macOS에서 충돌** — Button 내부 제스처가 먼저 잡아서 외부 LongPressGesture 미동작. `.simultaneousGesture(DragGesture)` + `.onTapGesture` 도 첫 클릭이 "워밍업"으로 소비되는 버그 있음. **해결**: Button 제거 → `.contentShape(Rectangle())` + 단일 `DragGesture(minimumDistance: 0)`, onEnded 에서 translation threshold 로 탭/드래그 판정.
- **SwiftPM raw binary + `UNUserNotificationCenter.current()` = NSInternalInconsistencyException 크래시** — `mainBundle.bundleIdentifier` 가 nil이면 바로 throw. **해결**: 호출 전 `Bundle.main.bundleIdentifier != nil` 가드. 정식 `.app` 번들에선 자동으로 동작.
- **CGS 프라이빗 API (`CGSOrderWindow`)로 다른 앱 창 제어는 SIP 비활성 + scripting addition 필요** — yabai 의 hide 기능이 그걸 요구하는 이유. 일반 권한 앱에선 안 먹힘. `_AXUIElementGetWindow` (CGWindowID 조회) 는 일반 권한으로도 OK.
- **Electron(VS Code/Slack/Cursor/Discord/Figma/Notion 등) 은 창 좌표 클램핑** — AX `kAXPositionAttribute` 로 화면 밖 좌표 세팅해도 Electron 이 (0,0) 근처로 당겨옴. 오프스크린 stash 방식은 Electron 앱에선 반만 작동.
- **`NSScreen.main` 은 accessory 앱에선 부정확** — 키 윈도우 기준이라 Dev-bar 가 키 윈도우 없을 때 임의 반환. **해결**: `CGMainDisplayID()` + `displayID(of: screen)` 비교로 주 디스플레이 판정.
- **macOS 기본 `applicationShouldTerminateAfterLastWindowClosed` 는 true** — accessory 앱은 명시적으로 `false` 반환해야 설정창 닫을 때 종료 안 됨.
- **Top-level `main.swift` 은 MainActor 가 아님** — `@MainActor class` 의 init 을 top-level 에서 호출하면 Swift 6 에서 actor-isolated error. **해결**: `@main @MainActor struct DevBarApp { static func main() { ... } }` 로 전환.

## 다음 세션 시작 시

1. 사용자에게 "Electron 클램핑 해결 방향 1~4번 중 선택하셨나요?" 재질문. 답 없이 진행하지 말 것.
2. 답 받으면 체크포인트 찍고 구현:
   - 1번(Dock 최소화 기본): `BarView.unifiedClickDrag` 의 `HideMethod` 기본값을 `.stash` → `.minimize` 로, ⌥+클릭은 `.stash` 로 스왑. 설정창에서 기본 방식 선택도 검토.
   - 2번(Electron 자동 감지): `slot.bundleIdentifier` 가 Electron 앱 화이트리스트(또는 `Frameworks/Electron Framework.framework` 존재 여부)면 minimize, 아니면 stash.
3. 구현 후 `swift build` → `pkill -f '.build/debug/DevBar' && .build/debug/DevBar &` 로 재실행, 사용자 테스트 후 커밋/푸시.
4. 롤백 기준: 문제 발생 시 `git reset --hard 54b0249` (현재 HEAD) 또는 `113dfb9` (직전 안정 체크포인트).

## 레퍼런스

- Remote: https://github.com/beyondworks/dev-bar
- 현재 HEAD: `54b0249`
- 직전 안정 체크포인트: `113dfb9`
- 빌드: `./scripts/build-app.sh` → `build/Dev-bar.dmg`
- Bundle ID: `com.beyondworks.dev-bar`

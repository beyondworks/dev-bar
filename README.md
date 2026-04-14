# Dev-bar

작업 컨텍스트 단위로 창을 묶어 보여주는 macOS 미니 독.

## 설치 / 실행 (개발용)

```sh
swift build
swift run
```

빌드/실행은 macOS 14+, Swift 6.0+ (Xcode 16+) 필요.

## 권한

창 제어를 위해 **Accessibility 권한**이 필요합니다. 첫 실행 시 시스템 다이얼로그가 뜨며,
`System Settings → Privacy & Security → Accessibility`에서 dev-bar (또는 swift)을 허용해주세요.

## MVP 기능

- 화면 상단 floating panel(Dev-bar) 표시
- `+` 버튼으로 실행 중인 앱의 창을 슬롯으로 등록
- 슬롯 클릭: 포커스되어 있으면 최소화, 아니면 raise/un-minimize
- 슬롯 라벨 변경, 제거
- 메뉴바 아이콘에서 표시/숨김, 종료

## 다음 단계

- 워크스페이스 그룹(여러 슬롯을 묶어 저장/복원)
- Claude Code/Codex 훅 연동(권한 요청·완료 → 뱃지/알림)
- 글로벌 핫키
- 슬롯 상태 자동 갱신(앱 종료, 창 사라짐 감지)
- 영구 저장(UserDefaults / file)

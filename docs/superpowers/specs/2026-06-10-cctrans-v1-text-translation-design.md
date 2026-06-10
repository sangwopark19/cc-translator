# cctrans — v1 텍스트 번역 설계

- **작성일**: 2026-06-10
- **상태**: 승인됨 (브레인스토밍 완료, 구현 계획 대기)
- **범위**: v1 (텍스트 번역). OCR 기능은 이후 단계.

## 1. 배경 & 동기

기존에 쓰던 Mac 번역 유틸리티가 버그가 늘고 속도가 느려져 일상 사용이 어려워졌다. 같은 사용 흐름(어디서든 텍스트 선택 후 단축키로 즉시 번역)을 **빠르고 안정적으로** 직접 구현한다. GitHub 공개 오픈소스로 배포하며 커리어 포트폴리오로도 활용한다.

### 성공 기준

- **속도**: 번역 트리거부터 결과 표시까지 체감 지연이 최소 (기존 앱의 핵심 불만 해소).
- **안정성**: 백그라운드 상주 중 크래시/멈춤 없이 동작.
- **사용성**: 기존에 익숙하던 `cmd+c+c` 흐름을 그대로 재현.
- **코드 품질**: 모듈 경계가 명확하고 테스트 가능 (포트폴리오 평가 요소).

## 2. 결정 사항

| 항목 | 결정 | 비고 |
| --- | --- | --- |
| 기술 스택 | Swift + SwiftUI 네이티브 | 속도/안정성, Vision OCR·Apple 번역 접근(향후), 포트폴리오 차별화 |
| 앱 형태 | 메뉴바(상태바) 상주 앱, Dock 아이콘 없음 (`LSUIElement`) | |
| v1 범위 | 텍스트 번역만 (cmd+c+c → 팝업, Google 번역) | OCR은 Phase 2~3 |
| 번역 방향 | 스마트 양방향: 한국어→영어, 그 외→한국어 | 대상 언어는 설정에서 변경 가능 |
| 기본 엔진 | Google 무료 웹 엔드포인트 (키 불필요) | 비공식 — 위험은 §10 |
| 배포 | 오픈소스, 사용자 자체 빌드 | 공증/샌드박스/App Store 불필요 |
| 배포 타깃 | macOS 15+ | 향후 Apple Translation 프레임워크까지 조건분기 없이 사용 |
| 빌드 도구 | 표준 Xcode 프로젝트로 시작 | Tuist 등은 추후 선택 |

## 3. 아키텍처 & 모듈 경계

각 모듈은 단일 책임을 가지며 잘 정의된 인터페이스로 통신한다.

| 모듈 | 책임 | 의존 |
| --- | --- | --- |
| `HotkeyService` | 전역 이벤트 감시 → "cmd+c 두 번" 감지 → 트리거 발행 | Accessibility 권한 |
| `PasteboardReader` | 클립보드에서 복사된 텍스트 안전하게 읽기 | `NSPasteboard` |
| `LanguageRouter` | 감지된 원문 언어 → 대상 언어 결정 (스마트 양방향) | (순수 로직) |
| `TranslationProvider` (protocol) | 번역 엔진 추상화 | — |
| `GoogleWebProvider` | Google 무료 웹 엔드포인트 구현 | 네트워크 |
| `TranslationPopupController` | 떠 있는 패널 생성·위치·생명주기 관리 | `NSPanel` |
| `PopupView` (SwiftUI) | 팝업 UI | — |
| `SettingsStore` | `UserDefaults` 기반 환경설정 | `@AppStorage` |
| `PermissionsService` | 손쉬운 사용(Accessibility) 권한 확인/요청 | `AXIsProcessTrusted` |
| `AppDelegate` | 메뉴바 상태아이템 + 전체 배선 | 위 전부 |

**핵심 설계점**: `TranslationProvider` 프로토콜. v1엔 `GoogleWebProvider`만 구현하지만, Apple 시스템 번역·외부 API Provider를 드롭인으로 추가할 수 있도록 한다.

## 4. cmd+c+c 동작 흐름

1. `CGEventTap`(또는 전역 키 모니터)으로 `cmd+c` keyDown 감시. **손쉬운 사용(Accessibility) 권한** 필요.
2. `cmd+c` 입력 시 타임스탬프 기록. **기본 400ms** 내에 두 번째 `cmd+c`가 오면 트리거.
3. 트리거 시 `NSPasteboard`에서 텍스트 읽기 (`changeCount`로 갱신 확인).
4. `LanguageRouter`가 원문 언어 감지 → 대상 결정 → `GoogleWebProvider.translate()` 호출.
5. 결과를 커서 근처 팝업에 표시.

사용 흐름: *텍스트 선택(더블클릭 등) → cmd+c+c*. 첫 복사가 클립보드에 담고, 두 번째가 트리거가 된다.

## 5. 번역 엔진 레이어

```swift
protocol TranslationProvider {
    func translate(_ text: String, to target: Language) async throws -> TranslationResult
}

struct TranslationResult {
    let translatedText: String
    let detectedSource: Language
    let target: Language
    let provider: String
}
```

- **GoogleWebProvider**: `translate.googleapis.com/translate_a/single` 무료 엔드포인트. `sl=auto`로 원문 자동감지, 응답에 감지 언어 포함.
- **스마트 양방향**: `LanguageRouter`가 "감지 언어가 한국어면 → 영어, 아니면 → 한국어"를 결정. 한국어 대상 호출에서 감지 결과가 ko면 영어로 한 번 더 호출 (상세는 구현 시 확정).

## 6. 팝업 UI

- 커서 근처에 뜨는 작은 **떠 있는 패널** (`.nonactivatingPanel`, floating level — 다른 앱 위에 뜨되 포커스 안 뺏음).
- 표시: 감지 언어 뱃지 · **원문** · **번역문(강조)** · 복사 버튼 · 로딩 스피너.
  - (결정) 원문과 번역문을 함께 표시한다.
- 닫기: `Esc` / 바깥 클릭 / 결과 복사 후.

## 7. 설정 & 영속화

`UserDefaults`(`@AppStorage`)에 저장:

- 대상 언어 기본값 (한국어)
- 양방향 짝 (한↔영)
- 더블탭 임계시간 (기본 400ms)
- 로그인 시 자동 실행

설정창은 SwiftUI `Settings` 씬.

## 8. 에러 처리

| 상황 | 동작 |
| --- | --- |
| 클립보드 비었음 / 텍스트 없음 | 조용히 무시 |
| 네트워크 실패 / 엔드포인트 오류 | 팝업에 오류 상태 + 재시도 버튼 |
| 텍스트 과도하게 김 / 빈 문자열 | 가드 처리 |
| 손쉬운 사용 권한 없음 | 시스템 설정으로 안내 |

## 9. 테스트 전략 (TDD)

비즈니스 로직은 테스트 우선으로 작성한다.

- **순수 로직 (단위 테스트)**: `LanguageRouter`(감지 언어 → 대상), Google 응답 파서, 더블탭 타이밍 감지기(클럭 주입), `PasteboardReader`(목).
- **OS 통합부** (`CGEventTap`, `NSPanel`): 얇게 유지하고, 그 안에서 호출하는 로직을 테스트로 검증.
- 프레임워크: Swift Testing 또는 XCTest.

## 10. 위험 & 완화

- **비공식 Google 엔드포인트**: 문서화되지 않아 변경/레이트리밋 가능. 개인·오픈소스 저용량엔 충분. `TranslationProvider` 추상화로 공식 API/Apple 번역으로 교체 가능하게 함. → ADR로 기록 예정.
- **Accessibility 권한 의존**: 권한 미부여 시 핵심 기능 불가. 최초 실행 시 명확한 안내 제공.

## 11. 이후 단계 (v1 아님)

설계가 다음 단계를 자연스럽게 수용하도록 구성했다.

- **Phase 2 — OCR 텍스트추출**: Vision + 화면영역 캡처 → 텍스트 인식 → 같은 엔진 레이어로 번역 → 팝업 재사용. (화면 기록 권한 필요)
- **Phase 3 — OCR 오버레이**: Vision 바운딩박스 → 각 영역 번역 → 투명창에 원위치 덮어쓰기.
- **엔진 확장**: `AppleTranslationProvider` (Translation 프레임워크, macOS 15+), 외부 API Provider (API 키).

## 12. 미해결/기본값으로 확정된 항목

- 더블탭 임계시간: 기본 400ms (사용 중 조정 가능하도록 설정에 노출).
- 앱/저장소 이름: 현재 `cctrans` / `cc-translator` 사용 (변경 가능).

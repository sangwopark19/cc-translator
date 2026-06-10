# cctrans — 안정적 서명 + 엔진 확장 설계

- **작성일**: 2026-06-10
- **상태**: 승인됨 (브레인스토밍 완료, 구현 계획 대기)
- **선행**: v1(텍스트 번역, Google) 완료·병합·push됨.

## 1. 배경 & 동기

1. **안정적 서명**: 현재 Debug 빌드는 ad-hoc 서명(`CODE_SIGN_IDENTITY: "-"`)이라 재빌드마다 cdhash가 바뀌어 손쉬운 사용(Accessibility) 권한이 무효화된다 (전역 단축키가 매 빌드 후 동작 불가). 안정적 서명 ID로 이를 해소한다.
2. **엔진 확장**: v1은 Google 한 엔진뿐. `TranslationProvider` 추상화 위에 Apple 시스템 번역(오프라인) + DeepL + 다양한 LLM/HTTP API(확장형)를 추가해, 사용자가 원하는 엔진을 골라 쓰게 한다.

### 성공 기준
- 재빌드해도 손쉬운 사용 권한이 유지된다.
- 사용자가 여러 엔진 인스턴스를 추가·구성하고, 설정에서 활성 엔진을 선택할 수 있다.
- API 키가 안전하게(Keychain) 저장된다.
- 모든 엔진에서 스마트 양방향이 균일하게 동작한다.

## 2. 결정 사항

| 항목 | 결정 |
| --- | --- |
| 서명 | self-signed 코드사이닝 인증서(CLI 스크립트로 재현 가능 생성), `project.yml`에서 Manual 서명 |
| 추가 엔진 | Apple 시스템 번역, DeepL, OpenAI호환(범용), Anthropic (Google은 기존) |
| 엔진 선택 UX | 설정에서 단일 활성 엔진 선택 |
| 엔진 확장 구조 | 타입 프리셋 + 인스턴스 (사용자가 엔진을 여러 개 추가) |
| 키 저장 | Keychain |
| 원문 언어 감지 | 로컬 `NLLanguageRecognizer`로 통일 → 단일 호출 번역 (기존 2회 재번역 제거) |
| 단계화 | Phase 0 서명 → Phase 1 엔진 프레임워크+HTTP/LLM 엔진 → Phase 2 Apple |

## 3. 단계화

규모가 커서 한 스펙에 담되 단계별로 구현하고 각 단계가 자체 plan을 가진다.

- **Phase 0 — 안정적 서명** (독립, 먼저).
- **Phase 1 — 엔진 프레임워크 + HTTP/LLM 엔진** (DeepL, OpenAI호환, Anthropic).
- **Phase 2 — Apple 시스템 번역** (Translation 프레임워크, 복잡).

## 4. Phase 0 — 안정적 서명

- `scripts/make-signing-cert.sh`: 코드사이닝용 self-signed 인증서를 생성해 로그인 키체인에 등록하고 코드사이닝 신뢰를 설정한다(키 생성 + Code Signing EKU 포함 인증서 + import + trust). 멱등(이미 있으면 건너뜀).
- `project.yml`: `CODE_SIGN_STYLE: Manual`, `CODE_SIGN_IDENTITY: "cctrans-dev"`(인증서 이름)로 변경. `"-"`(ad-hoc) 대체.
- `README.md`: 1회 셋업 안내(스크립트 실행 또는 Keychain Access GUI로 동일 인증서 생성). 권한은 1회 부여 후 재빌드에도 유지됨을 명시.
- 효과: 지정 요구사항(designated requirement)이 인증서 기반으로 고정 → TCC가 cdhash가 아닌 서명 동일성으로 권한을 유지.

## 5. Phase 1 — 엔진 구성 모델

```
EngineKind: google | apple | deepl | openAICompatible | anthropic
EngineConfig (Codable, Sendable):
    id: String (UUID)
    kind: EngineKind
    displayName: String
    baseURL: String?      // API 엔진용 (프리셋 기본값 제공)
    model: String?        // LLM 엔진용
    systemPrompt: String? // LLM 엔진용 (기본 번역 프롬프트 제공)
    // apiKey는 여기 저장하지 않음 — Keychain에 id로 보관
EngineRegistry:
    engines: [EngineConfig]   // 내장(Google/Apple) + 사용자 추가
    activeEngineID: String
```
- 구성 목록·활성 ID는 `UserDefaults`에 JSON으로 영속화.
- `openAICompatible` 한 종류로 OpenAI·Groq·OpenRouter·로컬(Ollama) 등 다수 서비스 커버(프리셋 baseURL/model 제공, 사용자 변경 가능).
- `ProviderFactory(config:, apiKey:) -> TranslationProvider`: kind별로 provider 인스턴스를 만든다.

## 6. Phase 1 — 키 저장 (Keychain)

- `KeychainStore` (App 계층, Security 프레임워크): `setKey(_:for: engineID)`, `key(for: engineID)`, `deleteKey(for:)`.
- 설정 UI에서 입력/수정/삭제. 키는 코드/로그/UserDefaults에 노출하지 않는다.

## 7. Phase 1 — 로컬 감지 + 단일 호출 코디네이터

- 신규 `LanguageDetector` (CCTransCore, NaturalLanguage `NLLanguageRecognizer`): 텍스트 → `Language`(코드). 오프라인·즉시. 결정적 테스트를 위해 프로토콜로 추상화(주입형).
- **`TranslationProvider` 프로토콜 변경**: `translate(_ text:to target:) async throws -> String` — 이제 provider는 **번역문(String)만** 책임진다(감지·원문·조립은 코디네이터 몫). 기존 `GoogleWebProvider`도 이에 맞게 변경(Google 응답의 감지언어는 무시).
- `TranslationCoordinator` 변경: **로컬 감지 → `LanguageRouter`로 대상 결정 → `provider.translate(text, to:)` 1회 → `TranslationResult` 조립**(originalText=입력, translatedText=provider 반환, detectedSource=로컬 감지, target=결정값, provider=엔진명). 한국어 원문 2회 호출 재번역 로직 제거.
- `TranslationResult` 구조는 유지(필드 동일), 다만 조립 책임이 provider→coordinator로 이동.
- 기존 `TranslationCoordinatorTests`/`LanguageRouterTests`/`GoogleWebProviderTests`는 새 흐름에 맞게 갱신(TDD): 감지기·provider 모두 주입/stub으로 결정적 테스트.

## 8. Phase 1 — Provider 구현

`HTTPClient` 주입형으로 stub 단위테스트.
- `DeepLProvider`: REST(`/v2/translate`), 키로 free(`api-free.deepl.com`)/pro(`api.deepl.com`) 자동 선택, `target_lang` 전달.
- `OpenAICompatibleProvider`: `/chat/completions`, baseURL·model·key·systemPrompt 구성. 시스템 프롬프트 기본값: "Translate the user's text into {target}. Output only the translation, no explanations." 응답에서 메시지 본문 추출.
- `AnthropicProvider`: Messages API(`/v1/messages`, `anthropic-version` 헤더), model·key·prompt. 응답 텍스트 추출.
- 모든 provider는 `translate(_:to:) -> String`(번역문)만 반환한다(§7). 원문·감지·조립은 코디네이터가 담당.

## 9. Phase 1 — 설정 UI

- **엔진 관리** 섹션 신설: 구성된 엔진 목록(추가/편집/삭제), 활성 엔진 Picker, 종류별 입력 필드(displayName·baseURL·model·systemPrompt·apiKey[Keychain]).
- 기존 설정(기본 대상언어·상대언어·임계시간·자동실행) 유지.
- `AppDelegate.makeCoordinator()`가 활성 `EngineConfig` + Keychain 키로 `ProviderFactory`를 통해 provider 생성(하드코딩 Google 대체). 설정 변경 즉시 반영(기존 패턴 유지).

## 10. Phase 2 — Apple 시스템 번역

- Translation 프레임워크는 SwiftUI `.translationTask(_:action:)`에 묶여 있어 헤드리스 호출이 비공식. 숨김 `NSHostingView`에 `.translationTask`를 얹고 continuation으로 브리지해 `TranslationProvider.translate(_:to:)`를 구현한다(App 또는 별도 모듈; CCTransCore 순수성 유지).
- 최초 사용 언어쌍은 시스템이 언어팩 다운로드 UI를 띄울 수 있음(명시·안내). 오프라인 번역 이점.
- 복잡·위험이 커 독립 단계 + 별도 plan.

## 11. 테스트 전략

- Core 단위테스트(TDD 우선): `LanguageDetector`(주입형, 결정적), 갱신된 `TranslationCoordinator`(단일 호출, mock provider), `DeepLProvider`/`OpenAICompatibleProvider`/`AnthropicProvider`(stub HTTP로 요청 URL·헤더·바디 구성과 응답 파싱 검증).
- `KeychainStore`: 통합 테스트(테스트 키 네임스페이스) 또는 프로토콜 추상화 + 목.
- 서명·설정 UI·Apple provider: 빌드 + 수동 검증(서명 후 권한 유지로 검증 수월).

## 12. 위험 & 완화

- **self-signed 서명/TCC**: 인증서 신뢰·Code Signing EKU 설정이 정확해야 권한 유지. 스크립트로 재현 가능하게 하고 README에 검증 절차 기재.
- **Apple Translation 비공식 헤드리스 사용**: API가 UI 바인딩이라 깨질 수 있음 → 독립 단계로 격리, `TranslationProvider`로 분리해 실패 시 다른 엔진으로 대체 가능.
- **로컬 감지 정확도**: 짧은/모호한 텍스트는 오탐 가능. 스마트 양방향(한↔영 판별)엔 충분. 필요 시 임계 신뢰도 보정.
- **LLM 비용/지연**: 사용자가 키·모델을 직접 구성하므로 비용 인지. 활성 엔진 선택으로 통제.

## 13. 이후/미해결
- 추가 LLM 네이티브 제공자(예: Gemini)나 완전 범용 HTTP 템플릿은 YAGNI로 보류(OpenAI호환으로 대부분 커버).
- 팝업에서의 엔진 즉시 전환은 v1 범위 외(설정 단일 활성 엔진으로 시작).

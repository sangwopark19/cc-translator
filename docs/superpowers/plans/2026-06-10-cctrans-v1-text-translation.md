# cctrans v1 텍스트 번역 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mac 어디서든 텍스트 선택 후 `cmd+c+c`로 즉시 번역 팝업을 띄우는 메뉴바 앱의 v1(텍스트 번역, Google 엔진)을 만든다.

**Architecture:** 순수 로직(모델·언어 라우팅·Google provider·더블탭 감지)을 SPM 패키지 `CCTransCore`로 분리해 `swift test`로 TDD한다. 앱 셸(메뉴바·CGEventTap·NSPanel·SwiftUI)은 XcodeGen으로 생성하는 macOS 앱 타깃 `CCTrans`에 두고 `CCTransCore`에 의존한다. 번역 엔진은 `TranslationProvider` 프로토콜로 추상화해 이후 Apple/외부 API를 드롭인으로 추가한다.

**Tech Stack:** Swift 6 / SwiftUI / AppKit, Swift Testing, Swift Package Manager(`CCTransCore`), XcodeGen + xcodebuild(앱 타깃), macOS 15+ 타깃, 미서명(로컬 빌드).

---

## 사전 준비

실행 에이전트는 시작 전 다음 도구가 있는지 확인한다 (없으면 설치):

```bash
swift --version          # Xcode 16+ 툴체인 (Swift 6, Swift Testing 포함)
xcodebuild -version
which xcodegen || brew install xcodegen
```

## 파일 구조 (완성 시)

```
/  (repo root: cc-translator)
├── .gitignore
├── project.yml                              # XcodeGen 매니페스트 (앱 타깃)
├── README.md
├── docs/adr/0001-unofficial-google-endpoint.md
├── CCTransCore/                             # SPM 패키지: 순수 로직 (swift test)
│   ├── Package.swift
│   ├── Sources/CCTransCore/
│   │   ├── Language.swift
│   │   ├── TranslationResult.swift
│   │   ├── TranslationError.swift
│   │   ├── TranslationProvider.swift
│   │   ├── LanguageRouter.swift
│   │   ├── GoogleResponseParser.swift
│   │   ├── HTTPClient.swift
│   │   ├── GoogleWebProvider.swift
│   │   ├── TranslationCoordinator.swift
│   │   └── DoubleTapDetector.swift
│   └── Tests/CCTransCoreTests/
│       ├── LanguageRouterTests.swift
│       ├── GoogleResponseParserTests.swift
│       ├── GoogleWebProviderTests.swift
│       ├── TranslationCoordinatorTests.swift
│       └── DoubleTapDetectorTests.swift
└── App/                                     # 앱 타깃 소스 (AppKit/SwiftUI 셸)
    ├── CCTransApp.swift
    ├── AppDelegate.swift
    ├── PermissionsService.swift
    ├── PasteboardReader.swift
    ├── HotkeyService.swift
    ├── PopupViewModel.swift
    ├── PopupView.swift
    ├── TranslationPopupController.swift
    ├── SettingsStore.swift
    └── SettingsView.swift
```

`CCTransCore` = 빠르게 단위 테스트되는 순수 로직. `App` = 얇은 OS 글루 + UI(수동 검증).

---

## Task 1: 저장소 스캐폴딩 (.gitignore + CCTransCore 패키지)

**Files:**
- Create: `.gitignore`
- Create: `CCTransCore/Package.swift`
- Create: `CCTransCore/Sources/CCTransCore/Placeholder.swift`
- Create: `CCTransCore/Tests/CCTransCoreTests/SmokeTests.swift`

- [ ] **Step 1: `.gitignore` 작성**

```gitignore
.DS_Store
*.xcodeproj
*.xcworkspace
build/
.build/
DerivedData/
*.xcuserstate
```

- [ ] **Step 2: `CCTransCore/Package.swift` 작성**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CCTransCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CCTransCore", targets: ["CCTransCore"]),
    ],
    targets: [
        .target(name: "CCTransCore"),
        .testTarget(name: "CCTransCoreTests", dependencies: ["CCTransCore"]),
    ]
)
```

- [ ] **Step 3: 임시 소스/스모크 테스트 작성**

`CCTransCore/Sources/CCTransCore/Placeholder.swift`:

```swift
enum CCTransCore {
    static let version = "0.1.0"
}
```

`CCTransCore/Tests/CCTransCoreTests/SmokeTests.swift`:

```swift
import Testing
@testable import CCTransCore

@Suite struct SmokeTests {
    @Test func versionIsSet() {
        #expect(CCTransCore.version == "0.1.0")
    }
}
```

- [ ] **Step 4: 테스트 실행 (통과 확인)**

Run: `swift test --package-path CCTransCore`
Expected: 빌드 성공, 1개 테스트 PASS.

- [ ] **Step 5: 커밋**

```bash
git add .gitignore CCTransCore
git commit -m "chore: scaffold CCTransCore swift package"
```

---

## Task 2: 코어 모델 (Language, TranslationResult, TranslationError, TranslationProvider)

**Files:**
- Create: `CCTransCore/Sources/CCTransCore/Language.swift`
- Create: `CCTransCore/Sources/CCTransCore/TranslationResult.swift`
- Create: `CCTransCore/Sources/CCTransCore/TranslationError.swift`
- Create: `CCTransCore/Sources/CCTransCore/TranslationProvider.swift`
- Delete: `CCTransCore/Sources/CCTransCore/Placeholder.swift`
- Modify: `CCTransCore/Tests/CCTransCoreTests/SmokeTests.swift`

- [ ] **Step 1: 실패하는 테스트로 교체**

`CCTransCore/Tests/CCTransCoreTests/SmokeTests.swift` 전체를 교체:

```swift
import Testing
@testable import CCTransCore

@Suite struct ModelTests {
    @Test func languageConstants() {
        #expect(Language.korean.code == "ko")
        #expect(Language.english.code == "en")
        #expect(Language.korean != Language.english)
    }

    @Test func translationResultStoresFields() {
        let r = TranslationResult(
            originalText: "Hello",
            translatedText: "안녕하세요",
            detectedSource: .english,
            target: .korean,
            provider: "google"
        )
        #expect(r.originalText == "Hello")
        #expect(r.translatedText == "안녕하세요")
        #expect(r.detectedSource == .english)
        #expect(r.target == .korean)
        #expect(r.provider == "google")
    }
}
```

- [ ] **Step 2: 테스트 실행 (실패 확인)**

Run: `swift test --package-path CCTransCore`
Expected: 컴파일 실패 — `Language`, `TranslationResult` 미정의.

- [ ] **Step 3: 모델 구현**

`Language.swift`:

```swift
public struct Language: Equatable, Hashable, Sendable {
    public let code: String
    public init(code: String) { self.code = code }

    public static let korean = Language(code: "ko")
    public static let english = Language(code: "en")
    public static let auto = Language(code: "auto")
}
```

`TranslationResult.swift`:

```swift
public struct TranslationResult: Equatable, Sendable {
    public let originalText: String
    public let translatedText: String
    public let detectedSource: Language
    public let target: Language
    public let provider: String

    public init(
        originalText: String,
        translatedText: String,
        detectedSource: Language,
        target: Language,
        provider: String
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.detectedSource = detectedSource
        self.target = target
        self.provider = provider
    }
}
```

`TranslationError.swift`:

```swift
public enum TranslationError: Error, Equatable {
    case malformedResponse
    case network
    case invalidRequest
    case emptyInput
}
```

`TranslationProvider.swift`:

```swift
public protocol TranslationProvider: Sendable {
    func translate(_ text: String, to target: Language) async throws -> TranslationResult
}
```

그리고 `Placeholder.swift` 삭제:

```bash
rm CCTransCore/Sources/CCTransCore/Placeholder.swift
```

- [ ] **Step 4: 테스트 실행 (통과 확인)**

Run: `swift test --package-path CCTransCore`
Expected: 2개 테스트 PASS.

- [ ] **Step 5: 커밋**

```bash
git add CCTransCore
git commit -m "feat: add core translation models and provider protocol"
```

---

## Task 3: LanguageRouter (스마트 양방향)

**Files:**
- Create: `CCTransCore/Sources/CCTransCore/LanguageRouter.swift`
- Create: `CCTransCore/Tests/CCTransCoreTests/LanguageRouterTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

`LanguageRouterTests.swift`:

```swift
import Testing
@testable import CCTransCore

@Suite struct LanguageRouterTests {
    let router = LanguageRouter(primary: .korean, secondary: .english)

    @Test func koreanSourceRoutesToSecondary() {
        #expect(router.target(forDetected: .korean) == .english)
    }

    @Test func englishSourceRoutesToPrimary() {
        #expect(router.target(forDetected: .english) == .korean)
    }

    @Test func otherSourceRoutesToPrimary() {
        #expect(router.target(forDetected: Language(code: "ja")) == .korean)
    }
}
```

- [ ] **Step 2: 테스트 실행 (실패 확인)**

Run: `swift test --package-path CCTransCore --filter LanguageRouterTests`
Expected: 컴파일 실패 — `LanguageRouter` 미정의.

- [ ] **Step 3: 구현**

`LanguageRouter.swift`:

```swift
public struct LanguageRouter: Sendable {
    public let primary: Language
    public let secondary: Language

    public init(primary: Language, secondary: Language) {
        self.primary = primary
        self.secondary = secondary
    }

    /// 감지된 원문 언어가 primary면 secondary로, 아니면 primary로 번역한다.
    public func target(forDetected source: Language) -> Language {
        source == primary ? secondary : primary
    }
}
```

- [ ] **Step 4: 테스트 실행 (통과 확인)**

Run: `swift test --package-path CCTransCore --filter LanguageRouterTests`
Expected: 3개 테스트 PASS.

- [ ] **Step 5: 커밋**

```bash
git add CCTransCore
git commit -m "feat: add LanguageRouter for smart bidirectional targeting"
```

---

## Task 4: GoogleResponseParser

**Files:**
- Create: `CCTransCore/Sources/CCTransCore/GoogleResponseParser.swift`
- Create: `CCTransCore/Tests/CCTransCoreTests/GoogleResponseParserTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

`GoogleResponseParserTests.swift`:

```swift
import Testing
import Foundation
@testable import CCTransCore

@Suite struct GoogleResponseParserTests {
    @Test func parsesSingleSentence() throws {
        let json = #"[[["안녕하세요","Hello",null,null,10]],null,"en"]"#
        let parsed = try GoogleResponseParser.parse(Data(json.utf8))
        #expect(parsed.translatedText == "안녕하세요")
        #expect(parsed.detectedSource == .english)
    }

    @Test func joinsMultipleSentences() throws {
        let json = #"[[["가","A",null,null],["나","B",null,null]],null,"en"]"#
        let parsed = try GoogleResponseParser.parse(Data(json.utf8))
        #expect(parsed.translatedText == "가나")
    }

    @Test func throwsOnMalformed() {
        #expect(throws: TranslationError.malformedResponse) {
            try GoogleResponseParser.parse(Data("not json".utf8))
        }
    }
}
```

- [ ] **Step 2: 테스트 실행 (실패 확인)**

Run: `swift test --package-path CCTransCore --filter GoogleResponseParserTests`
Expected: 컴파일 실패 — `GoogleResponseParser` 미정의.

- [ ] **Step 3: 구현**

`GoogleResponseParser.swift`:

```swift
import Foundation

public struct ParsedTranslation: Equatable, Sendable {
    public let translatedText: String
    public let detectedSource: Language
}

public enum GoogleResponseParser {
    /// translate_a/single 응답: `[[["번역","원문",...], ...], null, "감지언어", ...]`
    public static func parse(_ data: Data) throws -> ParsedTranslation {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let sentences = root.first as? [Any] else {
            throw TranslationError.malformedResponse
        }
        let translated = sentences
            .compactMap { ($0 as? [Any])?.first as? String }
            .joined()
        guard !translated.isEmpty else { throw TranslationError.malformedResponse }
        let sourceCode = (root.count > 2 ? root[2] as? String : nil) ?? "auto"
        return ParsedTranslation(
            translatedText: translated,
            detectedSource: Language(code: sourceCode)
        )
    }
}
```

- [ ] **Step 4: 테스트 실행 (통과 확인)**

Run: `swift test --package-path CCTransCore --filter GoogleResponseParserTests`
Expected: 3개 테스트 PASS.

- [ ] **Step 5: 커밋**

```bash
git add CCTransCore
git commit -m "feat: add GoogleResponseParser"
```

---

## Task 5: HTTPClient + GoogleWebProvider

**Files:**
- Create: `CCTransCore/Sources/CCTransCore/HTTPClient.swift`
- Create: `CCTransCore/Sources/CCTransCore/GoogleWebProvider.swift`
- Create: `CCTransCore/Tests/CCTransCoreTests/GoogleWebProviderTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

`GoogleWebProviderTests.swift`:

```swift
import Testing
import Foundation
@testable import CCTransCore

final class StubHTTPClient: HTTPClient, @unchecked Sendable {
    let fixture: Data
    private(set) var requestedURLs: [URL] = []
    init(fixture: Data) { self.fixture = fixture }
    func fetchData(from url: URL) async throws -> Data {
        requestedURLs.append(url)
        return fixture
    }
}

@Suite struct GoogleWebProviderTests {
    @Test func buildsRequestAndParsesResult() async throws {
        let json = #"[[["안녕하세요","Hello",null,null]],null,"en"]"#
        let stub = StubHTTPClient(fixture: Data(json.utf8))
        let provider = GoogleWebProvider(httpClient: stub)

        let result = try await provider.translate("Hello", to: .korean)

        #expect(result.translatedText == "안녕하세요")
        #expect(result.originalText == "Hello")
        #expect(result.detectedSource == .english)
        #expect(result.target == .korean)
        #expect(result.provider == "google")

        let url = try #require(stub.requestedURLs.first)
        #expect(url.absoluteString.contains("tl=ko"))
        #expect(url.absoluteString.contains("sl=auto"))
    }
}
```

- [ ] **Step 2: 테스트 실행 (실패 확인)**

Run: `swift test --package-path CCTransCore --filter GoogleWebProviderTests`
Expected: 컴파일 실패 — `HTTPClient`, `GoogleWebProvider` 미정의.

- [ ] **Step 3: 구현**

`HTTPClient.swift`:

```swift
import Foundation

public protocol HTTPClient: Sendable {
    func fetchData(from url: URL) async throws -> Data
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func fetchData(from url: URL) async throws -> Data {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  200..<300 ~= http.statusCode else {
                throw TranslationError.network
            }
            return data
        } catch let error as TranslationError {
            throw error
        } catch {
            throw TranslationError.network
        }
    }
}
```

`GoogleWebProvider.swift`:

```swift
import Foundation

public struct GoogleWebProvider: TranslationProvider {
    private let httpClient: HTTPClient
    private let endpoint = "https://translate.googleapis.com/translate_a/single"

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func translate(_ text: String, to target: Language) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationError.emptyInput }

        var components = URLComponents(string: endpoint)
        components?.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: target.code),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: trimmed),
        ]
        guard let url = components?.url else { throw TranslationError.invalidRequest }

        let data = try await httpClient.fetchData(from: url)
        let parsed = try GoogleResponseParser.parse(data)
        return TranslationResult(
            originalText: trimmed,
            translatedText: parsed.translatedText,
            detectedSource: parsed.detectedSource,
            target: target,
            provider: "google"
        )
    }
}
```

- [ ] **Step 4: 테스트 실행 (통과 확인)**

Run: `swift test --package-path CCTransCore --filter GoogleWebProviderTests`
Expected: 1개 테스트 PASS.

- [ ] **Step 5: 커밋**

```bash
git add CCTransCore
git commit -m "feat: add HTTPClient abstraction and GoogleWebProvider"
```

---

## Task 6: TranslationCoordinator (양방향 재호출 오케스트레이션)

**Files:**
- Create: `CCTransCore/Sources/CCTransCore/TranslationCoordinator.swift`
- Create: `CCTransCore/Tests/CCTransCoreTests/TranslationCoordinatorTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

`TranslationCoordinatorTests.swift`:

```swift
import Testing
@testable import CCTransCore

final class MockProvider: TranslationProvider, @unchecked Sendable {
    private var results: [TranslationResult]
    private(set) var requestedTargets: [Language] = []
    init(results: [TranslationResult]) { self.results = results }
    func translate(_ text: String, to target: Language) async throws -> TranslationResult {
        requestedTargets.append(target)
        return results.removeFirst()
    }
}

@Suite struct TranslationCoordinatorTests {
    let router = LanguageRouter(primary: .korean, secondary: .english)

    @Test func foreignSourceTranslatesOnce() async throws {
        let provider = MockProvider(results: [
            TranslationResult(originalText: "Hello", translatedText: "안녕",
                              detectedSource: .english, target: .korean, provider: "mock")
        ])
        let coordinator = TranslationCoordinator(
            provider: provider, router: router, primaryTarget: .korean
        )

        let result = try await coordinator.translate("Hello")

        #expect(result.translatedText == "안녕")
        #expect(provider.requestedTargets == [.korean])
    }

    @Test func koreanSourceReTranslatesToSecondary() async throws {
        let provider = MockProvider(results: [
            TranslationResult(originalText: "안녕", translatedText: "안녕",
                              detectedSource: .korean, target: .korean, provider: "mock"),
            TranslationResult(originalText: "안녕", translatedText: "Hi",
                              detectedSource: .korean, target: .english, provider: "mock"),
        ])
        let coordinator = TranslationCoordinator(
            provider: provider, router: router, primaryTarget: .korean
        )

        let result = try await coordinator.translate("안녕")

        #expect(result.translatedText == "Hi")
        #expect(result.target == .english)
        #expect(provider.requestedTargets == [.korean, .english])
    }
}
```

- [ ] **Step 2: 테스트 실행 (실패 확인)**

Run: `swift test --package-path CCTransCore --filter TranslationCoordinatorTests`
Expected: 컴파일 실패 — `TranslationCoordinator` 미정의.

- [ ] **Step 3: 구현**

`TranslationCoordinator.swift`:

```swift
public struct TranslationCoordinator: Sendable {
    private let provider: TranslationProvider
    private let router: LanguageRouter
    private let primaryTarget: Language

    public init(provider: TranslationProvider, router: LanguageRouter, primaryTarget: Language) {
        self.provider = provider
        self.router = router
        self.primaryTarget = primaryTarget
    }

    /// primaryTarget으로 1차 번역 후, 감지된 원문 언어에 따라 필요 시 재번역한다.
    public func translate(_ text: String) async throws -> TranslationResult {
        let first = try await provider.translate(text, to: primaryTarget)
        let desired = router.target(forDetected: first.detectedSource)
        if desired == first.target { return first }
        return try await provider.translate(text, to: desired)
    }
}
```

- [ ] **Step 4: 테스트 실행 (통과 확인)**

Run: `swift test --package-path CCTransCore --filter TranslationCoordinatorTests`
Expected: 2개 테스트 PASS.

- [ ] **Step 5: 커밋**

```bash
git add CCTransCore
git commit -m "feat: add TranslationCoordinator with bidirectional re-translate"
```

---

## Task 7: DoubleTapDetector (cmd+c 두 번 감지 로직)

**Files:**
- Create: `CCTransCore/Sources/CCTransCore/DoubleTapDetector.swift`
- Create: `CCTransCore/Tests/CCTransCoreTests/DoubleTapDetectorTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

`DoubleTapDetectorTests.swift`:

```swift
import Testing
@testable import CCTransCore

@Suite struct DoubleTapDetectorTests {
    @Test func secondTapWithinThresholdTriggers() {
        var detector = DoubleTapDetector(threshold: 0.4)
        #expect(detector.register(at: 0.0) == false)
        #expect(detector.register(at: 0.3) == true)
    }

    @Test func secondTapBeyondThresholdDoesNotTrigger() {
        var detector = DoubleTapDetector(threshold: 0.4)
        #expect(detector.register(at: 0.0) == false)
        #expect(detector.register(at: 0.6) == false)
    }

    @Test func tripleTapTriggersOnlyOnce() {
        var detector = DoubleTapDetector(threshold: 0.4)
        #expect(detector.register(at: 0.0) == false)
        #expect(detector.register(at: 0.1) == true)
        #expect(detector.register(at: 0.2) == false)
    }
}
```

- [ ] **Step 2: 테스트 실행 (실패 확인)**

Run: `swift test --package-path CCTransCore --filter DoubleTapDetectorTests`
Expected: 컴파일 실패 — `DoubleTapDetector` 미정의.

- [ ] **Step 3: 구현**

`DoubleTapDetector.swift`:

```swift
import Foundation

public struct DoubleTapDetector: Sendable {
    public let threshold: TimeInterval
    private var lastTimestamp: TimeInterval?

    public init(threshold: TimeInterval) {
        self.threshold = threshold
    }

    /// 직전 탭과의 간격이 threshold 이내면 true(트리거)를 반환하고 상태를 리셋한다.
    public mutating func register(at timestamp: TimeInterval) -> Bool {
        if let last = lastTimestamp, timestamp - last <= threshold {
            lastTimestamp = nil
            return true
        }
        lastTimestamp = timestamp
        return false
    }
}
```

- [ ] **Step 4: 테스트 실행 (통과 확인)**

Run: `swift test --package-path CCTransCore`
Expected: 전체 스위트 통과 (모델·Router·Parser·Provider·Coordinator·DoubleTap).

- [ ] **Step 5: 커밋**

```bash
git add CCTransCore
git commit -m "feat: add DoubleTapDetector"
```

---

## Task 8: 앱 타깃 스캐폴딩 (XcodeGen + 메뉴바 셸)

**Files:**
- Create: `project.yml`
- Create: `App/CCTransApp.swift`
- Create: `App/AppDelegate.swift`
- Create: `App/SettingsView.swift` (임시 비어있는 화면)

- [ ] **Step 1: `project.yml` 작성**

```yaml
name: CCTrans
options:
  bundleIdPrefix: com.sangwopark19
  deploymentTarget:
    macOS: "15.0"
packages:
  CCTransCore:
    path: CCTransCore
targets:
  CCTrans:
    type: application
    platform: macOS
    sources:
      - App
    dependencies:
      - package: CCTransCore
        product: CCTransCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.sangwopark19.cctrans
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_LSUIElement: YES
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
        SWIFT_VERSION: "5.0"
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_IDENTITY: "-"
schemes:
  CCTrans:
    build:
      targets:
        CCTrans: all
    run:
      config: Debug
```

- [ ] **Step 2: 앱 진입점 + 임시 셸 작성**

`App/CCTransApp.swift`:

```swift
import SwiftUI

@main
struct CCTransApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("cctrans", systemImage: "character.bubble") {
            SettingsLink { Text("환경설정…") }
                .keyboardShortcut(",")
            Divider()
            Button("종료") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        Settings {
            SettingsView()
        }
    }
}
```

`App/AppDelegate.swift` (이 단계에서는 최소 골격):

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("cctrans launched")
    }
}
```

`App/SettingsView.swift` (임시):

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Text("환경설정 (작업 중)")
            .frame(width: 360, height: 200)
    }
}
```

- [ ] **Step 3: 프로젝트 생성 및 빌드**

Run:
```bash
xcodegen generate
xcodebuild -project CCTrans.xcodeproj -scheme CCTrans -configuration Debug -destination 'platform=macOS' -derivedDataPath build build
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: 수동 검증 (사용자 실행)**

Run: `open build/Build/Products/Debug/CCTrans.app`
Expected: Dock 아이콘 없이 **메뉴바에 말풍선 아이콘**이 뜬다. 클릭 시 "환경설정…", "종료" 메뉴가 보인다. "종료"로 닫힌다.

- [ ] **Step 5: 커밋**

```bash
git add project.yml App
git commit -m "feat: scaffold menu bar app target via XcodeGen"
```

---

## Task 9: PermissionsService (손쉬운 사용 권한)

**Files:**
- Create: `App/PermissionsService.swift`
- Modify: `App/AppDelegate.swift`

- [ ] **Step 1: 구현 (권한 확인/프롬프트)**

`App/PermissionsService.swift`:

```swift
import ApplicationServices

enum PermissionsService {
    /// Accessibility 신뢰 여부. prompt가 true면 미부여 시 시스템 안내를 띄운다.
    static func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
```

- [ ] **Step 2: 앱 시작 시 권한 요청**

`App/AppDelegate.swift`의 `applicationDidFinishLaunching` 본문을 교체:

```swift
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !PermissionsService.isAccessibilityTrusted(prompt: true) {
            NSLog("cctrans: Accessibility 권한 필요 — 시스템 설정에서 허용 필요")
        }
    }
```

- [ ] **Step 3: 빌드**

Run: `xcodegen generate && xcodebuild -project CCTrans.xcodeproj -scheme CCTrans -destination 'platform=macOS' -derivedDataPath build build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: 수동 검증 (사용자 실행)**

Run: `open build/Build/Products/Debug/CCTrans.app`
Expected: 첫 실행 시 **"손쉬운 사용" 권한 요청** 시스템 대화상자가 뜬다. 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에 `CCTrans`를 추가/허용.

- [ ] **Step 5: 커밋**

```bash
git add App
git commit -m "feat: request Accessibility permission on launch"
```

---

## Task 10: PasteboardReader

**Files:**
- Create: `App/PasteboardReader.swift`

- [ ] **Step 1: 구현**

`App/PasteboardReader.swift`:

```swift
import AppKit

struct PasteboardReader {
    /// 클립보드의 문자열을 읽어 공백 정리 후 반환한다. 비어있으면 nil.
    func readSelection() -> String? {
        guard let raw = NSPasteboard.general.string(forType: .string) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
```

- [ ] **Step 2: 빌드 확인**

Run: `xcodegen generate && xcodebuild -project CCTrans.xcodeproj -scheme CCTrans -destination 'platform=macOS' -derivedDataPath build build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: 커밋**

```bash
git add App
git commit -m "feat: add PasteboardReader"
```

---

## Task 11: HotkeyService (CGEventTap → DoubleTapDetector)

**Files:**
- Create: `App/HotkeyService.swift`
- Modify: `App/AppDelegate.swift`

- [ ] **Step 1: 구현**

`App/HotkeyService.swift`:

```swift
import AppKit
import CCTransCore

/// 전역 cmd+c keyDown을 감시하고 threshold 내 두 번 입력 시 콜백을 호출한다.
/// Accessibility 권한이 필요하다.
final class HotkeyService {
    private let onDoubleCopy: () -> Void
    private var detector: DoubleTapDetector
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let cKeyCode: CGKeyCode = 8  // kVK_ANSI_C

    init(threshold: TimeInterval, onDoubleCopy: @escaping () -> Void) {
        self.onDoubleCopy = onDoubleCopy
        self.detector = DoubleTapDetector(threshold: threshold)
    }

    func start() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon in
                if let refcon {
                    let service = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()
                    service.handle(event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            NSLog("cctrans: 이벤트 탭 생성 실패 (Accessibility 권한 확인)")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
    }

    private func handle(_ event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == cKeyCode, event.flags.contains(.maskCommand) else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if detector.register(at: now) {
            onDoubleCopy()
        }
    }
}
```

- [ ] **Step 2: AppDelegate에서 시작 + 임시 로그 연결**

`App/AppDelegate.swift` 전체를 교체:

```swift
import AppKit
import CCTransCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyService: HotkeyService?
    private let pasteboardReader = PasteboardReader()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !PermissionsService.isAccessibilityTrusted(prompt: true) {
            NSLog("cctrans: Accessibility 권한 필요")
        }
        let service = HotkeyService(threshold: 0.4) { [weak self] in
            let text = self?.pasteboardReader.readSelection() ?? "(없음)"
            NSLog("cctrans: double-copy 감지 → \(text)")
        }
        service.start()
        hotkeyService = service
    }
}
```

- [ ] **Step 3: 빌드**

Run: `xcodegen generate && xcodebuild -project CCTrans.xcodeproj -scheme CCTrans -destination 'platform=macOS' -derivedDataPath build build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: 수동 검증 (사용자 실행, 권한 허용 후)**

Run: `open build/Build/Products/Debug/CCTrans.app`
그다음 아무 앱에서 텍스트 선택 후 `cmd+c` 두 번 빠르게 누른다.
검증: `Console.app`에서 `cctrans: double-copy 감지 → <복사한 텍스트>` 로그가 보인다. (천천히 두 번 누르면 트리거되지 않아야 함)

- [ ] **Step 5: 커밋**

```bash
git add App
git commit -m "feat: add HotkeyService with global double-copy detection"
```

---

## Task 12: PopupViewModel + PopupView (SwiftUI)

**Files:**
- Create: `App/PopupViewModel.swift`
- Create: `App/PopupView.swift`

- [ ] **Step 1: 뷰모델 구현**

`App/PopupViewModel.swift`:

```swift
import Observation
import CCTransCore

@MainActor
@Observable
final class PopupViewModel {
    enum State: Equatable {
        case loading
        case result(TranslationResult)
        case error(String)
    }
    var state: State = .loading
}
```

- [ ] **Step 2: 팝업 뷰 구현 (원문 + 번역문 표시)**

`App/PopupView.swift`:

```swift
import SwiftUI
import AppKit
import CCTransCore

struct PopupView: View {
    @Bindable var viewModel: PopupViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch viewModel.state {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("번역 중…").foregroundStyle(.secondary)
                }
            case .result(let result):
                resultView(result)
            case .error(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onExitCommand(perform: onClose)
    }

    @ViewBuilder
    private func resultView(_ result: TranslationResult) -> some View {
        HStack(spacing: 6) {
            languageBadge(result.detectedSource.code)
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
            languageBadge(result.target.code)
            Spacer()
            Button {
                copyToPasteboard(result.translatedText)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("번역문 복사")
        }
        Text(result.translatedText)
            .font(.title3)
            .textSelection(.enabled)
        Divider()
        Text("원문")
            .font(.caption)
            .foregroundStyle(.secondary)
        Text(result.originalText)
            .font(.callout)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
    }

    private func languageBadge(_ code: String) -> some View {
        Text(code.uppercased())
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
```

- [ ] **Step 3: 빌드 확인**

Run: `xcodegen generate && xcodebuild -project CCTrans.xcodeproj -scheme CCTrans -destination 'platform=macOS' -derivedDataPath build build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: 커밋**

```bash
git add App
git commit -m "feat: add popup view model and SwiftUI popup view"
```

---

## Task 13: TranslationPopupController (NSPanel)

**Files:**
- Create: `App/TranslationPopupController.swift`

- [ ] **Step 1: 구현**

`App/TranslationPopupController.swift`:

```swift
import AppKit
import SwiftUI
import CCTransCore

@MainActor
final class TranslationPopupController {
    private var panel: NSPanel?
    private let viewModel = PopupViewModel()

    func showLoading(near point: NSPoint) {
        viewModel.state = .loading
        present(near: point)
    }

    func showResult(_ result: TranslationResult) {
        viewModel.state = .result(result)
    }

    func showError(_ message: String) {
        viewModel.state = .error(message)
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func present(near point: NSPoint) {
        let size = NSSize(width: 360, height: 240)
        if panel == nil {
            let hosting = NSHostingController(
                rootView: PopupView(viewModel: viewModel, onClose: { [weak self] in self?.close() })
            )
            let newPanel = NSPanel(contentViewController: hosting)
            newPanel.styleMask = [.titled, .closable, .fullSizeContentView, .nonactivatingPanel]
            newPanel.titleVisibility = .hidden
            newPanel.titlebarAppearsTransparent = true
            newPanel.isMovableByWindowBackground = true
            newPanel.isFloatingPanel = true
            newPanel.level = .floating
            newPanel.hidesOnDeactivate = false
            panel = newPanel
        }
        guard let panel else { return }
        panel.setContentSize(size)
        // 커서 아래쪽에 표시 (화면 좌표는 좌하단 원점)
        let origin = NSPoint(x: point.x, y: point.y - size.height - 8)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }
}
```

- [ ] **Step 2: 빌드 확인**

Run: `xcodegen generate && xcodebuild -project CCTrans.xcodeproj -scheme CCTrans -destination 'platform=macOS' -derivedDataPath build build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: 커밋**

```bash
git add App
git commit -m "feat: add floating panel popup controller"
```

---

## Task 14: SettingsStore + SettingsView (임계시간·자동실행·대상 언어)

**Files:**
- Create: `App/SettingsStore.swift`
- Modify: `App/SettingsView.swift`

- [ ] **Step 1: SettingsStore 구현**

`App/SettingsStore.swift`:

```swift
import Foundation
import CCTransCore

enum SettingsKeys {
    static let doubleTapThreshold = "doubleTapThreshold"
    static let primaryTargetCode = "primaryTargetCode"
}

struct SettingsStore {
    private let defaults = UserDefaults.standard

    var threshold: TimeInterval {
        let value = defaults.double(forKey: SettingsKeys.doubleTapThreshold)
        return value == 0 ? 0.4 : value
    }

    var primaryTarget: Language {
        let code = defaults.string(forKey: SettingsKeys.primaryTargetCode) ?? "ko"
        return Language(code: code)
    }

    /// 스마트 양방향의 secondary: primary가 한국어면 영어, 아니면 한국어.
    var secondaryTarget: Language {
        primaryTarget == .korean ? .english : .korean
    }
}
```

- [ ] **Step 2: SettingsView 구현**

`App/SettingsView.swift` 전체 교체:

```swift
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage(SettingsKeys.doubleTapThreshold) private var threshold: Double = 0.4
    @AppStorage(SettingsKeys.primaryTargetCode) private var primaryTargetCode: String = "ko"
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let languages: [(code: String, name: String)] = [
        ("ko", "한국어"), ("en", "영어"), ("ja", "일본어"),
        ("zh-CN", "중국어(간체)"), ("es", "스페인어"), ("fr", "프랑스어"),
    ]

    var body: some View {
        Form {
            Picker("기본 대상 언어", selection: $primaryTargetCode) {
                ForEach(languages, id: \.code) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }

            VStack(alignment: .leading) {
                Text("더블탭 인식 시간: \(threshold, specifier: "%.2f")초")
                Slider(value: $threshold, in: 0.2...0.8, step: 0.05)
            }

            Toggle("로그인 시 자동 실행", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        NSLog("cctrans: 로그인 항목 변경 실패 \(error)")
                    }
                }
        }
        .padding(20)
        .frame(width: 380)
    }
}
```

- [ ] **Step 3: 빌드 확인**

Run: `xcodegen generate && xcodebuild -project CCTrans.xcodeproj -scheme CCTrans -destination 'platform=macOS' -derivedDataPath build build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: 수동 검증 (사용자 실행)**

`open build/Build/Products/Debug/CCTrans.app` 후 메뉴바 > 환경설정. 대상 언어 Picker, 임계시간 슬라이더, 자동 실행 토글이 동작하는지 확인.

- [ ] **Step 5: 커밋**

```bash
git add App
git commit -m "feat: add settings store and settings UI"
```

---

## Task 15: 엔드투엔드 배선 (hotkey → pasteboard → coordinator → popup)

**Files:**
- Modify: `App/AppDelegate.swift`

- [ ] **Step 1: AppDelegate 전체 배선으로 교체**

`App/AppDelegate.swift` 전체 교체:

```swift
import AppKit
import CCTransCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyService: HotkeyService?
    private let pasteboardReader = PasteboardReader()
    private let popupController = TranslationPopupController()
    private let settings = SettingsStore()

    private lazy var coordinator: TranslationCoordinator = {
        let provider = GoogleWebProvider(httpClient: URLSessionHTTPClient())
        let router = LanguageRouter(primary: settings.primaryTarget, secondary: settings.secondaryTarget)
        return TranslationCoordinator(provider: provider, router: router, primaryTarget: settings.primaryTarget)
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !PermissionsService.isAccessibilityTrusted(prompt: true) {
            NSLog("cctrans: Accessibility 권한 필요")
        }
        let service = HotkeyService(threshold: settings.threshold) { [weak self] in
            self?.handleTranslateTrigger()
        }
        service.start()
        hotkeyService = service
    }

    private func handleTranslateTrigger() {
        guard let text = pasteboardReader.readSelection() else { return }
        let location = NSEvent.mouseLocation
        popupController.showLoading(near: location)
        Task {
            do {
                let result = try await coordinator.translate(text)
                popupController.showResult(result)
            } catch {
                popupController.showError("번역에 실패했습니다. 잠시 후 다시 시도하세요.")
            }
        }
    }
}
```

- [ ] **Step 2: 빌드**

Run: `xcodegen generate && xcodebuild -project CCTrans.xcodeproj -scheme CCTrans -destination 'platform=macOS' -derivedDataPath build build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: 수동 검증 — 전체 흐름 (사용자 실행)**

`open build/Build/Products/Debug/CCTrans.app` (권한 허용 상태).
1. 영어 텍스트 선택 → `cmd+c+c` → 커서 근처에 팝업, **한국어 번역 + 원문** 표시.
2. 한국어 텍스트 선택 → `cmd+c+c` → **영어 번역** 표시 (스마트 양방향).
3. 복사 버튼으로 번역문 복사, `Esc`로 팝업 닫힘.
4. 네트워크 끊고 시도 → 오류 메시지 + (재시도는 다시 cmd+c+c).

- [ ] **Step 4: 커밋**

```bash
git add App
git commit -m "feat: wire end-to-end translation flow"
```

---

## Task 16: README + ADR (비공식 Google 엔드포인트 기록)

**Files:**
- Create: `README.md`
- Create: `docs/adr/0001-unofficial-google-endpoint.md`

- [ ] **Step 1: ADR 작성**

`docs/adr/0001-unofficial-google-endpoint.md`:

```markdown
# ADR 0001: v1 번역 엔진으로 비공식 Google 웹 엔드포인트 사용

## 상태
승인됨 (v1)

## 맥락
v1은 빠르게 동작하는 텍스트 번역이 목표다. 공식 Google Cloud Translation API는 API 키와 결제 설정이 필요해 오픈소스 자체빌드 사용자에게 진입장벽이 된다.

## 결정
`translate.googleapis.com/translate_a/single` 무료 웹 엔드포인트를 기본 엔진으로 사용한다. 키가 필요 없고 개인·저용량 사용에 충분하다.

## 결과
- 장점: 키 없이 즉시 동작, 자동 언어 감지 제공.
- 단점: 비공식·비문서화 — 변경/레이트리밋 위험. `TranslationProvider` 추상화로 Apple 시스템 번역·외부 API provider를 드롭인 교체 가능하게 두어 위험을 완화한다.
```

- [ ] **Step 2: README 작성**

`README.md`:

```markdown
# cctrans

Mac 어디서든 `cmd+c+c`(복사 두 번)로 즉시 번역하는 메뉴바 앱.

## 기능 (v1)
- 텍스트 선택 후 `cmd+c+c` → 커서 근처 팝업에 번역(원문 + 번역문) 표시
- 스마트 양방향: 한국어→영어, 그 외→한국어 (대상 언어 설정 가능)
- Google 무료 엔드포인트 기반 (키 불필요)

## 요구사항
- macOS 15+
- Xcode 16+, [XcodeGen](https://github.com/yonzkon/XcodeGen) (`brew install xcodegen`)

## 빌드
\`\`\`bash
swift test --package-path CCTransCore        # 코어 로직 테스트
xcodegen generate
xcodebuild -project CCTrans.xcodeproj -scheme CCTrans -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/CCTrans.app
\`\`\`

## 권한
첫 실행 시 **손쉬운 사용(Accessibility)** 권한을 허용해야 전역 단축키가 동작합니다.
시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 `CCTrans`를 활성화하세요.

## 로드맵
- OCR 텍스트추출 번역 (Vision + 화면 캡처)
- OCR 이미지 위치 오버레이 번역
- Apple 시스템 번역 / 외부 API(DeepL, OpenAI 등) provider
```

- [ ] **Step 3: 커밋**

```bash
git add README.md docs/adr
git commit -m "docs: add README and ADR for unofficial Google endpoint"
```

---

## 자체 검토 (작성자 체크리스트 결과)

- **스펙 커버리지**: §3 모듈 → Task 2~14에 각각 대응. §4 cmd+c+c → Task 7(감지 로직)+11(이벤트탭). §5 엔진 → Task 5+6. §6 팝업(원문+번역문) → Task 12. §7 설정(임계시간·자동실행·대상언어) → Task 14. §8 에러 → Task 5(network/empty)+15(팝업 오류). §9 테스트(순수 로직 단위테스트) → Task 3~7. §10 위험(ADR) → Task 16. §11 이후 단계 → README 로드맵. 누락 없음.
- **플레이스홀더**: 모든 코드 스텝에 실제 코드 포함. "적절히 처리" 류 없음.
- **타입 일관성**: `Language`/`TranslationResult`(originalText 포함)/`TranslationProvider.translate(_:to:)`/`fetchData(from:)`/`DoubleTapDetector.register(at:)`/`LanguageRouter.target(forDetected:)`/`TranslationCoordinator.translate(_:)` 시그니처가 정의·사용처에서 일치.
- **알려진 제약**: 미서명 로컬 빌드는 재빌드 시 손쉬운 사용 권한 재요청이 발생할 수 있음(개발 단계 한정). 임계시간 변경은 앱 재시작 후 반영(`coordinator`/`HotkeyService`가 시작 시 설정을 읽음).

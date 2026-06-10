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
```bash
swift test --package-path CCTransCore        # 코어 로직 테스트
xcodegen generate
xcodebuild -project CCTrans.xcodeproj -scheme CCTrans -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/CCTrans.app
```

## 권한
첫 실행 시 **손쉬운 사용(Accessibility)** 권한을 허용해야 전역 단축키가 동작합니다.
시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 `CCTrans`를 활성화하세요.

## 로드맵
- OCR 텍스트추출 번역 (Vision + 화면 캡처)
- OCR 이미지 위치 오버레이 번역
- Apple 시스템 번역 / 외부 API(DeepL, OpenAI 등) provider

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

## 안정적 서명 (개발 셋업, 1회)

기본 Debug 빌드는 ad-hoc 서명이라 **재빌드마다 손쉬운 사용 권한이 풀린다**(코드 서명이 매번 달라지기 때문). 안정적 self-signed 인증서로 서명하면 권한이 유지된다:

```bash
./scripts/make-signing-cert.sh   # 'cctrans-dev' 인증서 1회 생성 (로그인 암호 프롬프트가 뜰 수 있음)
```

이후 빌드는 `project.yml`이 이 인증서로 Manual 서명한다. 첫 빌드에서 codesign 키 접근 허용("항상 허용")을 한 번 누르면 된다. 손쉬운 사용 권한은 한 번만 부여하면 재빌드에도 유지된다.

대안: Keychain Access → 인증서 지원 → 인증서 생성에서 이름 `cctrans-dev`, 유형 "코드 서명"으로 직접 만들어도 된다.

## 로드맵
- OCR 텍스트추출 번역 (Vision + 화면 캡처)
- OCR 이미지 위치 오버레이 번역
- Apple 시스템 번역 / 외부 API(DeepL, OpenAI 등) provider

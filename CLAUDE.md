# cctrans

## Agent skills

### Issue tracker

Issues and PRDs are tracked as GitHub issues via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical triage roles using default label strings (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout — `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Build & architecture

- `CCTransCore/` — 순수 로직 Swift 패키지; `swift test --package-path CCTransCore`로 빠른 테스트
- `App/` — AppKit/SwiftUI 메뉴바 셸; Xcode 프로젝트는 `project.yml`에서 XcodeGen으로 생성
- 빌드/실행: `xcodegen generate && xcodebuild -project CCTrans.xcodeproj -scheme CCTrans -configuration Debug -derivedDataPath build build && open build/Build/Products/Debug/CCTrans.app`
- `App/*.swift` 파일 추가 후에는 `xcodegen generate` 재실행(컴파일 포함되도록)
- `CCTrans.xcodeproj`·`build/`는 절대 커밋 금지(gitignored, 재생성)
- Swift 6 언어 모드, macOS 15+ 배포 타깃

## Signing

- Debug 빌드는 안정적 self-signed `cctrans-dev`로 서명 — `scripts/make-signing-cert.sh` 1회 실행. Manual 서명 유지; ad-hoc(`CODE_SIGN_IDENTITY: "-"`)으로 되돌리면 재빌드마다 손쉬운 사용 권한이 풀림

## Docs

- 설계 스펙·구현 계획: `docs/superpowers/specs/`, `docs/superpowers/plans/`

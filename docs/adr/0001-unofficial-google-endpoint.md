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

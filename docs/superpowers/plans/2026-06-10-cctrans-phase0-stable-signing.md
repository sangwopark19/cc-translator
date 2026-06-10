# cctrans Phase 0 — 안정적 서명 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Debug 빌드를 안정적인 self-signed 인증서로 서명해, 재빌드해도 코드 서명(지정 요구사항)이 동일하게 유지되도록 한다 → 손쉬운 사용(Accessibility) 권한이 재빌드마다 풀리지 않는다.

**Architecture:** 코드사이닝용 self-signed 인증서 `cctrans-dev`를 로그인 키체인에 1회 생성(멱등 스크립트)하고, `project.yml`을 Manual 서명 + 그 인증서로 전환한다. 비즈니스 로직이 아니므로 단위테스트가 아니라 **실행 + 검증 게이트**(codesign/security 명령)로 검증한다.

**Tech Stack:** bash, openssl(LibreSSL), `security`(keychain), `codesign`, XcodeGen, xcodebuild. macOS 15+.

> **주의(사람 개입 가능 지점):** 인증서 생성 시 `security`가 **로그인 암호 / 키체인 접근 승인** GUI 프롬프트를 띄울 수 있고, 첫 빌드 시 codesign이 키 접근 허용("항상 허용") 프롬프트를 띄울 수 있다. 모두 1회성이며, 이후 재빌드는 비대화식으로 동일 서명된다.

---

## Task 1: 서명 인증서 생성 스크립트

**Files:**
- Create: `scripts/make-signing-cert.sh`

- [ ] **Step 1: 스크립트 작성**

`scripts/make-signing-cert.sh`:

```bash
#!/usr/bin/env bash
# 코드사이닝용 self-signed 인증서 "cctrans-dev"를 로그인 키체인에 생성한다.
# 재빌드해도 서명이 안정적으로 유지되어 Accessibility 권한이 보존된다. 멱등.
set -euo pipefail

CERT_NAME="cctrans-dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$CERT_NAME" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "인증서 '$CERT_NAME' 이미 존재. 건너뜀."
  security find-identity -p codesigning "$KEYCHAIN" | grep "$CERT_NAME" || true
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<'EOF'
[req]
distinguished_name = dn
prompt = no
[dn]
CN = cctrans-dev
[v3]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF

# 1) self-signed 코드사이닝 인증서 + 개인키 생성
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
  -days 3650 -config "$TMP/cert.cnf" -extensions v3

# 2) PKCS#12로 묶기 (빈 암호)
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/cert.p12" -passout pass:

# 3) 로그인 키체인에 import (codesign이 키 사용하도록 ACL 부여)
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "" -T /usr/bin/codesign

# 4) codesign이 키를 비대화식으로 쓰도록 partition list 설정 (키체인 암호 프롬프트가 뜰 수 있음)
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$KEYCHAIN" >/dev/null 2>&1 \
  || echo "NOTE: partition-list 설정 생략됨 — 첫 빌드 때 codesign 키 접근 허용('항상 허용')을 눌러야 할 수 있음."

# 5) 코드사이닝 신뢰 설정 (로그인 암호 프롬프트가 뜰 수 있음)
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem" \
  || echo "NOTE: trust 설정 실패/생략 — 로컬 서명에는 보통 문제 없음."

echo "인증서 '$CERT_NAME' 생성 완료."
security find-identity -p codesigning "$KEYCHAIN" | grep "$CERT_NAME" || true
```

- [ ] **Step 2: 실행 권한 부여 + 실행**

Run:
```bash
chmod +x scripts/make-signing-cert.sh
./scripts/make-signing-cert.sh
```
Expected: "인증서 'cctrans-dev' 생성 완료." 출력. (중간에 로그인 암호/키체인 승인 프롬프트가 뜨면 승인.)

- [ ] **Step 3: 인증서가 코드사이닝 ID로 보이는지 검증**

Run: `security find-identity -p codesigning "$HOME/Library/Keychains/login.keychain-db" | grep cctrans-dev`
Expected: `cctrans-dev`를 포함한 한 줄(인증서 SHA-1 해시와 `"cctrans-dev"`). 비어 있으면 BLOCKED로 보고하고 trust 단계(스크립트 5) 재시도 또는 Keychain Access GUI 안내.

- [ ] **Step 4: 멱등성 확인**

Run: `./scripts/make-signing-cert.sh`
Expected: "이미 존재. 건너뜀." 출력 (중복 생성 안 함).

- [ ] **Step 5: 커밋**

```bash
git add scripts/make-signing-cert.sh
git commit -m "feat: add self-signed code-signing certificate script"
```

---

## Task 2: project.yml을 Manual 서명으로 전환 + 안정성 검증

**Files:**
- Modify: `project.yml:26-27`

- [ ] **Step 1: project.yml 서명 설정 변경**

`project.yml`의 `settings.base`에서 두 줄을 교체:

기존:
```yaml
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_IDENTITY: "-"
```
변경:
```yaml
        CODE_SIGN_STYLE: Manual
        CODE_SIGN_IDENTITY: "cctrans-dev"
```
(다른 키 PRODUCT_BUNDLE_IDENTIFIER 등은 그대로 둔다.)

- [ ] **Step 2: 재생성 + 빌드**

Run:
```bash
xcodegen generate
xcodebuild -project CCTrans.xcodeproj -scheme CCTrans -configuration Debug -destination 'platform=macOS' -derivedDataPath build build
```
Expected: `BUILD SUCCEEDED`. (첫 빌드에서 codesign 키 접근 허용 프롬프트가 뜨면 "항상 허용".) 만약 "No signing identity found" 또는 서명 에러가 나면 BLOCKED로 보고 — Task 1의 trust 단계가 필요.

- [ ] **Step 3: 앱이 그 인증서로 서명됐는지 검증**

Run: `codesign -dvv build/Build/Products/Debug/CCTrans.app 2>&1 | grep -E "Authority|Identifier"`
Expected: `Authority=cctrans-dev` 와 `Identifier=com.sangwopark19.cctrans` 가 보인다.

- [ ] **Step 4: 지정 요구사항(designated requirement)이 재빌드에 안정적인지 검증 (핵심)**

Run:
```bash
codesign -d --requirements - build/Build/Products/Debug/CCTrans.app 2>&1 | tee /tmp/dr1.txt
# 클린 재빌드
rm -rf build
xcodebuild -project CCTrans.xcodeproj -scheme CCTrans -configuration Debug -destination 'platform=macOS' -derivedDataPath build build >/dev/null 2>&1
codesign -d --requirements - build/Build/Products/Debug/CCTrans.app 2>&1 | tee /tmp/dr2.txt
diff /tmp/dr1.txt /tmp/dr2.txt && echo "STABLE: 지정 요구사항이 재빌드에도 동일"
```
Expected: `diff`가 차이 없음 + "STABLE: ..." 출력. 지정 요구사항이 인증서 기반(`certificate leaf[subject.CN] = "cctrans-dev"` 등)이고 cdhash에 의존하지 않으므로 동일해야 한다. → 이게 TCC 권한 유지의 근거.

- [ ] **Step 5: 커밋**

```bash
git add project.yml
git commit -m "build: sign Debug builds with stable cctrans-dev identity"
```

---

## Task 3: README 서명 안내 + TCC 유지 수동 검증

**Files:**
- Modify: `README.md` (권한 섹션 아래에 서명 셋업 추가)

- [ ] **Step 1: README에 서명 셋업 섹션 추가**

`README.md`의 `## 권한` 섹션 바로 아래에 다음을 추가:

```markdown
## 안정적 서명 (개발 셋업, 1회)

기본 Debug 빌드는 ad-hoc 서명이라 **재빌드마다 손쉬운 사용 권한이 풀린다**(코드 서명이 매번 달라지기 때문). 안정적 self-signed 인증서로 서명하면 권한이 유지된다:

\`\`\`bash
./scripts/make-signing-cert.sh   # 'cctrans-dev' 인증서 1회 생성 (로그인 암호 프롬프트가 뜰 수 있음)
\`\`\`

이후 빌드는 `project.yml`이 이 인증서로 Manual 서명한다. 첫 빌드에서 codesign 키 접근 허용("항상 허용")을 한 번 누르면 된다. 손쉬운 사용 권한은 한 번만 부여하면 재빌드에도 유지된다.

대안: Keychain Access → 인증서 지원 → 인증서 생성에서 이름 `cctrans-dev`, 유형 "코드 서명"으로 직접 만들어도 된다.
```

- [ ] **Step 2: 수동 검증 — 권한이 재빌드에 유지되는지 (사용자 실행)**

1. (권한이 아직 없으면) 앱 실행 → 시스템 설정 > 손쉬운 사용에서 CCTrans 활성화.
2. `rm -rf build && xcodegen generate && xcodebuild ... build && open build/Build/Products/Debug/CCTrans.app`로 **재빌드 후 재실행**.
3. 텍스트 선택 후 `cmd+c+c` → 권한 재부여 없이 번역 팝업이 뜨면 성공 (이전엔 재빌드 후 단축키가 죽었음).

- [ ] **Step 3: 커밋**

```bash
git add README.md
git commit -m "docs: document stable code-signing setup"
```

---

## 자체 검토 (작성자 체크리스트 결과)

- **스펙 커버리지**: 스펙 §4(Phase 0)의 3요소 — 인증서 생성 스크립트(Task 1), `project.yml` Manual 서명(Task 2), README 안내(Task 3) — 모두 대응. 지정 요구사항 안정성(스펙의 TCC 유지 근거)은 Task 2 Step 4에서 명시 검증.
- **플레이스홀더**: 스크립트·명령·검증이 모두 구체적. "적절히 처리" 류 없음.
- **타입/이름 일관성**: 인증서명 `cctrans-dev`와 번들 id `com.sangwopark19.cctrans`가 스크립트·project.yml·검증 명령에서 일치.
- **알려진 제약**: 인증서 trust/partition 단계와 첫 빌드 codesign 접근은 1회 GUI 승인이 필요할 수 있음(명시). self-signed라 Gatekeeper 배포용은 아님(로컬/자체빌드 전용, 스펙 의도와 일치).

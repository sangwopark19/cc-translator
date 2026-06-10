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

# 2) PKCS#12로 묶기. macOS Security가 OpenSSL 3.x의 기본 MAC(SHA-256)을 못 읽으므로
#    -legacy 알고리즘을 쓰고, passphrase를 둔다(빈 암호 import는 불안정). LibreSSL은
#    -legacy를 모르므로 그 경우 폴백한다.
P12_PASS="cctrans-import"
if ! openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
      -out "$TMP/cert.p12" -passout "pass:$P12_PASS" 2>/dev/null; then
  openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/cert.p12" -passout "pass:$P12_PASS"
fi

# 3) 로그인 키체인에 import (codesign이 키 사용하도록 ACL 부여)
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$P12_PASS" -T /usr/bin/codesign

# 4) codesign이 키를 비대화식으로 쓰도록 partition list 설정 (키체인 암호 프롬프트가 뜰 수 있음)
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$KEYCHAIN" >/dev/null 2>&1 \
  || echo "NOTE: partition-list 설정 생략됨 — 첫 빌드 때 codesign 키 접근 허용('항상 허용')을 눌러야 할 수 있음."

# 5) 코드사이닝 신뢰 설정 (로그인 암호 프롬프트가 뜰 수 있음)
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem" \
  || echo "NOTE: trust 설정 실패/생략 — 로컬 서명에는 보통 문제 없음."

echo "인증서 '$CERT_NAME' 생성 완료."
security find-identity -p codesigning "$KEYCHAIN" | grep "$CERT_NAME" || true

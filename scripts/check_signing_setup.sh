#!/usr/bin/env bash

set -euo pipefail

if [[ -f ".env.release" ]]; then
  # shellcheck disable=SC1091
  source .env.release
fi

DEV_ID_APP_CERT="${DEV_ID_APP_CERT:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}"

fail=0

echo "==> Verificando identidades de assinatura"
security find-identity -v -p codesigning "$KEYCHAIN_PATH" || true

if ! security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep -q "Developer ID Application"; then
  echo "ERRO: nenhum 'Developer ID Application' encontrado no keychain"
  fail=1
fi

if [[ -z "$DEV_ID_APP_CERT" ]]; then
  echo "ERRO: DEV_ID_APP_CERT não definido em .env.release"
  fail=1
else
  if ! security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep -Fq "$DEV_ID_APP_CERT"; then
    echo "ERRO: DEV_ID_APP_CERT não corresponde a nenhuma identidade válida"
    echo "Valor atual: $DEV_ID_APP_CERT"
    fail=1
  fi
fi

echo
echo "==> Verificando profile de notarização"
if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "ERRO: NOTARY_PROFILE não definido em .env.release"
  fail=1
else
  if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "ERRO: profile '$NOTARY_PROFILE' inválido/ausente no Keychain"
    fail=1
  else
    echo "OK: profile '$NOTARY_PROFILE' válido"
  fi
fi

echo
if [[ $fail -ne 0 ]]; then
  echo "Preflight falhou. Corrija os itens acima antes de gerar release."
  exit 1
fi

echo "Preflight OK. Assinador e notarização prontos."

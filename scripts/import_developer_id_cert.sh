#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Uso: $0 <caminho_do_certificado.p12> <senha_do_p12> [keychain_path]"
  exit 1
fi

P12_PATH="$1"
P12_PASSWORD="$2"
KEYCHAIN_PATH="${3:-$HOME/Library/Keychains/login.keychain-db}"

if [[ ! -f "$P12_PATH" ]]; then
  echo "Arquivo não encontrado: $P12_PATH"
  exit 1
fi

echo "Importando certificado em: $KEYCHAIN_PATH"
security import "$P12_PATH" \
  -k "$KEYCHAIN_PATH" \
  -P "$P12_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  -T /usr/bin/productbuild

echo
echo "Identidades de assinatura disponíveis:"
security find-identity -v -p codesigning "$KEYCHAIN_PATH"

echo
echo "Se aparecer 'Developer ID Application', copie exatamente o nome para DEV_ID_APP_CERT no .env.release"

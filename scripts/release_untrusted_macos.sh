#!/usr/bin/env bash

set -euo pipefail

APP_NAME="${APP_NAME:-MenuProUI-MAC}"
APP_PATH="${APP_PATH:-dist/${APP_NAME}.app}"
DIST_DIR="${DIST_DIR:-dist}"
ARCH_LABEL="${ARCH_LABEL:-macos-arm64}"
DEFAULT_VERSION="${DEFAULT_VERSION:-1.7}"

if [[ -f ".env.release" ]]; then
  # shellcheck disable=SC1091
  source .env.release
fi

VERSION="${1:-$DEFAULT_VERSION}"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-app-${ARCH_LABEL}-${VERSION}.zip"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${ARCH_LABEL}-${VERSION}.dmg"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Comando obrigatório não encontrado: $1"
    exit 1
  fi
}

require_command swift
require_command plutil
require_command codesign
require_command ditto
require_command hdiutil

mkdir -p "$DIST_DIR"

echo "==> Build release SwiftPM"
swift build -c release

if [[ ! -d "$APP_PATH" ]]; then
  echo "App não encontrado em: $APP_PATH"
  echo "Monte o bundle .app em dist antes de rodar este script."
  exit 1
fi

echo "==> Atualizar versão no Info.plist (${VERSION})"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP_PATH/Contents/Info.plist"

echo "==> Limpar atributos estendidos"
xattr -cr "$APP_PATH"

echo "==> Assinar ad-hoc (sem Apple Developer)"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "==> Gerar ZIP"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Gerar DMG"
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"

echo
echo "Artefatos gerados:"
echo "- $ZIP_PATH"
echo "- $DMG_PATH"
echo
echo "Importante: sem Developer ID/notarização, outro Mac pode bloquear na primeira abertura."
echo "No Mac de destino: clique direito no app -> Open, ou use Configurações -> Privacidade e Segurança -> Open Anyway."

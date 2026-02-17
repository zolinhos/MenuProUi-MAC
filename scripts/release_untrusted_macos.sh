#!/usr/bin/env bash

set -euo pipefail

APP_NAME="${APP_NAME:-MenuProUI-MAC}"
APP_PATH="${APP_PATH:-dist/${APP_NAME}.app}"
DIST_DIR="${DIST_DIR:-dist}"
ARCH_LABEL="${ARCH_LABEL:-macos-arm64}"
DEFAULT_VERSION="${DEFAULT_VERSION:-1.7.10}"

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

sync_app_from_build() {
  local build_bin
  local build_bundle

  build_bin="$(find .build -type f -path "*/release/${APP_NAME}" | head -n 1)"
  build_bundle="$(find .build -type d -path "*/release/${APP_NAME}_${APP_NAME}.bundle" | head -n 1)"

  if [[ -z "$build_bin" || ! -f "$build_bin" ]]; then
    echo "Binário release não encontrado em .build para ${APP_NAME}"
    exit 1
  fi

  echo "==> Sincronizar binário compilado no app bundle"
  cp -f "$build_bin" "$APP_PATH/Contents/MacOS/${APP_NAME}"
  chmod +x "$APP_PATH/Contents/MacOS/${APP_NAME}"

  if [[ -n "$build_bundle" && -d "$build_bundle" ]]; then
    echo "==> Sincronizar resources bundle compilado"
    rm -rf "$APP_PATH/Contents/Resources/${APP_NAME}_${APP_NAME}.bundle"
    cp -R "$build_bundle" "$APP_PATH/Contents/Resources/"
  fi
}

mkdir -p "$DIST_DIR"

echo "==> Build release SwiftPM"
swift build -c release

if [[ ! -d "$APP_PATH" ]]; then
  echo "App não encontrado em: $APP_PATH"
  echo "Monte o bundle .app em dist antes de rodar este script."
  exit 1
fi

sync_app_from_build

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

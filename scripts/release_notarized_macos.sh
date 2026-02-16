#!/usr/bin/env bash

set -euo pipefail

APP_NAME="${APP_NAME:-MenuProUI-MAC}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.menuproui.mac}"
APP_PATH="${APP_PATH:-dist/${APP_NAME}.app}"
DIST_DIR="${DIST_DIR:-dist}"
ARCH_LABEL="${ARCH_LABEL:-macos-arm64}"
MIN_MACOS="${MIN_MACOS:-13.0}"
DEFAULT_VERSION="${DEFAULT_VERSION:-1.7}"
DEV_ID_APP_CERT="${DEV_ID_APP_CERT:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
AC_USERNAME="${AC_USERNAME:-}"
AC_PASSWORD="${AC_PASSWORD:-}"
AC_TEAM_ID="${AC_TEAM_ID:-}"

if [[ -f ".env.release" ]]; then
  # shellcheck disable=SC1091
  source ".env.release"
fi

VERSION="${1:-$DEFAULT_VERSION}"
DATE_TAG="$(date +%Y-%m-%d)"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-app-${ARCH_LABEL}-${VERSION}.zip"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${ARCH_LABEL}-${VERSION}.dmg"
NOTARY_LOG_DIR="${DIST_DIR}/notary-logs"

log() {
  echo
  echo "==> $*"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Comando obrigatório não encontrado: $1"
    exit 1
  fi
}

notary_submit_wait() {
  local artifact="$1"
  if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit "$artifact" --keychain-profile "$NOTARY_PROFILE" --wait
  else
    if [[ -z "$AC_USERNAME" || -z "$AC_PASSWORD" || -z "$AC_TEAM_ID" ]]; then
      echo "Defina NOTARY_PROFILE ou AC_USERNAME + AC_PASSWORD + AC_TEAM_ID"
      exit 1
    fi
    xcrun notarytool submit "$artifact" \
      --apple-id "$AC_USERNAME" \
      --password "$AC_PASSWORD" \
      --team-id "$AC_TEAM_ID" \
      --wait
  fi
}

require_command swift
require_command codesign
require_command spctl
require_command xcrun
require_command ditto
require_command hdiutil
require_command plutil

if [[ $# -lt 1 ]]; then
  echo "Versão não informada, usando padrão: ${VERSION}"
fi

if [[ -z "$DEV_ID_APP_CERT" ]]; then
  echo "Defina DEV_ID_APP_CERT com o certificado Developer ID Application"
  echo "Exemplo: DEV_ID_APP_CERT='Developer ID Application: Seu Nome (TEAMID)'"
  exit 1
fi

mkdir -p "$DIST_DIR" "$NOTARY_LOG_DIR"

log "Build release SwiftPM"
swift build -c release

if [[ ! -d "$APP_PATH" ]]; then
  echo "App não encontrado em: $APP_PATH"
  echo "Monte o bundle .app em dist antes de rodar este script."
  exit 1
fi

log "Atualizar versão no Info.plist (${VERSION})"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$APP_BUNDLE_ID" "$APP_PATH/Contents/Info.plist"
plutil -replace LSMinimumSystemVersion -string "$MIN_MACOS" "$APP_PATH/Contents/Info.plist"

log "Limpar atributos estendidos"
xattr -cr "$APP_PATH"

log "Assinar app com Developer ID"
codesign --force --deep --timestamp --options runtime --sign "$DEV_ID_APP_CERT" "$APP_PATH"

log "Validar assinatura do app"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute -vvv "$APP_PATH"

log "Gerar ZIP para notarização"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

log "Notarizar ZIP"
notary_submit_wait "$ZIP_PATH" | tee "${NOTARY_LOG_DIR}/notary-zip-${VERSION}-${DATE_TAG}.log"

log "Staple no app"
xcrun stapler staple "$APP_PATH"

log "Gerar DMG"
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"

log "Assinar DMG"
codesign --force --timestamp --sign "$DEV_ID_APP_CERT" "$DMG_PATH"

log "Notarizar DMG"
notary_submit_wait "$DMG_PATH" | tee "${NOTARY_LOG_DIR}/notary-dmg-${VERSION}-${DATE_TAG}.log"

log "Staple no DMG"
xcrun stapler staple "$DMG_PATH"

log "Validações finais Gatekeeper"
spctl --assess --type execute -vvv "$APP_PATH"
spctl --assess --type open -vvv "$DMG_PATH"

log "Release concluída"
echo "App: $APP_PATH"
echo "Zip: $ZIP_PATH"
echo "Dmg: $DMG_PATH"

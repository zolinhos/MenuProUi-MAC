#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME="${1:-notary-profile}"
APPLE_ID="${2:-${AC_USERNAME:-}}"
TEAM_ID="${3:-${AC_TEAM_ID:-}}"
APP_PASSWORD="${4:-${AC_PASSWORD:-}}"

if [[ -z "$APPLE_ID" ]]; then
  read -r -p "Apple ID: " APPLE_ID
fi

if [[ -z "$TEAM_ID" ]]; then
  read -r -p "Team ID: " TEAM_ID
fi

if [[ -z "$APP_PASSWORD" ]]; then
  read -r -s -p "App-specific password: " APP_PASSWORD
  echo
fi

xcrun notarytool store-credentials "$PROFILE_NAME" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_PASSWORD"

echo
echo "Perfil salvo: $PROFILE_NAME"
echo "Use: export NOTARY_PROFILE=\"$PROFILE_NAME\""

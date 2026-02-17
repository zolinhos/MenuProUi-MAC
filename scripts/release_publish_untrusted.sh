#!/usr/bin/env bash

set -euo pipefail

if [[ -f ".env.release" ]]; then
  # shellcheck disable=SC1091
  source .env.release
fi

APP_NAME="${APP_NAME:-MenuProUI-MAC}"
DIST_DIR="${DIST_DIR:-dist}"
ARCH_LABEL="${ARCH_LABEL:-macos-arm64}"
DEFAULT_VERSION="${DEFAULT_VERSION:-1.7.10}"

VERSION_INPUT="${1:-$DEFAULT_VERSION}"
OWNER_REPO_INPUT="${2:-${GITHUB_REPO:-}}"

normalize_version() {
  local raw="$1"
  if [[ "$raw" == v* ]]; then
    echo "${raw#v}"
  else
    echo "$raw"
  fi
}

repo_from_origin() {
  local remote_url
  remote_url="$(git config --get remote.origin.url || true)"

  if [[ -z "$remote_url" ]]; then
    return 1
  fi

  if [[ "$remote_url" =~ ^git@github.com:(.+)\.git$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$remote_url" =~ ^https://github.com/(.+)\.git$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Comando obrigatório não encontrado: $1"
    exit 1
  fi
}

require_command git
require_command python3
require_command bash

VERSION="$(normalize_version "$VERSION_INPUT")"
TAG="v${VERSION}"
RELEASE_NAME="Versão ${APP_NAME} ${VERSION}"
OWNER_REPO="$OWNER_REPO_INPUT"

if [[ -z "$OWNER_REPO" ]]; then
  OWNER_REPO="$(repo_from_origin || true)"
fi

if [[ -z "$OWNER_REPO" ]]; then
  echo "Não foi possível detectar owner/repo. Passe como 2º argumento:"
  echo "  bash scripts/release_publish_untrusted.sh ${VERSION} owner/repo"
  exit 1
fi

ZIP_PATH="${DIST_DIR}/${APP_NAME}-app-${ARCH_LABEL}-${VERSION}.zip"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${ARCH_LABEL}-${VERSION}.dmg"
NOTES_PATH="${DIST_DIR}/release_notes_${TAG}.md"

mkdir -p "$DIST_DIR"

echo "==> Preflight checklist automático"
bash scripts/release_preflight.sh "$VERSION"

echo "==> [1/4] Gerar artefatos ${VERSION}"
bash scripts/release_untrusted_macos.sh "$VERSION"

if [[ ! -f "$ZIP_PATH" || ! -f "$DMG_PATH" ]]; then
  echo "Artefatos esperados não encontrados:"
  echo "- $ZIP_PATH"
  echo "- $DMG_PATH"
  exit 1
fi

if [[ ! -f "$NOTES_PATH" ]]; then
  cat > "$NOTES_PATH" <<EOF
${RELEASE_NAME}

## Novidades
- Atualização ${TAG}

## Arquivos
- $(basename "$ZIP_PATH")
- $(basename "$DMG_PATH")

## Instalação (sem notarização Apple)
Este build é assinado localmente (ad-hoc), então o macOS pode exibir aviso de segurança na primeira abertura.

1. Arraste o app para /Applications
2. Clique com botão direito no app e escolha Open
3. Confirme em Open novamente

Alternativa: System Settings > Privacy & Security > Open Anyway

## Requisitos
- macOS 13+
- Apple Silicon (arm64)
EOF
fi

echo "==> [2/4] Criar tag ${TAG} (se necessário)"
if git rev-parse "${TAG}" >/dev/null 2>&1; then
  echo "Tag local já existe: ${TAG}"
else
  git tag -a "$TAG" -m "Release ${TAG}"
fi

echo "==> [3/4] Publicar tag no origin"
if git ls-remote --tags origin "refs/tags/${TAG}" | grep -q "refs/tags/${TAG}"; then
  echo "Tag remota já existe: ${TAG}"
else
  git push origin "$TAG"
fi

echo "==> [4/4] Criar/atualizar release e subir assets"
python3 scripts/publish_github_release.py \
  "$OWNER_REPO" \
  "$TAG" \
  --name "$RELEASE_NAME" \
  --body-file "$NOTES_PATH" \
  "$ZIP_PATH" \
  "$DMG_PATH"

echo
echo "Concluído: release ${TAG} publicada para ${OWNER_REPO}"
echo "Notas: $NOTES_PATH"

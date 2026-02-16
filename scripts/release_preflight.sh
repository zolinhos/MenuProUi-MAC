#!/usr/bin/env bash

set -euo pipefail

VERSION_INPUT="${1:-}"

if [[ -z "$VERSION_INPUT" ]]; then
  echo "Uso: bash scripts/release_preflight.sh <versao>"
  exit 1
fi

normalize_version() {
  local raw="$1"
  if [[ "$raw" == v* ]]; then
    echo "${raw#v}"
  else
    echo "$raw"
  fi
}

VERSION="$(normalize_version "$VERSION_INPUT")"

ok() {
  echo "[OK] $1"
}

warn() {
  echo "[WARN] $1"
}

fail() {
  echo "[ERRO] $1"
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "Comando obrigatório não encontrado: $1"
  fi
}

require_file() {
  if [[ ! -f "$1" ]]; then
    fail "Arquivo obrigatório não encontrado: $1"
  fi
}

echo "==> Preflight release ${VERSION}"

require_command git
require_command swift
require_command python3
require_command bash
ok "Dependências de comando"

require_file "Views/ContentView.swift"
require_file "README.md"
require_file "scripts/publish_github_release.py"
require_file "scripts/release_untrusted_macos.sh"
ok "Arquivos essenciais"

if grep -q 'keyboardShortcut("k", modifiers: \[\.command, \.shift\])' Views/ContentView.swift; then
  ok "Atalho ⇧⌘K presente no código"
else
  fail "Atalho ⇧⌘K não encontrado em Views/ContentView.swift"
fi

if grep -q '⇧⌘K' README.md; then
  ok "Atalho ⇧⌘K documentado no README"
else
  fail "Atalho ⇧⌘K não documentado no README"
fi

if grep -q 'Checar conectividade' Views/ContentView.swift && grep -q 'Todos os clientes' Views/ContentView.swift; then
  ok "Fluxo de escopo de conectividade presente"
else
  fail "Fluxo de escopo de conectividade não encontrado"
fi

echo "==> Build release de validação"
swift build -c release >/dev/null
ok "Build release"

dirty_tracked="$(git status --short | grep -E '^( M|M |MM|A |D |R )' | grep -vE '^ M (\.build/|dist/|\.DS_Store$)' || true)"
if [[ -n "$dirty_tracked" ]]; then
  warn "Há alterações rastreadas fora de .build/dist:"
  echo "$dirty_tracked"
else
  ok "Sem alterações rastreadas pendentes (fora .build/dist)"
fi

echo "==> Preflight concluído para ${VERSION}"

#!/usr/bin/env python3

import base64
import json
import subprocess
import sys
import urllib.request
from typing import Dict, List, Optional, Tuple


def run(command: List[str]) -> str:
    return subprocess.check_output(command, text=True).strip()


def get_git_credential() -> Tuple[str, str]:
    proc = subprocess.run(
        ["git", "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n",
        text=True,
        capture_output=True,
        check=True,
    )
    username = ""
    password = ""
    for line in proc.stdout.splitlines():
        if line.startswith("username="):
            username = line.split("=", 1)[1]
        elif line.startswith("password="):
            password = line.split("=", 1)[1]
    if not username or not password:
        raise RuntimeError("Credenciais GitHub não encontradas no git credential helper")
    return username, password


def github_request(url: str, user: str, token: str, method: str = "GET", payload: Optional[Dict] = None) -> Dict:
    body = None
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": "Basic " + base64.b64encode(f"{user}:{token}".encode()).decode(),
    }
    if payload is not None:
        body = json.dumps(payload).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    with urllib.request.urlopen(req) as res:
        return json.load(res)


def main() -> int:
    if len(sys.argv) != 3:
        print("Uso: update_release_body.py <owner/repo> <tag>")
        return 1

    owner_repo = sys.argv[1]
    tag = sys.argv[2]

    release_body = """MenuProUI-MAC 1.7.1

## Novidades
- Corrige persistência do nome do acesso ao editar
- Adiciona ação **Clonar** no menu de contexto dos acessos

## Arquivos
- `MenuProUI-MAC-app-macos-arm64-1.7.1.zip`
- `MenuProUI-MAC-macos-arm64-1.7.1.dmg`

## Instalação (sem notarização Apple)
Este build é assinado localmente (ad-hoc), então o macOS pode exibir aviso de segurança na primeira abertura.

### Opção 1 (recomendada para usuário comum)
1. Arraste o app para `/Applications`
2. Clique com botão direito no app e escolha **Open**
3. Confirme em **Open** novamente

### Opção 2 (via Ajustes do macOS)
1. Tente abrir o app normalmente
2. Abra **System Settings > Privacy & Security**
3. Em Security, clique **Open Anyway** para o app
4. Abra novamente e confirme

### Opção 3 (Terminal, usuário avançado)
```bash
xattr -dr com.apple.quarantine /Applications/MenuProUI-MAC.app
```

## Requisitos
- macOS 13+
- Apple Silicon (arm64)
"""

    user, token = get_git_credential()
    api = f"https://api.github.com/repos/{owner_repo}"
    release = github_request(f"{api}/releases/tags/{tag}", user, token)
    rel_id = release["id"]
    updated = github_request(
        f"{api}/releases/{rel_id}",
        user,
        token,
        method="PATCH",
        payload={"body": release_body},
    )
    print(updated.get("html_url", ""))
    print(f"updated_body_len {len(updated.get('body', ''))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

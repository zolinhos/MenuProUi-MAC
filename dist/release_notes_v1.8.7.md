# MenuProUI-MAC v1.8.7

## Novidade
- Adicionado novo tipo de acesso `MTK` (MikroTik / WinBox).

## O que foi implementado
- Cadastro, edição, exclusão e clonagem de acessos `MTK`.
- Integração do tipo `MTK` na grid/tabela de acessos, filtros e ações de contexto.
- Abertura de sessão via WinBox no macOS (`/Applications/WinBox.app`) com host, porta e usuário.
- Porta padrão de `MTK` definida como `8291`.
- Checagem de conectividade para `MTK` no fluxo TCP (mesma base de SSH/RDP).
- Parser de logs atualizado para reconhecer `TIPO=MTK`.

## Impacto
- Permite administrar roteadores MikroTik diretamente pelo fluxo do app, sem workaround manual.
- Mantém consistência de UX/telemetria entre SSH, RDP, URL e agora MTK.

## Arquivos
- `MenuProUI-MAC-app-macos-arm64-1.8.7.zip`
- `MenuProUI-MAC-macos-arm64-1.8.7.dmg`

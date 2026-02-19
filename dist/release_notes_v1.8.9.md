# MenuProUI-MAC v1.8.9

## Correções
- Corrigida a chamada do WinBox no macOS para evitar que a porta seja interpretada no campo de usuário.
- Ajustado fluxo de conectividade para `MTK` com prioridade em TCP direto (fallback `nc`), reduzindo falso `offline`.

## Impacto
- Abertura de sessão WinBox mais confiável para host/porta/usuário.
- Validação de conectividade MTK alinhada ao comportamento real da porta WinBox (`8291`).

## Arquivos
- `MenuProUI-MAC-app-macos-arm64-1.8.9.zip`
- `MenuProUI-MAC-macos-arm64-1.8.9.dmg`

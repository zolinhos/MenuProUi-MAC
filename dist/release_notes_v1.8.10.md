# MenuProUI-MAC v1.8.10

## Correções
- Corrigido falso `offline` em SSH/RDP quando `TCP` e `nmap` falham simultaneamente, mas o alvo está acessível.
- Adicionado fallback de confirmação via `nc` também no caminho de dupla falha (`nmap=false` e `tcp=false`).

## Impacto
- Redução de falsos negativos em rede local para acessos SSH/RDP.
- Resultado de conectividade mais aderente ao estado real do host/porta.

## Arquivos
- `MenuProUI-MAC-app-macos-arm64-1.8.10.zip`
- `MenuProUI-MAC-macos-arm64-1.8.10.dmg`

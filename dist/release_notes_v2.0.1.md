# MenuProUI-MAC v2.0.1

## Novidades principais
- Completa a revisão de internacionalização (PT/EN) em telas que ainda tinham textos fixos em português.
- Ajuste da tela principal: removido bloco de caminhos de arquivos da lateral, mantendo apenas a assinatura do produto.

## O que foi implementado
- Traduções PT/EN adicionadas/ajustadas em:
  - Help
  - Add/Edit Client
  - Add/Edit SSH
  - Add/Edit RDP
  - Add/Edit URL
  - Ajustes adicionais na ContentView (auditoria, preview/importação e rótulos de colunas)
- Padronização do uso de idioma com `@AppStorage("app.language")` e helper `t(...)` nas telas pendentes.
- Remoção dos caminhos `clientes.csv/acessos.csv/eventos.csv` da lateral esquerda da tela principal.

## Impacto
- Alternância de idioma mais consistente em toda a UI.
- Tela principal mais limpa, com informações técnicas concentradas na ajuda.

## Arquivos
- `MenuProUI-MAC-app-macos-arm64-2.0.1.zip`
- `MenuProUI-MAC-macos-arm64-2.0.1.dmg`

# MenuProUI-MAC v2.0.2

## Novidades principais
- Edição de acesso agora permite alterar o **tipo** no mesmo formulário (SSH, RDP, URL e MTK).

## O que foi implementado
- Fluxo de edição unificado com seletor de tipo no formulário de edição.
- Reaproveitamento do formulário de acesso com pré-carga dos dados existentes.
- Persistência ajustada para atualizar o mesmo registro ao trocar o tipo (mantendo o ID do acesso).
- Limpeza de cache de conectividade para refletir corretamente mudanças de host/porta/url e tipo.

## Impacto
- Mais agilidade para corrigir cadastro errado sem excluir e recriar acesso.
- Menor risco operacional por manter histórico e referência do mesmo item.

## Arquivos
- `MenuProUI-MAC-app-macos-arm64-2.0.2.zip`
- `MenuProUI-MAC-macos-arm64-2.0.2.dmg`

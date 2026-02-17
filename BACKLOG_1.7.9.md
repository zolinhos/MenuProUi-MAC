# Backlog — MenuProUI-MAC 1.7.9

Este arquivo acompanha a execução do backlog numerado (1–120). A versão 1.7.5 permanece congelada.

Legenda: [ ] pendente | [x] concluído | [~] parcial

## Conectividade / Orquestração
- [x] (20/21) Banner não-bloqueante para início/fim de varredura
- [x] (14/15) Progresso incremental (checados/total + barra)
- [x] (10) Cancelamento de varredura
- [x] (85) Checar conectividade de um único acesso (menu de contexto)
- [x] nmap-first para SSH/RDP quando disponível
- [x] TCP direto + fallback nmap para URL quando necessário
- [x] Diagnóstico em runtime do caminho do nmap
- [x] (1/2/8) Configurações: timeout, concorrência, cache e portas fallback URL
- [x] (8) Limite de concorrência aplicado na varredura
- [x] (59) Cache curto aplicado na varredura
- [x] (71/72/73) Colunas de conectividade (última checagem / método / latência)

## Segurança / Confiabilidade de dados
- [x] (95/96) Import com backup e rollback automático
- [x] (101) Rotação do `eventos.csv` por tamanho
- [x] (91/92) Export opcional com proteção contra CSV injection
- [x] (103) Integridade de auditoria com hash encadeado (arquivo `.chain`)
- [x] (108/109/110) Busca/filtros na auditoria (ação/entidade/termo)
- [x] (94) Import dry-run (prévia/relatório) antes de aplicar
- [x] (95) Restaurar último backup via Configurações
- [x] (93/97/99/100) Validação mais rígida no import (bloqueia erros e faz rollback)

## Versão / Release
- [x] Defaults de scripts e checklist apontando para 1.7.9
- [x] Notas de release iniciais: dist/release_notes_v1.7.9.md

## Backlog completo (1–120)
> O backlog completo está no histórico da conversa; este arquivo será expandido para conter os 120 itens com status conforme avançarmos.

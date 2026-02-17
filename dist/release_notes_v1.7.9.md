Versão MenuProUI-MAC 1.7.9

## Objetivo
- Evolução grande de confiabilidade/UX/segurança operacional (sem alterar a release 1.7.5)

## Novidades (em andamento)
- Varredura de conectividade com progresso incremental, cancelamento, e checagem por acesso
- Estratégia de conectividade mais rápida (nmap-first para SSH/RDP quando disponível; fallback inteligente para URL)
- Diagnóstico em runtime do caminho detectado do `nmap`
- Tela de Configurações para ajustar timeout, concorrência, cache e portas fallback de URL
- Limite de concorrência configurável para manter varredura rápida sem sobrecarregar a rede
- Cache curto configurável para evitar varreduras repetidas em sequência
- Importação com backup automático e rollback em caso de falha
- Rotação automática do `eventos.csv` por tamanho (evita crescimento infinito)
- Export opcional com proteção contra CSV injection (ajustável nas Configurações)
- Auditoria com verificação de integridade (hash encadeado) do `eventos.csv`
- Viewer de auditoria com busca e filtros por ação/entidade

## Notas
- A versão 1.7.5 permanece congelada; toda evolução a partir daqui é direcionada para 1.7.9.

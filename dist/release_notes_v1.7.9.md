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
- Importação com prévia (dry-run) e confirmação antes de aplicar
- Configurações: restauração do último backup (clientes/acessos/eventos)
- Grid de acessos: exibe última checagem, método (TCP/nmap) e latência (ms)
- Importação com validação mais rígida: bloqueia dados inválidos (IDs duplicados, tipo desconhecido, porta inválida) e faz rollback automático
- Grid de acessos: filtro por status de conectividade (online/offline/checando/não checado) e ordenação por status
- Varredura otimizada: deduplicação por endpoint (host/porta) para evitar checagens repetidas e acelerar listas grandes
- Cache de conectividade por endpoint (reaproveita resultados entre acessos duplicados)
- Checagem rápida: botão "Checar Selecionado" + auto-checagem opcional ao selecionar acesso (configurável)
- Configurações: botões "Revalidar nmap" e "Testar nmap agora" (feedback visual)
- Varredura: exibe % + ETA aproximado + horário início/fim + duração
- Diagnóstico: diferencia DNS/timeout/recusada/host indisponível/porta fechada e mostra detalhe na grid
- Grid: nova coluna "Erro" para último motivo do offline
- Auditoria: botões rápidos para filtrar por cliente/acesso selecionado
- URL: preserva query/fragmento e normaliza portas inválidas; "Testar URL" no diálogo de cadastro/edição com resultado no próprio diálogo
- UX: mensagens de erro/info passaram a usar banner (toast) não-bloqueante no topo

## Notas
- A versão 1.7.5 permanece congelada; toda evolução a partir daqui é direcionada para 1.7.9.

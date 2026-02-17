# Backlog — MenuProUI-MAC 1.7.9

Este arquivo acompanha a execução do backlog numerado (1–120). A versão 1.7.5 permanece congelada.

Legenda: [ ] pendente | [x] concluído | [~] parcial (implementado em parte / falta acabamento)

Este arquivo foi expandido para conter a lista completa fornecida na conversa (fev/2026), com o status verificado no código atual.

## Configurações / Conectividade (geral)
- [x] Criar tela de Configurações (geral).
- [x] Permitir configurar timeout global de conectividade.
- [ ] Permitir timeout por tipo (SSH/RDP/URL).
- [x] Permitir configurar portas fallback de URL.
- [x] Exibir caminho do nmap nas Configurações.
- [x] Botão “Revalidar nmap” sem reiniciar app.
- [x] Botão “Testar nmap agora” com resultado visual.
- [x] Permitir definir número máximo de checks paralelos.

## Varredura / Orquestração
- [ ] Implementar fila de varredura com prioridade.
- [x] Botão “Cancelar varredura em andamento”.
- [ ] Suporte a múltiplas varreduras em fila.
- [x] Evitar varredura duplicada no mesmo host/porta.
- [x] Debounce de clique no botão “Checar Conectividade”.

## Progresso / Telemetria de varredura (UI)
- [x] Mostrar progresso (%) da varredura.
- [x] Mostrar contador “checados/total”.
- [x] Mostrar tempo estimado restante.
- [x] Exibir hora de início da varredura.
- [x] Exibir hora de fim da varredura.
- [x] Exibir duração total da varredura.
- [x] Notificação não-bloqueante ao concluir varredura.
- [x] Trocar alertas modais por toast/banner informativo.

## Erros / Diagnóstico (conectividade)
- [x] Notificação de erro com causa técnica resumida.
- [x] Diferenciar erro DNS, timeout, conexão recusada.
- [x] Diferenciar “porta fechada” de “host indisponível”.
- [x] Diferenciar “nmap ausente” de “nmap falhou”.

## Logs (conectividade)
- [x] Registrar motivo detalhado por falha no log.
- [x] Incluir “origem da checagem” (cliente/todos) no log.
- [x] Incluir duração por host no log de conectividade.
- [x] Incluir ferramenta usada (TCP/nmap) no log.
- [x] Incluir porta efetiva usada no log.

## URL — validação/normalização
- [x] Validar URL robustamente (esquema/host/porta/path).
- [x] Corrigir input http:ip automaticamente.
- [x] Corrigir input sem esquema para http://.
- [ ] Validar IPv4 estrito.
- [ ] Validar IPv6 estrito.
- [x] Suportar hostname local (intranet.local).
- [x] Suportar URL com query string.
- [x] Suportar URL com fragmento.
- [x] Preservar maiúsculas/minúsculas no path.
- [x] Normalizar esquema para lowercase.
- [x] Normalizar portas inválidas para padrão por esquema.
- [x] Tratar porta zero como inválida.
- [x] Tratar porta >65535 como inválida.
- [ ] Avisar quando URL aponta para localhost.
- [ ] Avisar quando URL contém caractere inválido.
- [ ] Pré-visualizar URL final antes de salvar.

## URL — Teste no diálogo (cadastro/edição)
- [ ] Botão “Testar URL” no diálogo de cadastro.
- [ ] Botão “Testar URL” no diálogo de edição.
- [ ] Mostrar resultado do teste no próprio diálogo.
- [ ] Salvar última URL testada no contexto da sessão.

## Perfis/Modes de checagem
- [ ] Criar modo “checagem rápida” (menos tentativas).
- [ ] Criar modo “checagem completa” (mais portas/retries).
- [ ] Criar perfil “Operação” e “Diagnóstico”.
- [x] Definir estratégia nmap por tipo de acesso.
- [x] SSH/RDP sempre nmap quando disponível (já iniciado).
- [x] URL com TCP primeiro e nmap fallback (já iniciado).
- [ ] Permitir forçar “somente nmap” para URL.
- [ ] Permitir forçar “somente TCP” para URL.

## Cache / Invalidação / Tuning
- [x] Cache curto de resultado para evitar repetição imediata.
- [ ] Invalidar cache ao editar acesso.
- [ ] Invalidar cache ao mudar timeout/configuração.
- [ ] Incluir jitter entre checks para reduzir pico.
- [ ] Limitar concorrência por cliente.
- [ ] Limitar concorrência por sub-rede.
- [ ] Detectar rede local lenta e reduzir agressividade.
- [ ] Detectar rede rápida e aumentar concorrência.
- [ ] Definir portas nmap por esquema customizáveis.
- [ ] Permitir lista de portas por cliente.
- [ ] Permitir lista de portas por acesso.

## Grid / Colunas / Filtros
- [ ] Exibir “porta testada” na coluna de status.
- [x] Adicionar coluna “Última checagem”.
- [x] Adicionar coluna “Latência”.
- [x] Adicionar coluna “Método” (TCP/nmap).
- [x] Adicionar coluna “Detalhe de erro”.
- [x] Ordenar acessos por estado de conectividade.
- [x] Filtrar por estado (online/offline/checando).
- [ ] Filtrar por “checado nas últimas X horas”.
- [ ] Destacar offline críticos visualmente.
- [x] Indicador de varredura global no topo da tela.
- [ ] Badge no cliente com “x/y online”.

## Atalhos / Context Menu / Abertura
- [ ] Atalho para abrir painel de conectividade.
- [ ] Atalho para cancelar varredura.
- [ ] Atalho para repetir última varredura.
- [ ] Atalho para alternar modo rápido/completo.
- [x] Context menu: “Checar somente este acesso”.
- [x] Context menu: “Checar cliente deste acesso”.
- [ ] Context menu: “Copiar diagnóstico”.
- [ ] Context menu: “Abrir no navegador/cliente” mantendo foco.
- [ ] Duplo clique com debounce para evitar abertura dupla.
- [x] Clique Enter em linha também abre (confirmar consistência).

## CSV — export/import e segurança operacional
- [x] Fortalecer sanitização de CSV contra fórmulas (=,+,-,@).
- [x] Escapar campos potencialmente perigosos no export.
- [x] Validar schema CSV no import antes de aplicar.
- [x] Dry-run de import com relatório de inconsistências.
- [x] Backup automático antes de import.
- [x] Rollback automático se import falhar no meio.
- [x] Tratar duplicidade de IDs no import.
- [x] Tratar aliases duplicados por cliente.
- [ ] Tratar normalização de encoding UTF-8 BOM.
- [ ] Validar datas inválidas no histórico.

## Auditoria (eventos.csv)
- [x] Rotacionar eventos.csv por tamanho.
- [ ] Rotacionar eventos.csv por período (ex.: 90 dias).
- [x] Hash encadeado de eventos para integridade.
- [ ] Registrar versão do app em cada evento.
- [ ] Registrar usuário/sessão no evento (quando aplicável).
- [ ] Export de auditoria em CSV filtrado por período.
- [ ] Export de auditoria em JSON para integrações.
- [x] Busca textual na auditoria dentro do app.
- [x] Filtro de auditoria por ação.
- [x] Filtro de auditoria por cliente/acesso.

## Testes / CI / Release
- [ ] Criar suíte de testes de parser de URL.
- [ ] Criar suíte de testes de normalização de porta.
- [ ] Criar suíte de testes de fallback nmap/TCP.
- [ ] Criar suíte de testes para import/export CSV.
- [ ] Criar testes para logs de auditoria.
- [ ] Criar teste de regressão para duplo clique abrir.
- [ ] Criar teste de regressão para busca global.
- [ ] Pipeline CI com build + testes automáticos.
- [x] Pipeline release com validação de assets/notas/tag.
- [ ] Checklist operacional “pré-release” automatizado no CI.

## Itens já entregues (referência rápida)
- [x] nmap-first para SSH/RDP quando disponível
- [x] TCP direto + fallback nmap para URL quando necessário
- [x] Diagnóstico em runtime do caminho do nmap
- [x] Deduplicação por endpoint na varredura (evita probes repetidos)
- [x] Cache por endpoint (além do cache por ID) para reaproveitar checagens entre acessos duplicados
- [x] Checar acesso selecionado (botão) + auto-checar ao selecionar (opcional)
- [x] Import com backup e rollback automático
- [x] Export opcional com proteção contra CSV injection
- [x] Integridade de auditoria com hash encadeado (arquivo `.chain`)
- [x] Busca/filtros na auditoria (ação/entidade/termo)
- [x] Defaults de scripts e checklist apontando para 1.7.9
- [x] Notas de release iniciais: dist/release_notes_v1.7.9.md

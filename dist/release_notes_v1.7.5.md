Versão MenuProUI-MAC 1.7.5

## Novidades
- Paridade de schema com WIN no `acessos.csv`: `IsFavorite`, `OpenCount`, `LastOpenedAt`
- Log de auditoria padrão WIN em `eventos.csv` (`TimestampUtc,Action,EntityType,EntityName,Details`)
- Registro de ações principais: `create`, `edit`, `delete`, `clone`, `favorite`, `open`, `import`, `export`, `check_connectivity`, `help_opened`, `refresh`, `new_access_dialog_opened`, `delete_confirmed`, `delete_cancelled`
- Favoritos de acesso com persistência em CSV, botão rápido no painel principal e ação no menu de contexto
- Importação/Exportação por UI para `clientes.csv`, `acessos.csv` e `eventos.csv` (eventos opcional no import)
- Busca geral e filtros locais em conjunto (cliente + acessos)
- Visualização de auditoria no app (atalho `⌥⌘J`) com últimos acessos e eventos gerais
- URLs agora preservam protocolo real (`http`/`https`) no cadastro, edição, persistência e abertura
- URLs ampliadas para aceitar esquema flexível (`http`, `https`, `ftp` e similares), inclusive entrada sem esquema (fallback `http`)
- Checagem de conectividade para URL aprimorada para extrair host/porta da URL completa com fallback por esquema
- Duplo clique na linha do acesso para abrir diretamente
- Terminologia da interface/documentação ajustada de "HTTPS" para "URL"
- Importação/Exportação mantidos como atalhos (`⇧⌘B` / `⇧⌘I`) e ajustes no menu de contexto (clientes/acessos)
- Busca global corrigida para trazer acessos de todos os clientes (incluindo host, alias, usuário, URL, porta, tags, observações e cliente)
- Exportação com confirmação de sobrescrita quando arquivos CSV já existem no destino
- Visualização de auditoria ajustada para carregar eventos de forma robusta
- Painel principal simplificado com remoção do gráfico de conexões

## Atalhos (paridade com WIN)
- `⌘R` atualizar dados
- `⌘K` foco busca global
- `⌘F` foco busca clientes
- `⇧⌘F` foco busca acessos
- `⌘L` limpar buscas
- `⌘N` novo cliente
- `⇧⌘N` novo acesso
- `⇧⌘D` clonar acesso
- `⇧⌘K` checar conectividade
- `⇧⌘B` exportar CSVs
- `⌥⌘J` abrir auditoria de eventos
- `↩︎` abrir acesso selecionado
- `⌘E` editar acesso selecionado
- `⌫` excluir acesso selecionado
- `⌘/` ou `F1` abrir ajuda

## Arquivos
- MenuProUI-MAC-app-macos-arm64-1.7.5.zip
- MenuProUI-MAC-macos-arm64-1.7.5.dmg

## Instalação (sem notarização Apple)
Este build é assinado localmente (ad-hoc), então o macOS pode exibir aviso de segurança na primeira abertura.

1. Arraste o app para /Applications
2. Clique com botão direito no app e escolha Open
3. Confirme em Open novamente

Alternativa: System Settings > Privacy & Security > Open Anyway

## Requisitos
- macOS 13+
- Apple Silicon (arm64)

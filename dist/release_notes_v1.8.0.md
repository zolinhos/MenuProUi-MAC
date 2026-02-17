# MenuProUI-MAC v1.8.0

## Melhorias

- **Validação em tempo real** nos diálogos de edição (Cliente, SSH, RDP, URL) — botão Salvar desabilitado até preencher campos obrigatórios
- **Notes multi-linha** (TextEditor) nos diálogos EditRDP e EditURL, consistente com os diálogos de cadastro
- **Frame mínimo** nos diálogos EditClient, EditRDP e EditURL para melhor usabilidade
- **Atalho ⌘.** para Favoritar/Desfavoritar acesso selecionado
- **Ordenação por status** corrigida: online primeiro, offline por último
- **Seleção de acesso** corrigida: clique simples 100% nativo do List, duplo clique via NSEvent monitor (sem interferência)

## Conectividade

- **Resolução DNS antecipada** agora aplica para SSH/RDP além de URL — hosts locais (.local, mDNS) se beneficiam
- **Fallback nc (netcat)** adicionado para SSH/RDP quando nmap não está instalado
- **Cadeia de fallback tripla** completa para todos os tipos: TCP → nmap → nc

## Código

- Código morto removido: `URLLauncher.openURL(raw:)`, `openHTTPS()`, `CSVStore.logHelpOpen()`
- `DateFormatter` estático em ContentView (performance)
- Dois blocos `.onAppear` consolidados
- Conflito de `@SceneStorage` entre AddURLView e EditURLView corrigido
- Comentários em português brasileiro em todos os arquivos
- README atualizado com documentação completa

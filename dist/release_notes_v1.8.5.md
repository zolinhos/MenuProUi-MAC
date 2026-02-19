# MenuProUI-MAC v1.8.5

## Correções
- Corrigido falso positivo de conectividade para URL quando `curl` retorna timeout (`exit 28`) e apenas `nc/tcp` indicam porta aberta.
- Agora endpoints sem resposta HTTP/HTTPS efetiva são marcados como `offline` nesse cenário.

## Melhoria de interface
- Adicionada barra fixa de status no rodapé da aplicação.
- A barra agora centraliza mensagens de checagem de conectividade e outros avisos operacionais.
- Durante varredura, a barra mostra o progresso em tempo real; fora da varredura, permite limpar a mensagem atual.
- Grid de acessos migrada para `Table` no macOS, permitindo ordenação por qualquer coluna clicando no cabeçalho.
- Colunas da grid agora podem ser redimensionadas a qualquer momento pelo usuário.
- Ordenação inicial da grid ajustada para `Status` (online/checking/unknown/offline) e, em empate, `Alias`.

## Impacto
- Reduz marcações indevidas de `online` em hosts que aceitam conexão TCP mas não respondem na aplicação.
- Caso validado: `192.168.200.1`.

## Arquivos
- `MenuProUI-MAC-app-macos-arm64-1.8.5.zip`
- `MenuProUI-MAC-macos-arm64-1.8.5.dmg`

Versão MenuProUI-MAC 1.7.10

## Objetivo
- Consolida as melhorias grandes da trilha 1.7.x (UX + conectividade + confiabilidade)

## Novidades
- Configurações (engrenagem) reestruturada: layout correto na sheet + explicação detalhada de cada campo
- Varredura de conectividade: progresso, % + ETA aproximado, cancelamento, início/fim/duração
- Diagnóstico: detalhe de erro (DNS/timeout/recusada/host indisponível/porta fechada) + coluna "Erro" na grid
- nmap: detecção em runtime + botões "Revalidar" e "Testar agora" nas Configurações
- URL: validação/normalização melhorada (inclui query/fragmento) + botão "Testar URL" nos diálogos (cadastro/edição)
- Import: prévia (dry-run) + backup/rollback; validação mais rígida (inclui conflito de alias por cliente/tipo)
- Auditoria: integridade por hash chain + viewer com busca/filtros e atalhos de filtro por cliente/acesso
- UX: mensagens de erro/info usando banner (toast) não-bloqueante

## Arquivos
- `MenuProUI-MAC-app-macos-arm64-1.7.10.zip`
- `MenuProUI-MAC-macos-arm64-1.7.10.dmg`

## Instalação (sem notarização Apple)
Este build é assinado localmente (ad-hoc), então o macOS pode exibir aviso de segurança na primeira abertura.

1. Arraste o app para `/Applications`
2. Clique com botão direito no app e escolha **Open**
3. Confirme em **Open** novamente

Alternativa: **System Settings > Privacy & Security > Open Anyway**

## Requisitos
- macOS 13+
- Apple Silicon (arm64)

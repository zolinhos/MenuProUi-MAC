# MenuProUI-MAC v1.8.1

## Correção

- Corrigida regressão na checagem de conectividade com `nmap`.
- A estratégia agora tenta primeiro sem `-Pn` e, quando o host discovery falha (`host seems down` / `0 hosts up`), faz retry automático com `-Pn`.
- Redução de falsos offline em redes que bloqueiam ICMP/descoberta de host.

## Técnico

- Ajuste em `Services/ConnectivityChecker.swift` na função `checkWithNmapDetailed(...)`.
- Saída de diagnóstico consolidada entre tentativa padrão e retry com `-Pn`.

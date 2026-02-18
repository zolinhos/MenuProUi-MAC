# MenuProUI-MAC v1.8.3

## Correções de conectividade

- Logging de conectividade ampliado: agora cada endpoint checado é registrado (incluindo URL online por TCP), para facilitar auditoria de casos como `192.168.200.1`.
- URL com validação mais rígida: quando TCP reporta online, o app confirma com `nc`; se houver divergência, tenta confirmar com `nmap` antes de concluir.
- Mantida a proteção de falso positivo em resultados `nmap` com confirmação TCP.

## Observação de diagnóstico

- Nos eventos anteriores, o item RDP checado era `192.168.0.1:3389`.
- Os itens `192.168.200.1` estavam como URLs e antes podiam não aparecer no log quando online por TCP.

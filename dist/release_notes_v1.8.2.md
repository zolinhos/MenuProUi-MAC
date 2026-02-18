# MenuProUI-MAC v1.8.2

## Correções

- Endurecida a validação de conectividade para evitar falso positivo de `online` via `nmap`.
- Quando `nmap` indica porta aberta, o app agora confirma com uma conexão TCP real antes de marcar como online.
- Se o TCP falhar, o resultado final passa para offline com diagnóstico explícito no log.

## Observação

- Nos logs enviados, o target checado foi `192.168.0.1` (não `192.168.200.1`).

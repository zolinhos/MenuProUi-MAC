# MenuProUI-MAC v1.8.4

## Conectividade (regra 2+1)

- Validação de UP por múltiplos métodos:
  - URL/HTTP: `TCP` + `HTTP (curl)`
  - SSH/RDP: `nmap` + `TCP`
- Se houver divergência (um positivo e outro negativo), agora executa 3º método para desempate (`nc` e, quando necessário, `nmap`).
- Resultado final passa a ser por consenso (votação), reduzindo falso positivo de "verde".

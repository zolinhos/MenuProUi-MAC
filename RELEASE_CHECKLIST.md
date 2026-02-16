# Release Checklist — MenuProUI-MAC v1.3

## 1) Validação local
- [ ] Rodar app e testar atalhos principais (`Enter`, `⌘N`, `⇧⌘N`, `⌘R`, `⌘E`, `⌫`, `⌘/`)
- [ ] Confirmar abertura de SSH, RDP e URL
- [ ] Verificar ajuda com caminhos de `clientes.csv` e `acessos.csv`

## 2) Build e artefatos
- [x] Build release: `swift build -c release`
- [x] App gerado: `dist/MenuProUI-MAC.app`
- [x] Zip gerado: `dist/MenuProUI-MAC-app-macos-arm64-v1.3.zip`
- [x] Dmg gerado: `dist/MenuProUI-MAC-macos-arm64-v1.3.dmg`

## 3) Assinatura
- [x] Assinar ad-hoc: `codesign --force --deep --sign - dist/MenuProUI-MAC.app`
- [x] Verificar assinatura: `codesign --verify --deep --strict --verbose=2 dist/MenuProUI-MAC.app`

## 4) Publicação no GitHub
- [ ] Criar tag `v1.3`
- [ ] Criar release "MenuProUI-MAC v1.3"
- [ ] Anexar `.zip` e `.dmg`
- [ ] Incluir changelog curto (atalhos, help, melhorias de empacotamento)

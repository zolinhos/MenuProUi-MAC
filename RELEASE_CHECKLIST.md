# Release Checklist — MenuProUI-MAC

> Este checklist agora é validado automaticamente por `scripts/release_preflight.sh`
> e é executado antes do publish em `scripts/release_publish_untrusted.sh`.

## 1) Validação local
- [ ] Rodar app e testar atalhos principais (`Enter`, `⌘N`, `⇧⌘N`, `⌘R`, `⌘E`, `⌫`, `⌘/`)
- [ ] Confirmar abertura de SSH, RDP e URL
- [ ] Verificar ajuda com caminhos de `clientes.csv` e `acessos.csv`

## 2) Build e artefatos
- [x] Build release: `swift build -c release`
- [x] App gerado: `dist/MenuProUI-MAC.app`
- [ ] Zip gerado: `dist/MenuProUI-MAC-app-macos-arm64-1.7.10.zip`
- [ ] Dmg gerado: `dist/MenuProUI-MAC-macos-arm64-1.7.10.dmg`

## 3) Assinatura e notarização (distribuição)
- [ ] Copiar ambiente: `cp .env.release.example .env.release`
- [ ] Criar profile notary: `bash scripts/setup_notary_profile.sh notary-profile`
- [ ] Definir certificado: `DEV_ID_APP_CERT="Developer ID Application: Seu Nome (TEAMID)"`
- [ ] Definir autenticação notarização (`NOTARY_PROFILE` ou `AC_USERNAME` + `AC_PASSWORD` + `AC_TEAM_ID`)
- [ ] Rodar script: `bash scripts/release_notarized_macos.sh 1.7.10`
- [ ] Validar Gatekeeper app: `spctl --assess --type execute -vvv dist/MenuProUI-MAC.app`
- [ ] Validar Gatekeeper dmg: `spctl --assess --type open -vvv dist/MenuProUI-MAC-macos-arm64-1.7.10.dmg`

## 4) Publicação no GitHub
- [ ] Criar tag `v1.7.10`
- [ ] Criar release "MenuProUI-MAC 1.7.10"
- [ ] Anexar `.zip` e `.dmg`
- [ ] Incluir changelog curto (atalhos, help, melhorias de empacotamento)

## 5) Alternativa sem Apple Developer (sem notarização)
- [ ] Rodar: `bash scripts/release_untrusted_macos.sh 1.7.10`
- [ ] Avisar usuários: primeira abertura precisa de `Open Anyway` ou clique direito `Open`

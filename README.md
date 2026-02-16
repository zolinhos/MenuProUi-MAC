# MenuProUI-MAC

Aplicativo **macOS** (SwiftUI) para centralizar, organizar e abrir acessos de infraestrutura por **cliente**, suportando:

- **SSH** (host, usuário e **porta digitável**)
- **RDP** (host, usuário/domínio e **porta digitável**, com geração de `.rdp`)
- **HTTPS (URL)** para consoles web (Firewall, VMware, etc.), com **porta padrão 443** e suporte a portas customizadas

Os dados são persistidos localmente em arquivos **CSV** em `~/.config/MenuProUI/`.

---

## ✅ Principais recursos

### Clientes
- Cadastrar cliente (ID, Nome, Tags)
- Editar cliente
- Apagar cliente (com opção de **cascata**, removendo acessos vinculados)

### Acessos por cliente
- **SSH**
  - Cadastrar (alias, nome, host, **porta**, usuário, tags)
  - Abrir com 1 clique
  - Editar, clonar e apagar
- **RDP**
  - Cadastrar (alias, nome, host, **porta**, domínio opcional, usuário, tags)
  - Abrir com 1 clique (gera `.rdp`)
  - Editar, clonar e apagar
  - Porta customizada gravada corretamente via `server port:i:PORT`
- **HTTPS**
  - Cadastrar URL completa (ex.: `https://firewall.voceconfia.com.br:4444`)
  - Porta padrão **443** caso não seja informada
  - Abrir no navegador padrão
  - Editar, clonar e apagar

### Saúde de conectividade (manual)
- Botão **Checar Conectividade** por cliente (sem auto-refresh)
- Status por acesso:
  - 🟢 online
  - 🔴 offline
  - 🟡 checando
  - ⚪ não checado
- Indicador agregado no cliente (sidebar)

### Interface
- Tema escuro (azul/preto)
- Lista de clientes na lateral (NavigationSplitView)
- Ações rápidas (Adicionar / Abrir / Checar conectividade / Editar / Apagar)
- (Opcional) gráficos/estatísticas se `LogParser` estiver ativo

---

## 🧩 Tecnologias

- SwiftUI
- Combine (para `ObservableObject` / `@Published`)
- Charts (para gráfico, quando habilitado)
- AppKit (via `NSWorkspace` para abrir SSH/HTTPS e `.rdp`)

---

## ✅ Requisitos

- macOS 13+
- Xcode 15+ (recomendado)
- Swift 6.0+ (compatível com `swift-tools-version: 6.0`)
- Command Line Tools do Xcode instalados

### Verificação rápida do ambiente

```bash
sw_vers
xcodebuild -version
swift --version
xcode-select -p
```

Se `xcode-select -p` falhar, rode:

```bash
xcode-select --install
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

### Dependências de execução (após compilar)

- SSH: app handler configurado no macOS (`ssh://`)
- RDP: cliente RDP instalado (ex.: Microsoft Remote Desktop)
- HTTPS: navegador padrão

---

## 🚀 Como rodar (desenvolvimento)

1. Clone o repositório:

   ```bash
   git clone <URL_DO_REPO>
   cd <PASTA_DO_REPO>
   ```

2. (Opcional) Limpe build anterior:

  ```bash
  rm -rf .build
  ```

3. Build via SwiftPM:

  ```bash
  swift build
  ```

4. Rodar local:

  ```bash
  swift run
  ```

5. Opcional (Xcode):
  - `File` → `Open...` e abra a pasta do projeto
  - Execute com `Run` (⌘R)

### Build release local (sem empacotar)

```bash
swift build -c release
```

### Erros comuns ao compilar local

- `toolchain is invalid` / `missing SDK`: selecione o Xcode correto com `xcode-select -s`
- `permission denied` em scripts: rode `chmod +x scripts/*.sh`
- erro de assinatura ao distribuir: use o fluxo `scripts/release_untrusted_macos.sh` (sem notarização) ou configure Developer ID/notary

---

## ⌨️ Atalhos de teclado

Atalhos úteis implementados na interface:

- `⌘R` → Atualizar dados
- `⌘N` → Novo Cliente
- `⇧⌘N` → Novo Acesso
- `↩︎` → Abrir acesso selecionado
- `⌘E` → Editar acesso selecionado
- `⌫` → Excluir acesso selecionado
- `⌘/` → Abrir Ajuda
- No diálogo **Novo acesso**:
  - `⌘1` → Cadastrar SSH
  - `⌘2` → Cadastrar RDP
  - `⌘3` → Cadastrar URL
  - `Esc` → Cancelar

---

## 🗂 Persistência de dados (CSV)

O app cria e mantém os arquivos em:

```
~/.config/MenuProUI/
```

Arquivos criados:

- `clientes.csv`
- `acessos.csv`
- `rdpfiles/` (pasta para arquivos `.rdp` gerados)

> Importante: o CSV é **simples** (split por vírgula). Evite vírgulas dentro dos campos.

---

## 📄 Formatos dos arquivos

### 1) `clientes.csv`

Header:
```
Id,Nome,Observacoes,CriadoEm,AtualizadoEm
```

Exemplo:
```
scma,Santa Casa,,2026-02-14 12:00:00,2026-02-14 12:00:00
```

---

### 2) `acessos.csv`

Header:
```
Id,ClientId,Tipo,Apelido,Nome,Host,Porta,Usuario,Dominio,RdpIgnoreCert,RdpFullScreen,RdpDynamicResolution,RdpWidth,RdpHeight,Url,Observacoes,CriadoEm,AtualizadoEm
```

Exemplo SSH:
```
uuid-1,scma,SSH,scma-ssh01,Servidor Linux 01,10.0.0.10,2222,root,,,,,,, ,Acesso Linux,2026-02-14 12:00:00,2026-02-14 12:00:00
```

Exemplo URL:
```
uuid-2,scma,URL,fw-web01,Firewall Web,firewall.voceconfia.com.br,4444,,,,,,,/,,2026-02-14 12:01:00,2026-02-14 12:01:00
```

---

## 🔗 Como a ação “Abrir” funciona

### SSH
O app abre uma URL do tipo:

```
ssh://usuario@host:porta
```

O macOS encaminha para o handler padrão configurado (Terminal/iTerm/cliente SSH).  
➡️ Isso evita permissões extras e automações.

---

### RDP
O app gera um arquivo `.rdp` em:

```
~/.config/MenuProUI/rdpfiles/
```

E abre automaticamente com o app padrão de RDP do macOS (ex.: Microsoft Remote Desktop).

Inclui a porta via:

```
server port:i:PORT
```

---

### HTTPS
O app abre no navegador padrão:

```
https://host:porta/path
```

---

## 🎨 Ícone do app (AppIcon) — macOS

O macOS exige múltiplos tamanhos no `AppIcon.appiconset`.

Tamanhos comuns:

- 16×16 (1x)
- 32×32 (2x de 16)
- 32×32 (1x)
- 64×64 (2x de 32)
- 128×128 (1x)
- 256×256 (2x de 128)
- 256×256 (1x)
- 512×512 (2x de 256)
- 512×512 (1x)
- 1024×1024 (2x de 512)

### Onde configurar
No Xcode:
- `Assets.xcassets` → `AppIcon`

### Erro clássico
Se aparecer algo como:

> `logo.png is 1024x1024 but should be 16x16`

Significa que um PNG grande foi colocado em slot pequeno.  
Substitua pelo tamanho correto em cada slot.

---

## 📦 Build de distribuição (app/zip/dmg)

Comandos base:

```bash
swift build -c release
```

O empacotamento pode gerar:

- `dist/MenuProUI-MAC.app`
- `dist/MenuProUI-MAC-app-macos-arm64-YYYY-MM-DD.zip`
- `dist/MenuProUI-MAC-macos-arm64-YYYY-MM-DD.dmg`

Assinatura local ad-hoc (opcional):

```bash
codesign --force --deep --sign - dist/MenuProUI-MAC.app
```

Validação:

```bash
codesign --verify --deep --strict --verbose=2 dist/MenuProUI-MAC.app
```

### Distribuição recomendada (Developer ID + Notarização)

Para enviar para outros Macs sem bloqueio do Gatekeeper:

```bash
cp .env.release.example .env.release
chmod +x scripts/*.sh

# 1) Importar certificado Developer ID Application (.p12)
bash scripts/import_developer_id_cert.sh ~/Downloads/developer_id_application.p12 "SENHA_DO_P12"

# 2) Criar profile do notarytool
bash scripts/setup_notary_profile.sh notary-profile

# 3) Validar assinador/notary antes da release
bash scripts/check_signing_setup.sh

# 4) Gerar release notarizada
export DEV_ID_APP_CERT="Developer ID Application: Seu Nome (TEAMID)"
export NOTARY_PROFILE="notary-profile"
bash scripts/release_notarized_macos.sh 1.7.1
```

Validação final:

```bash
spctl --assess --type execute -vvv dist/MenuProUI-MAC.app
spctl --assess --type open -vvv dist/MenuProUI-MAC-macos-arm64-1.7.1.dmg
```

> Observação: os artefatos atuais são `arm64` (Apple Silicon). Em Mac Intel, é necessário gerar build `x86_64` ou universal.

### Distribuição sem pagar Apple Developer (não notarizado)

Se você não quer pagar o programa da Apple, pode distribuir com assinatura ad-hoc/local:

```bash
bash scripts/release_untrusted_macos.sh 1.7.1
```

Isso gera ZIP/DMG, mas no Mac de quem receber pode aparecer bloqueio na primeira abertura.

No Mac de destino:

- Clique direito no app → Open
- Ou: Privacy & Security → Open Anyway

---

## 🛠 Troubleshooting

### 1) `Expressions are not allowed at the top level`
Você tem Views/chamadas soltas fora de um `struct View`.

✅ Correção:
Garanta que `Image(...)`, `Text(...)`, `.frame(...)` etc. estejam dentro de:

```swift
struct ContentView: View {
    var body: some View {
        // Views aqui
    }
}
```

---

### 2) `Result of call to 'frame(...)' is unused`
Normalmente aparece quando `.frame(...)` está “solto”, não encadeado com uma View.

✅ Exemplo correto:

```swift
Image("logo")
  .resizable()
  .frame(width: 40, height: 40)
```

---

### 3) `Picker: the selection "" is invalid...`
A seleção atual não corresponde a nenhum `.tag(...)` existente.

✅ Correção recomendada:
- Selecione clientes por **ID** (String) e use `.tag(...)` coerente com o tipo da seleção.

---

## 🧭 Estrutura do projeto (visão geral)

Arquivos típicos:

- `Views/ContentView.swift`  
  UI principal: lista de clientes, busca e lista unificada de acessos.

- `Models/Models.swift`  
  Modelos: `Client`, `SSHServer`, `RDPServer`, `URLAccess`.

- `Services/CSVStore.swift`  
  Persistência: leitura, escrita e CRUD dos CSVs em `~/.config/MenuProUI/`.

- `Services/SSHLauncher.swift`  
  Abre SSH via `ssh://...` usando `NSWorkspace`.

- `Services/RDPFileWriter.swift`  
  Gera `.rdp` (com porta custom) e abre via `NSWorkspace`.

- `Services/URLLauncher.swift`  
  Abre URLs HTTPS via `NSWorkspace`.

- `Dialogs/Add*.swift` / `Dialogs/Edit*.swift`  
  Telas de cadastro e edição.

---

## 🔒 Segurança

- O app **não armazena senhas**
- Os dados ficam em `~/.config/MenuProUI/` no seu usuário do macOS
- Recomenda-se proteger o dispositivo e o usuário com senha/Touch ID

---

## 🗺 Roadmap

- Export/Import via UI
- Busca em tempo real para clientes e acessos
- Favoritos
- Validação visual de host/porta/URL
- Criptografia opcional do storage local
- Sync opcional (ex.: iCloud Drive), se desejado

---

## 🤝 Contribuindo

1. Faça um fork
2. Crie uma branch:

   ```bash
   git checkout -b feature/minha-melhoria
   ```

3. Commit:

   ```bash
   git commit -m "feat: minha melhoria"
   ```

4. Push:

   ```bash
   git push origin feature/minha-melhoria
   ```

5. Abra um Pull Request

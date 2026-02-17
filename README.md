# MenuProUI-MAC

Aplicativo **macOS** (SwiftUI) para centralizar, organizar e abrir acessos de infraestrutura por **cliente**, suportando:

- **SSH** (host, usuário e **porta digitável**)
- **RDP** (host, usuário/domínio e **porta digitável**, com geração de `.rdp`)
- **URL (HTTP/HTTPS/FTP)** para consoles web (Firewall, VMware, etc.), com suporte a portas customizadas

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
  - Editar, clonar, favoritar e apagar
- **RDP**
  - Cadastrar (alias, nome, host, **porta**, domínio opcional, usuário, tags)
  - Abrir com 1 clique (gera `.rdp`)
  - Editar, clonar, favoritar e apagar
  - Porta customizada gravada corretamente via `server port:i:PORT`
- **URL (HTTP/HTTPS/FTP)**
  - Cadastrar URL completa (ex.: `http://firewall.voceconfia.com.br:4444`)
  - Porta padrão por protocolo: `80` (HTTP), `443` (HTTPS), `21` (FTP)
  - Abrir no navegador padrão
  - Editar, clonar, favoritar e apagar
  - Validação de URL em tempo real nos diálogos de cadastro e edição

### Importação/Exportação
- Exportar `clientes.csv`, `acessos.csv` e `eventos.csv` por atalho (`⇧⌘B`)
- Importar `clientes.csv` + `acessos.csv` (com `eventos.csv` opcional) por atalho (`⇧⌘I`)

### Auditoria de eventos (padrão WIN)
- Geração de `eventos.csv` com header `TimestampUtc,Action,EntityType,EntityName,Details`
- Registro de ações: `create`, `edit`, `delete`, `clone`, `favorite`, `open`, `import`, `export`, `check_connectivity`, `help_opened`, `refresh`, `new_access_dialog_opened`, `delete_confirmed`, `delete_cancelled`
- Atalho para abrir auditoria no app: `⌥⌘J`

### Saúde de conectividade (manual)
- Botão **Checar Conectividade** por cliente (sem auto-refresh)
- A varredura roda em background: você pode continuar abrindo/editando acessos durante o processo
- Ao finalizar a varredura, o app exibe um aviso em tela com resumo online/offline
- **Cadeia de fallback tripla** para sondas de porta:
  1. **NWConnection (TCP nativo)** — probe principal via Network.framework
  2. **nmap/nping** — fallback para portas que falham via TCP nativo (ex.: rotas link-local com `bind(0.0.0.0:0)` EINVAL no macOS)
  3. **nc (netcat)** — fallback terciário quando nmap não está instalado
- Para acessos URL, a checagem testa host/porta TCP da URL (com porta explícita ou padrão por esquema: `http` 80, `https` 443, `ftp` 21)
- Para SSH/RDP, o app usa o probe mais adequado disponível
- Para URL, se a checagem TCP direta falhar e `nmap` estiver instalado no macOS, o app faz fallback de varredura de portas web comuns (`443`, `80`, `8443`, `8080`, `9443`)
- Se `nmap` não estiver instalado, o app tenta `nc` (netcat) como fallback terciário
- URLs sem endpoint TCP válido (ex.: caminhos locais/formatos não resolvíveis) podem retornar offline, mesmo abrindo no navegador
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
- Duplo clique na linha de acesso para abrir diretamente
- Validação de formulário em tempo real em todos os diálogos (Add e Edit)
- Observações (Notes) com campo multi-linha nos diálogos RDP e URL
- Código-fonte documentado com comentários em português brasileiro

---

## 🧩 Tecnologias

- SwiftUI
- Combine (para `ObservableObject` / `@Published`)
- AppKit (via `NSWorkspace` para abrir SSH/URL e `.rdp`)

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
- URL (HTTP/HTTPS): navegador padrão

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
- `⌘K` → Focar busca global
- `⌘F` → Focar busca de clientes
- `⇧⌘F` → Focar busca de acessos
- `⌘L` → Limpar buscas
- `⌘N` → Novo Cliente
- `⇧⌘N` → Novo Acesso
- `⇧⌘D` → Clonar acesso selecionado
- `⇧⌘K` → Checar conectividade
- `⇧⌘B` → Exportar CSVs
- `⇧⌘I` → Importar CSVs
- `⌥⌘J` → Exibir log de eventos/últimos acessos
- `↩︎` → Abrir acesso selecionado
- `⌘E` → Editar acesso selecionado
- `⌫` → Excluir acesso selecionado
- `⌘/` ou `F1` → Abrir Ajuda
- `⌘.` → Favoritar/Desfavoritar acesso selecionado
- Favoritar/Desfavoritar → botão dedicado e menu de contexto
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



```

Id,ClientId,Tipo,Apelido,Host,Porta,Usuario,Dominio,RdpIgnoreCert,RdpFullScreen,RdpDynamicResolution,RdpWidth,RdpHeight,Url,Observacoes,IsFavorite,OpenCount,LastOpenedAt,CriadoEm,AtualizadoEm


Exemplo SSH:

```

uuid-1,scma,SSH,scma-ssh01,10.0.0.10,2222,root,,True,False,True,,,,Acesso Linux,True,3,02/17/2026 02:01:44,02/17/2026 00:56:19,02/17/2026 00:56:19
```

Exemplo URL:

```

uuid-2,scma,URL,fw-web01,,,,,True,False,True,,,http://192.168.0.10:4444,,False,1,02/17/2026 01:40:43,02/17/2026 01:40:10,02/17/2026 01:40:40


---

### 3) `eventos.csv`

Header:
```
TimestampUtc,Action,EntityType,EntityName,Details
```

Exemplo:
```
02/17/2026 01:51:22,create,client,teste 2 incluir,Cliente criado
02/17/2026 02:10:00,clone,access,clone rdp,Clonado de Novo Acesso; Tipo=RDP
02/17/2026 02:10:03,favorite,access,clone rdp,Favoritado
02/17/2026 02:10:10,open,access,clone rdp,Acesso aberto; Tipo=RDP
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

### URL
O app abre no navegador padrão, preservando o esquema informado (`http`, `https`, `ftp` e outros):

```
esquema://host:porta/path
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
bash scripts/release_notarized_macos.sh 1.8.0
```

O fluxo notarizado também executa automaticamente o preflight checklist (`scripts/release_preflight.sh`) antes de iniciar o empacotamento/notarização.

Validação final:

```bash
spctl --assess --type execute -vvv dist/MenuProUI-MAC.app
spctl --assess --type open -vvv dist/MenuProUI-MAC-macos-arm64-1.8.0.dmg
```

> Observação: os artefatos atuais são `arm64` (Apple Silicon). Em Mac Intel, é necessário gerar build `x86_64` ou universal.

### Distribuição sem pagar Apple Developer (não notarizado)

Se você não quer pagar o programa da Apple, pode distribuir com assinatura ad-hoc/local:

```bash
bash scripts/release_untrusted_macos.sh 1.8.0
```

### Publicar release em 1 comando (tag + GitHub + upload)

Para facilitar próximas versões, use o orquestrador abaixo:

```bash
bash scripts/release_publish_untrusted.sh 1.8.0
```

Antes de empacotar/publicar, o script executa automaticamente um **preflight checklist**:

- valida comandos obrigatórios
- valida arquivos essenciais
- valida presença do atalho `⇧⌘K` no código e no README
- valida presença do fluxo de escopo de conectividade
- roda build release de validação

Ele executa automaticamente:

- build/empacotamento (`zip` e `dmg`)
- criação da tag (`v<versão>`) se não existir
- push da tag
- criação/atualização da release no GitHub e upload dos assets

Se precisar informar manualmente o repositório:

```bash
bash scripts/release_publish_untrusted.sh 1.8.0 zolinhos/MenuProUi-MAC
```

As notas da release são lidas de `dist/release_notes_v<versão>.md`.
Se o arquivo não existir, o script cria um template automaticamente.

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

- `Services/ConnectivityChecker.swift`  
  Checagem de conectividade com cadeia de fallback tripla: NWConnection → nmap → nc.

- `Services/LogParser.swift`  
  Parser de eventos de log para gráfico de conexões por dia.

- `Services/URLLauncher.swift`  
  Abre URLs com esquema configurável via `NSWorkspace`.

- `Dialogs/Add*.swift` / `Dialogs/Edit*.swift`  
  Telas de cadastro e edição.

---

## 🔒 Segurança

- O app **não armazena senhas**
- Os dados ficam em `~/.config/MenuProUI/` no seu usuário do macOS
- Recomenda-se proteger o dispositivo e o usuário com senha/Touch ID

---

## 🗺 Roadmap

- Criptografia opcional do storage local
- Sync opcional (ex.: iCloud Drive), se desejado
- Suporte a Jump Server (SSH ProxyJump)
- Tema claro opcional

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

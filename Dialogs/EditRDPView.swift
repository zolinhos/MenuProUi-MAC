import SwiftUI

// MARK: - Editar RDP
/// Diálogo para edição de um acesso RDP existente.
/// Valida que alias, nome, host e usuário não fiquem vazios antes de permitir salvar.
/// Porta, largura e altura são editadas como texto e convertidas em Int ao salvar.
struct EditRDPView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app.language") private var appLanguageRaw = AppLanguage.pt.rawValue

    /// Servidor RDP sendo editado (cópia local mutável).
    @State var item: RDPServer

    /// Callback executado ao salvar com sucesso.
    let onSave: (RDPServer) -> Void

    /// Porta, largura e altura como texto para digitação livre.
    @State private var portText: String
    @State private var widthText: String
    @State private var heightText: String
    private var appLanguage: AppLanguage { .from(appLanguageRaw) }
    private func t(_ pt: String, _ en: String) -> String { I18n.text(pt, en, language: appLanguage) }

    init(item: RDPServer, onSave: @escaping (RDPServer) -> Void) {
        self._item = State(initialValue: item)
        self.onSave = onSave
        self._portText = State(initialValue: "\(item.port)")
        self._widthText = State(initialValue: item.width.map(String.init) ?? "")
        self._heightText = State(initialValue: item.height.map(String.init) ?? "")
    }

    /// Validação: alias, nome, host e usuário obrigatórios.
    private var isFormValid: Bool {
        !item.alias.trimmed.isEmpty &&
        !item.name.trimmed.isEmpty &&
        !item.host.trimmed.isEmpty &&
        !item.user.trimmed.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("Editar RDP", "Edit RDP")).font(.title2).bold()

            Form {
                TextField(t("Alias", "Alias"), text: $item.alias)
                // ClientId — somente leitura
                Text("\(t("Cliente", "Client")): \(item.clientId)").foregroundStyle(.secondary)

                TextField(t("Nome", "Name"), text: $item.name)
                TextField(t("Host/IP", "Host/IP"), text: $item.host)
                TextField(t("Porta", "Port"), text: $portText)
                TextField(t("Domínio", "Domain"), text: $item.domain)
                TextField(t("Usuário", "User"), text: $item.user)
                TextField(t("Tags", "Tags"), text: $item.tags)

                // Opções RDP
                Toggle(t("Ignorar certificado", "Ignore certificate"), isOn: $item.ignoreCert)
                Toggle(t("Tela cheia", "Full screen"), isOn: $item.fullScreen)
                Toggle(t("Resolução dinâmica", "Dynamic resolution"), isOn: $item.dynamicResolution)
                TextField(t("Largura", "Width"), text: $widthText)
                    .disabled(item.dynamicResolution)
                TextField(t("Altura", "Height"), text: $heightText)
                    .disabled(item.dynamicResolution)

                // Observações — campo multi-linha (consistente com AddRDPView)
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("Observações", "Notes"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $item.notes)
                        .frame(minHeight: 90)
                }
            }

            HStack {
                Button(t("Cancelar", "Cancel")) { dismiss() }
                Spacer()
                Button(t("Salvar", "Save")) {
                    item.port = Int(portText.trimmed) ?? item.port
                    item.width = item.dynamicResolution ? nil : Int(widthText.trimmed)
                    item.height = item.dynamicResolution ? nil : Int(heightText.trimmed)
                    onSave(item)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
            }
        }
        .padding()
        .frame(minWidth: 760, minHeight: 620)
        .preferredColorScheme(.dark)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

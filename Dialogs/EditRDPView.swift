import SwiftUI

// MARK: - Editar RDP
/// Diálogo para edição de um acesso RDP existente.
/// Valida que alias, nome, host e usuário não fiquem vazios antes de permitir salvar.
/// Porta, largura e altura são editadas como texto e convertidas em Int ao salvar.
struct EditRDPView: View {
    @Environment(\.dismiss) private var dismiss

    /// Servidor RDP sendo editado (cópia local mutável).
    @State var item: RDPServer

    /// Callback executado ao salvar com sucesso.
    let onSave: (RDPServer) -> Void

    /// Porta, largura e altura como texto para digitação livre.
    @State private var portText: String
    @State private var widthText: String
    @State private var heightText: String

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
            Text("Editar RDP").font(.title2).bold()

            Form {
                TextField("Alias", text: $item.alias)
                // ClientId — somente leitura
                Text("Cliente: \(item.clientId)").foregroundStyle(.secondary)

                TextField("Nome", text: $item.name)
                TextField("Host/IP", text: $item.host)
                TextField("Porta", text: $portText)
                TextField("Domínio", text: $item.domain)
                TextField("Usuário", text: $item.user)
                TextField("Tags", text: $item.tags)

                // Opções RDP
                Toggle("Ignorar certificado", isOn: $item.ignoreCert)
                Toggle("Tela cheia", isOn: $item.fullScreen)
                Toggle("Resolução dinâmica", isOn: $item.dynamicResolution)
                TextField("Largura", text: $widthText)
                    .disabled(item.dynamicResolution)
                TextField("Altura", text: $heightText)
                    .disabled(item.dynamicResolution)

                // Observações — campo multi-linha (consistente com AddRDPView)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Observações")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $item.notes)
                        .frame(minHeight: 90)
                }
            }

            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Salvar") {
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

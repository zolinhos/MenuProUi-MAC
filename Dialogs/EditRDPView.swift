import SwiftUI

struct EditRDPView: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: RDPServer
    let onSave: (RDPServer) -> Void

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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Editar RDP").font(.title2).bold()

            Form {
                Text("Alias: \(item.alias)").foregroundStyle(.secondary)
                Text("Cliente: \(item.clientId)").foregroundStyle(.secondary)

                TextField("Nome", text: $item.name)
                TextField("Host/IP", text: $item.host)
                TextField("Porta", text: $portText)
                TextField("Domínio", text: $item.domain)
                TextField("Usuário", text: $item.user)
                TextField("Tags", text: $item.tags)
                Toggle("Ignorar certificado", isOn: $item.ignoreCert)
                Toggle("Tela cheia", isOn: $item.fullScreen)
                Toggle("Resolução dinâmica", isOn: $item.dynamicResolution)
                TextField("Largura", text: $widthText)
                    .disabled(item.dynamicResolution)
                TextField("Altura", text: $heightText)
                    .disabled(item.dynamicResolution)
                TextField("Observações", text: $item.notes)
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
            }
        }
        .padding()
        .preferredColorScheme(.dark)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

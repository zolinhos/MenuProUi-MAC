import SwiftUI

struct EditMTKView: View {
    @Environment(\.dismiss) private var dismiss

    @State var item: MTKAccess
    let onSave: (MTKAccess) -> Void
    @State private var portText: String

    init(item: MTKAccess, onSave: @escaping (MTKAccess) -> Void) {
        self._item = State(initialValue: item)
        self.onSave = onSave
        self._portText = State(initialValue: "\(item.port)")
    }

    private var isFormValid: Bool {
        !item.alias.trimmed.isEmpty &&
        !item.name.trimmed.isEmpty &&
        !item.host.trimmed.isEmpty &&
        !item.user.trimmed.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Editar MTK (WinBox)").font(.title2).bold()

            Form {
                TextField("Alias", text: $item.alias)
                Text("Cliente: \(item.clientId)").foregroundStyle(.secondary)

                TextField("Nome", text: $item.name)
                TextField("Host/IP", text: $item.host)
                TextField("Porta", text: $portText)
                TextField("Usuário", text: $item.user)
                TextField("Tags", text: $item.tags)

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
                    onSave(item)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
            }
        }
        .padding()
        .frame(minWidth: 760, minHeight: 520)
        .preferredColorScheme(.dark)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

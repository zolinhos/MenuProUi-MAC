import SwiftUI

struct EditClientView: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: Client
    let onSave: (Client) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Editar Cliente").font(.title2).bold()

            Form {
                Text("ID: \(item.id)").foregroundStyle(.secondary)
                TextField("Nome", text: $item.name)
                TextField("Tags", text: $item.tags)
                TextField("Observações", text: $item.notes)
            }

            HStack {
                Button("Cancelar") { dismiss() }
                Spacer()
                Button("Salvar") { onSave(item); dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .preferredColorScheme(.dark)
    }
}

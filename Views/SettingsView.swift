import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let latestBackupName: String
    let onRestoreLatestBackup: () -> Void

    @AppStorage("connectivity.timeoutSeconds") private var timeoutSeconds: Double = 3.0
    @AppStorage("connectivity.maxConcurrency") private var maxConcurrency: Int = 12
    @AppStorage("connectivity.cacheTTLSeconds") private var cacheTTLSeconds: Double = 10.0
    @AppStorage("connectivity.urlFallbackPorts") private var urlFallbackPortsCSV: String = "443,80,8443,8080,9443"
    @AppStorage("connectivity.autoCheckOnSelect") private var autoCheckOnSelect = false
    @AppStorage("connectivity.autoCheckDebounceMs") private var autoCheckDebounceMs: Int = 800
    @AppStorage("export.formulaProtection") private var exportFormulaProtection = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Configurações")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Fechar") { dismiss() }
            }

            Form {
                Section("Conectividade") {
                    HStack {
                        Text("Timeout (s)")
                        Spacer()
                        TextField("Timeout", value: $timeoutSeconds, format: .number)
                            .frame(width: 100)
                    }

                    HStack {
                        Text("Concorrência")
                        Spacer()
                        TextField("Concorrência", value: $maxConcurrency, format: .number)
                            .frame(width: 100)
                    }

                    HStack {
                        Text("Cache (s)")
                        Spacer()
                        TextField("Cache", value: $cacheTTLSeconds, format: .number)
                            .frame(width: 100)
                    }

                    Toggle("Auto-checar ao selecionar acesso", isOn: $autoCheckOnSelect)

                    HStack {
                        Text("Debounce (ms)")
                        Spacer()
                        TextField("Debounce", value: $autoCheckDebounceMs, format: .number)
                            .frame(width: 100)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Portas fallback URL (CSV)")
                        TextField("443,80,8443...", text: $urlFallbackPortsCSV)
                        Text("Usado quando URL falha no TCP direto e o nmap estiver disponível.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("nmap")
                            .font(.headline)
                        Text("Detectado: \(ConnectivityChecker.nmapPathDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Exportação") {
                    Toggle("Proteção contra CSV injection", isOn: $exportFormulaProtection)
                    Text("Quando habilitado, o export pode prefixar campos perigosos (ex.: iniciando com '=' '+' '-' '@') para reduzir risco ao abrir no Excel.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Backups") {
                    Text("Último backup: \(latestBackupName.isEmpty ? "(nenhum)" : latestBackupName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Restaurar último backup") {
                        onRestoreLatestBackup()
                    }
                    .disabled(latestBackupName.isEmpty)
                }

                Section {
                    Text("Dica: valores muito agressivos podem causar falsos offline em redes lentas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(minWidth: 640, minHeight: 440)
        .preferredColorScheme(.dark)
        .onChange(of: timeoutSeconds) { v in
            timeoutSeconds = max(0.5, min(v, 60.0))
        }
        .onChange(of: maxConcurrency) { v in
            maxConcurrency = max(1, min(v, 128))
        }
        .onChange(of: cacheTTLSeconds) { v in
            cacheTTLSeconds = max(0, min(v, 3600))
        }
        .onChange(of: autoCheckDebounceMs) { v in
            autoCheckDebounceMs = max(0, min(v, 10_000))
        }
    }
}

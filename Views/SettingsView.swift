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

    @State private var nmapRefreshToken = UUID()
    @State private var nmapTestRunning = false
    @State private var nmapTestResult: ConnectivityChecker.NmapTestResult?

    var body: some View {
        NavigationStack {
            Form {
                Section("Conectividade") {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Timeout (s)") {
                            TextField("Timeout", value: $timeoutSeconds, format: .number)
                                .frame(width: 120)
                                .monospacedDigit()
                        }
                        Text("Tempo máximo por tentativa de checagem (TCP e/ou nmap). Padrão: 3s. Intervalo: 0,5–60s. Em redes lentas, use 5–10s.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Concorrência") {
                            TextField("Concorrência", value: $maxConcurrency, format: .number)
                                .frame(width: 120)
                                .monospacedDigit()
                        }
                        Text("Número máximo de checagens paralelas durante a varredura. Padrão: 12. Intervalo: 1–128. Valores altos aceleram, mas podem gerar falsos offline e pico na rede.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Cache (s)") {
                            TextField("Cache", value: $cacheTTLSeconds, format: .number)
                                .frame(width: 120)
                                .monospacedDigit()
                        }
                        Text("Reaproveita resultados recentes para não repetir checagens em sequência. Padrão: 10s. 0 desliga o cache.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Auto-checar ao selecionar acesso", isOn: $autoCheckOnSelect)
                        Text("Quando ligado, ao selecionar um acesso a checagem roda automaticamente (se não houver varredura em andamento).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Debounce (ms)") {
                            TextField("Debounce", value: $autoCheckDebounceMs, format: .number)
                                .frame(width: 120)
                                .monospacedDigit()
                        }
                        Text("Atraso antes do auto-check disparar, para evitar checar enquanto você só está navegando na lista. Padrão: 800ms. Intervalo: 0–10.000ms.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Portas fallback URL (CSV)")
                            .font(.headline)
                        TextField("443,80,8443...", text: $urlFallbackPortsCSV)
                            .textFieldStyle(.roundedBorder)
                        Text("Lista de portas para o nmap testar quando a URL falha no TCP direto. Padrão: 443,80,8443,8080,9443. Use CSV com números (1–65535).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("nmap")
                            .font(.headline)
                        Text("Detectado: \(ConnectivityChecker.nmapPathDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("SSH/RDP usam nmap primeiro quando disponível; URL tenta TCP primeiro e usa nmap como fallback.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            Button("Revalidar nmap") {
                                nmapRefreshToken = UUID()
                            }
                            .buttonStyle(.bordered)

                            Button(nmapTestRunning ? "Testando..." : "Testar nmap agora") {
                                guard !nmapTestRunning else { return }
                                nmapTestRunning = true
                                nmapTestResult = nil
                                Task(priority: .utility) {
                                    let result = await ConnectivityChecker.testNmapNow(timeoutSeconds: 2.0)
                                    await MainActor.run {
                                        nmapTestResult = result
                                        nmapTestRunning = false
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(nmapTestRunning)
                        }

                        if let nmapTestResult {
                            Text(nmapTestResult.message)
                                .font(.caption)
                                .foregroundStyle(nmapTestResult.ok ? .green : .red)
                        }
                    }
                    .id(nmapRefreshToken)
                }

                Section("Exportação") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Proteção contra CSV injection", isOn: $exportFormulaProtection)
                        Text("Quando habilitado, o export pode prefixar campos perigosos (ex.: iniciando com '=' '+' '-' '@') para reduzir risco ao abrir no Excel/Sheets.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section("Backups") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Último backup: \(latestBackupName.isEmpty ? "(nenhum)" : latestBackupName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Restaura clientes.csv, acessos.csv e eventos.csv do snapshot mais recente criado antes de uma importação.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Restaurar último backup") {
                            onRestoreLatestBackup()
                        }
                        .disabled(latestBackupName.isEmpty)
                    }
                }

                Section {
                    Text("Dica: se sua rede for instável, aumente Timeout e diminua Concorrência para reduzir falsos offline.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .navigationTitle("Configurações")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        .frame(minWidth: 920, minHeight: 720)
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

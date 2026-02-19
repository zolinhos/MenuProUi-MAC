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
    @AppStorage("app.language") private var appLanguageRaw = AppLanguage.pt.rawValue

    @State private var nmapRefreshToken = UUID()
    @State private var nmapTestRunning = false
    @State private var nmapTestResult: ConnectivityChecker.NmapTestResult?

    private var appLanguage: AppLanguage { .from(appLanguageRaw) }
    private func t(_ pt: String, _ en: String) -> String { I18n.text(pt, en, language: appLanguage) }

    var body: some View {
        NavigationStack {
            Form {
                Section(t("Idioma", "Language")) {
                    Picker(t("Idioma do app", "App language"), selection: $appLanguageRaw) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang.rawValue)
                        }
                    }
                }

                Section(t("Conectividade", "Connectivity")) {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent(t("Timeout (s)", "Timeout (s)")) {
                            TextField(t("Timeout", "Timeout"), value: $timeoutSeconds, format: .number)
                                .frame(width: 120)
                                .monospacedDigit()
                        }
                        Text(t("Tempo máximo por tentativa de checagem (TCP e/ou nmap). Padrão: 3s. Intervalo: 0,5–60s. Em redes lentas, use 5–10s.", "Maximum time per connectivity attempt (TCP and/or nmap). Default: 3s. Range: 0.5–60s. On slow networks, use 5–10s."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent(t("Concorrência", "Concurrency")) {
                            TextField(t("Concorrência", "Concurrency"), value: $maxConcurrency, format: .number)
                                .frame(width: 120)
                                .monospacedDigit()
                        }
                        Text(t("Número máximo de checagens paralelas durante a varredura. Padrão: 12. Intervalo: 1–128. Valores altos aceleram, mas podem gerar falsos offline e pico na rede.", "Maximum number of parallel checks during scan. Default: 12. Range: 1–128. Higher values are faster but may cause false offline and network spikes."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent(t("Cache (s)", "Cache (s)")) {
                            TextField(t("Cache", "Cache"), value: $cacheTTLSeconds, format: .number)
                                .frame(width: 120)
                                .monospacedDigit()
                        }
                        Text(t("Reaproveita resultados recentes para não repetir checagens em sequência. Padrão: 10s. 0 desliga o cache.", "Reuse recent results to avoid repeated checks. Default: 10s. Set 0 to disable cache."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(t("Auto-checar ao selecionar acesso", "Auto-check on access selection"), isOn: $autoCheckOnSelect)
                        Text(t("Quando ligado, ao selecionar um acesso a checagem roda automaticamente (se não houver varredura em andamento).", "When enabled, selecting an access triggers connectivity check automatically (if no scan is running)."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent(t("Debounce (ms)", "Debounce (ms)")) {
                            TextField(t("Debounce", "Debounce"), value: $autoCheckDebounceMs, format: .number)
                                .frame(width: 120)
                                .monospacedDigit()
                        }
                        Text(t("Atraso antes do auto-check disparar, para evitar checar enquanto você só está navegando na lista. Padrão: 800ms. Intervalo: 0–10.000ms.", "Delay before auto-check starts, to avoid checks while navigating the list. Default: 800ms. Range: 0–10,000ms."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(t("Portas fallback URL (CSV)", "URL fallback ports (CSV)"))
                            .font(.headline)
                        TextField(t("443,80,8443...", "443,80,8443..."), text: $urlFallbackPortsCSV)
                            .textFieldStyle(.roundedBorder)
                        Text(t("Lista de portas para o nmap testar quando a URL falha no TCP direto. Padrão: 443,80,8443,8080,9443. Use CSV com números (1–65535).", "List of ports for nmap to test when URL direct TCP fails. Default: 443,80,8443,8080,9443. Use CSV numbers (1–65535)."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("nmap")
                            .font(.headline)
                        Text("\(t("Detectado", "Detected")): \(ConnectivityChecker.nmapPathDescription)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(t("SSH/RDP usam nmap primeiro quando disponível; URL tenta TCP primeiro e usa nmap como fallback.", "SSH/RDP use nmap first when available; URL tries TCP first and uses nmap as fallback."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 10) {
                            Button(t("Revalidar nmap", "Refresh nmap")) {
                                nmapRefreshToken = UUID()
                            }
                            .buttonStyle(.bordered)

                            Button(nmapTestRunning ? t("Testando...", "Testing...") : t("Testar nmap agora", "Test nmap now")) {
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

                Section(t("Exportação", "Export")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(t("Proteção contra CSV injection", "CSV injection protection"), isOn: $exportFormulaProtection)
                        Text(t("Quando habilitado, o export pode prefixar campos perigosos (ex.: iniciando com '=' '+' '-' '@') para reduzir risco ao abrir no Excel/Sheets.", "When enabled, export may prefix dangerous fields (starting with '=' '+' '-' '@') to reduce risk when opening in Excel/Sheets."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section(t("Backups", "Backups")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(t("Último backup", "Latest backup")): \(latestBackupName.isEmpty ? t("(nenhum)", "(none)") : latestBackupName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(t("Restaura clientes.csv, acessos.csv e eventos.csv do snapshot mais recente criado antes de uma importação.", "Restore clientes.csv, acessos.csv and eventos.csv from the latest snapshot created before an import."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(t("Restaurar último backup", "Restore latest backup")) {
                            onRestoreLatestBackup()
                        }
                        .disabled(latestBackupName.isEmpty)
                    }
                }

                Section {
                    Text(t("Dica: se sua rede for instável, aumente Timeout e diminua Concorrência para reduzir falsos offline.", "Tip: if your network is unstable, increase Timeout and reduce Concurrency to reduce false offline."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    Text(t("Desenvolvido por Solutions", "Developed by Solutions"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(t("Configurações", "Settings"))
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(t("Fechar", "Close")) { dismiss() }
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

import SwiftUI
import UIKit

struct MonitoringStatusView: View {
    @ObservedObject var controller: ScreenTimeController
    var detailed = false
    @State private var copied = false

    private var title: String {
        if !controller.isAuthorized { return "Bildschirmzeit-Berechtigung fehlt" }
        if !controller.state.monitoringEnabled { return "Messung noch nicht aktiviert" }
        if controller.isCheckingMonitor { return "Messung wird geprüft …" }
        if !controller.monitorReady { return "Messung braucht Aufmerksamkeit" }
        return "Minutenschritte eingerichtet"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title).font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
                if controller.isCheckingMonitor { ProgressView().controlSize(.small) }
            }
            if let date = controller.state.lastUsageUpdate {
                Text("Neue Nutzung zuletzt bestätigt: \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Noch keine Nutzungsminute von iOS bestätigt.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let date = controller.lastMonitorCheckAt {
                Text("Monitor geprüft: \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if let issue = controller.monitorIssue {
                Text(issue).font(.caption).foregroundStyle(.secondary)
            } else if controller.usageConfirmationIsOld {
                Text("Noch keine neuere Nutzungsbestätigung. Wenn du deine ausgewählten Apps seitdem weitergenutzt hast, verbinde die Messung erneut. Ohne weitere Nutzung ist dieser Stand normal.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if detailed || controller.usageConfirmationIsOld || !controller.monitorReady {
                Button("Messung neu verbinden") { controller.reconnectMonitoring() }
                    .buttonStyle(GateButtonStyle(prominent: false))
                    .disabled(controller.isCheckingMonitor || !controller.isAuthorized || !controller.state.monitoringEnabled)
            }
            if detailed {
                Text("Gate prüft die eingerichtete Messung beim Öffnen und bei geöffneter App ungefähr jede Minute. Neue Nutzungsminuten meldet iOS auch im Hintergrund; diese Meldungen können verspätet eintreffen.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Vergleiche nur die gespeicherten Konsum-Apps und Websites auf diesem iPhone. Telefon, WhatsApp und andere nicht ausgewählte Apps gehören nicht zu diesem Zeitkonto. Neu verbinden setzt weder Verbrauch noch Sperren zurück.")
                    .font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Messdiagnose") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(controller.monitoringDiagnostics).font(.caption2.monospaced()).textSelection(.enabled)
                        Button(copied ? "Diagnose kopiert" : "Diagnose kopieren") {
                            UIPasteboard.general.string = controller.monitoringDiagnostics
                            copied = true
                        }.font(.footnote)
                    }.padding(.top, 10)
                }.font(.footnote)
            }
        }
    }
}

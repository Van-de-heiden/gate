import FamilyControls
import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: ScreenTimeController
    @State private var isPickerPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    statusStrip

                    if let grant = controller.activeGrant {
                        grantCard(grant)
                    } else if controller.pendingTarget != nil {
                        LessonView(controller: controller)
                    } else {
                        setupCard
                    }

                    if let message = controller.message {
                        notice(message, color: .green)
                    }
                    if let error = controller.errorMessage {
                        notice(error, color: .red)
                    }

                    principles
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $controller.selection)
        .onAppear {
            controller.refreshSharedState()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GATE")
                .font(.system(size: 38, weight: .semibold, design: .serif))
                .tracking(5)
            Text("Konsum wird verdient. Fokus bleibt frei.")
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundColor(.secondary)
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 0) {
            statusItem(title: "SCHUTZ", value: controller.isAuthorized ? "AKTIV" : "OFFEN")
            Divider().frame(height: 38)
            statusItem(title: "GATE", value: controller.isMonitoring ? "LÄUFT" : "PAUSE")
            Divider().frame(height: 38)
            statusItem(
                title: "FREI",
                value: "\(GateConstants.dailyFreeMinutes) MIN"
            )
        }
        .padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statusItem(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption2.weight(.medium))
                .tracking(1.2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Technischer Probelauf")
                    .font(.title2.weight(.semibold))
                Text(GateConstants.isDebugAllowance
                     ? "Debug nutzt zwei Minuten statt der späteren freien Stunde."
                     : "Die erste Stunde des gewählten Konsumpools bleibt frei.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            step(number: "01", title: "Bildschirmzeit erlauben", detail: authorizationDetail) {
                Task { await controller.requestAuthorization() }
            } buttonTitle: {
                controller.isAuthorized ? "Erteilt" : "Zugriff erteilen"
            } disabled: {
                controller.isAuthorized || controller.isRequestingAuthorization
            }

            Divider()

            step(number: "02", title: "Konsum auswählen", detail: controller.selectionSummary) {
                isPickerPresented = true
            } buttonTitle: {
                controller.hasSelection ? "Auswahl ändern" : "Apps & Websites wählen"
            } disabled: {
                !controller.isAuthorized
            }

            Text("Wähle einzelne Konsum-Apps und Domains. Telefon, WhatsApp, Karten, Kalender und Lernwerkzeuge bleiben unmarkiert.")
                .font(.footnote)
                .foregroundColor(.secondary)

            Divider()

            HStack(spacing: 12) {
                Button(controller.isMonitoring ? "Gate neu starten" : "Gate starten") {
                    controller.startGate()
                }
                .buttonStyle(GatePrimaryButtonStyle())
                .disabled(!controller.isAuthorized || !controller.hasSelection)

                if controller.isMonitoring {
                    Button("Anhalten") {
                        controller.stopGate()
                    }
                    .buttonStyle(GateSecondaryButtonStyle())
                }
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var authorizationDetail: String {
        if controller.isAuthorized { return "Family Controls ist freigegeben." }
        if controller.authorizationStatus == .denied { return "In den Einstellungen abgelehnt." }
        return "Gate benötigt Apples Family-Controls-Freigabe."
    }

    private func step(
        number: String,
        title: String,
        detail: String,
        action: @escaping () -> Void,
        buttonTitle: () -> String,
        disabled: () -> Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(number)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(detail).font(.footnote).foregroundColor(.secondary)
                }
            }
            Button(buttonTitle(), action: action)
                .buttonStyle(GateSecondaryButtonStyle())
                .disabled(disabled())
        }
    }

    private func grantCard(_ grant: GateGrant) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ZUGANG GEWÄHRT")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundColor(.secondary)
            Text("\(grant.minutes) aktive Minuten")
                .font(.title2.weight(.semibold))
            Text("Nur die angeforderte \(grant.target.kind.displayName) ist freigegeben. Der Rest des Konsumpools bleibt gesperrt.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                if grant.expiresAt > Date() {
                    HStack {
                        Text("Verfällt bei Nichtnutzung in")
                        Spacer()
                        Text(grant.expiresAt, style: .timer)
                            .monospacedDigit()
                    }
                    .font(.footnote.weight(.medium))
                } else {
                    Text("Freigabe abgelaufen")
                        .font(.footnote.weight(.medium))
                }
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func notice(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var principles: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("UNVERHANDELBAR")
                .font(.caption.weight(.semibold))
                .tracking(1.5)
                .foregroundColor(.secondary)
            Text("Der Erwachsenenfilter und Apples Sperre für explizite Medien bleiben aktiv, auch während der freien Stunde und während einer verdienten Freigabe.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 12)
    }
}

private struct GatePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(Color(uiColor: .systemBackground))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.primary.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct GateSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(configuration.isPressed ? 0.11 : 0.055))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    ContentView(controller: ScreenTimeController())
}

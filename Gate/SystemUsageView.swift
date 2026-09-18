import DeviceActivity
import FamilyControls
import SwiftUI

struct SystemUsageView: View {
    @ObservedObject var controller: ScreenTimeController
    let showCheckpoints: () -> Void
    @State private var scope: GateReportScope = .consumption
    @State private var requestID = UUID()
    @State private var requestedAt = Date()
    @Environment(\.scenePhase) private var scenePhase

    private var savedSelection: FamilyActivitySelection { GateShieldPolicy.selection(from: controller.state) }
    private var canRequest: Bool {
        scope.canRequest(applicationCount: savedSelection.applicationTokens.count,
                         domainCount: savedSelection.webDomainTokens.count)
    }
    private var filter: DeviceActivityFilter {
        let selected = savedSelection
        return DeviceActivityFilter(segment: .daily(during: GateReportTimeline(ending: requestedAt).interval),
            users: .all, devices: .init([.iPhone]),
            applications: scope == .consumption ? selected.applicationTokens : [],
            webDomains: scope == .consumption ? selected.webDomainTokens : [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("iOS-Nutzungsbericht").font(.headline)
                Spacer()
                Button { reload() } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("iOS-Bericht erneut laden")
            }
            Picker("Umfang der Bildschirmzeit", selection: $scope) {
                ForEach(GateReportScope.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            Text(scope == .consumption
                 ? "Nur deine Konsum-Auswahl zählt fürs Budget."
                 : "Alle Apps · unabhängig vom Freibudget")
                .font(.subheadline).foregroundStyle(.secondary)

            if !controller.isAuthorized {
                ContentUnavailableView("Bildschirmzeit erlauben", systemImage: "lock.shield",
                    description: Text("Erlaube Gate unter Mehr den Zugriff auf Bildschirmzeit, um den Bericht anzuzeigen."))
            } else if !canRequest {
                ContentUnavailableView("Noch keine Konsum-Auswahl", systemImage: "apps.iphone",
                    description: Text("Wähle unter Mehr deine Konsum-Apps aus oder wechsle hier zu Alle Apps."))
            } else {
                ZStack {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("iOS-Bericht wird angefordert …").font(.subheadline)
                        Text("Bleibt die Fläche leer, lade den Bericht oben erneut. Fehlende Daten sind kein Verbrauch von null Minuten.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.padding(24)
                    DeviceActivityReport(DeviceActivityReport.Context(scope.contextID), filter: filter)
                        .id("\(scope.rawValue)-\(requestID)")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Button(action: showCheckpoints) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Freigabezähler").font(.subheadline.weight(.medium))
                        Text("Heute mindestens \(GateReportDuration.text(Double(controller.state.confirmedMinutes) * 60)) · nur Konsum-Auswahl")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption)
                }.padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.bottom, 8)
        .onAppear { reload() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { reload() } }
        .onChange(of: scope) { _, _ in reload() }
        .onChange(of: controller.state.day) { _, _ in reload() }
        .onChange(of: controller.state.selectionData) { _, _ in reload() }
        .onChange(of: controller.isAuthorized) { _, _ in reload() }
    }

    private func reload() {
        requestedAt = Date()
        requestID = UUID()
    }
}

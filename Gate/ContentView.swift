import Combine
import FamilyControls
import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: ScreenTimeController
    @ObservedObject var learning: LearningStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var tab = 0
    @State private var onboarding = false
    private let tabs = ["Heute", "Lernen", "Bilanz", "Mehr"]

    init(controller: ScreenTimeController) {
        self.controller = controller
        self.learning = controller.learning
    }

    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case 1: LearningLibraryView(controller: controller, learning: learning)
                case 2: GateStatisticsView(controller: controller, learning: learning)
                case 3: GateSettingsView(controller: controller)
                default: home
                }
            }
            .background(GateDesign.paper)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 0) {
                        ForEach(tabs.indices, id: \.self) { index in
                            Button { GateKeyboard.dismiss(); tab = index } label: {
                                VStack(spacing: 8) {
                                    Rectangle().fill(tab == index ? Color.primary : .clear).frame(width: 18, height: 2)
                                    Text(tabs[index]).font(.caption.weight(tab == index ? .semibold : .regular))
                                }.frame(maxWidth: .infinity).frame(minHeight: 52)
                            }.buttonStyle(.plain).accessibilityAddTraits(tab == index ? .isSelected : [])
                        }
                    }.padding(.horizontal, 18).background(GateDesign.paper)
                }
            }
        }
        .tint(.primary)
        .sheet(isPresented: $onboarding) { GateOnboardingView(controller: controller) }
        .sheet(isPresented: $controller.showPause, onDismiss: { controller.closePause() }) {
            IntentionalPauseView(controller: controller)
        }
        .sheet(item: $learning.session, onDismiss: { controller.lessonDidClose() }) { _ in
            LessonView(controller: controller, learning: learning)
        }
        .alert("Gate", isPresented: Binding(get: { controller.errorMessage != nil }, set: { if !$0 { controller.errorMessage = nil } })) {
            Button("Verstanden") { controller.errorMessage = nil }
        } message: { Text(controller.errorMessage ?? "") }
        .onAppear { onboarding = !controller.state.onboardingComplete }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { controller.refreshSharedState() }
            else { learning.checkpoint() }
        }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            if scenePhase == .active { controller.refreshSharedState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gateRequestOpened)) { note in
            controller.refreshSharedState()
            if let id = note.userInfo?["id"] as? UUID,
               let request = controller.state.requests.first(where: { $0.id == id }) {
                controller.selectRequest(request); tab = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gatePauseOpened)) { _ in
            controller.requestPause()
        }
        .onOpenURL { url in
            controller.handleURL(url)
            if url.host == "launch", let id = UUID(uuidString: url.lastPathComponent),
               let item = controller.state.launcher.first(where: { $0.id == id && $0.enabled }) {
                open(item)
            } else { tab = 0 }
        }
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                HStack {
                    Text("gate").font(.system(.title2, design: .serif)).tracking(-1)
                    Spacer()
                    Eyebrow(text: Date().formatted(.dateTime.day().month(.wide)))
                }
                VStack(alignment: .leading, spacing: 16) {
                    Text(controller.state.limitReached ? "Erst verstehen.\nDann weiter." : "Platz für das,\nwas zählt.")
                        .font(.system(.largeTitle, design: .serif)).fixedSize(horizontal: false, vertical: true)
                    Text(controller.state.monitoringEnabled
                         ? "Deine Aufmerksamkeit gehört dir."
                         : "Wähle deine Ablenkungen. Den Rest lässt Gate in Ruhe.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                allowance

                // Requests and grants are siblings, NEVER if-grant / else-if-request.
                if let request = controller.selectedRequest {
                    RequestCard(controller: controller, request: request)
                }
                if controller.state.requests.count > 1 {
                    GateSection(title: "Weitere Anfragen") {
                        ForEach(controller.state.requests.filter { $0.id != controller.selectedRequest?.id }) { request in
                            Button { controller.selectRequest(request) } label: {
                                HStack { GateTargetLabel(target: request.target); Spacer(); Text("Lektion").foregroundStyle(.secondary) }
                                    .padding(.vertical, 12)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                if !controller.activeGrants.isEmpty {
                    GateSection(title: "Deine Freigaben · unabhängig") {
                        ForEach(controller.activeGrants) { grant in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    GateTargetLabel(target: grant.target).font(.headline)
                                    Spacer()
                                    Text("≤ \(grant.minutes - grant.usedMinutes) min").font(.headline.monospacedDigit())
                                }
                                GateProgressLine(value: Double(grant.minutes - grant.usedMinutes) / Double(grant.minutes))
                                HStack {
                                    Text("Gültig bis \(grant.expiresAt.formatted(date: .omitted, time: .shortened))")
                                    Spacer()
                                    Button("Beenden") { controller.endGrant(grant) }.underline()
                                }.font(.caption).foregroundStyle(.secondary)
                            }.padding(18).background(GateDesign.surface).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Text("Restzeit anhand bestätigter iOS-Nutzungsschwellen; kein sekundengenauer Countdown.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let message = controller.message {
                    Text(message).font(.footnote).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(GateDesign.surface).onTapGesture { controller.message = nil }
                }
                GateSection(title: "Das Wesentliche") {
                    VStack(spacing: 0) {
                        ForEach(controller.state.launcher.filter(\.enabled)) { item in
                            Button { open(item) } label: {
                                HStack {
                                    Text(item.title).font(.system(.title2, design: .serif))
                                    Spacer()
                                    Text("Öffnen").font(.caption).foregroundStyle(.secondary)
                                }.frame(minHeight: 55).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
                if controller.state.limitReached && controller.state.monitoringEnabled {
                    ProtectedTargetsView(controller: controller)
                }
                Button { controller.beginPractice() } label: {
                    HStack { Text("Einfach etwas lernen"); Spacer(); Text("\(learning.dueCount) fällig").foregroundStyle(.secondary) }
                }.buttonStyle(GateButtonStyle(prominent: false))
                Button("Einen Impuls unterbrechen") { controller.showPause = true }
                    .font(.footnote).underline().frame(maxWidth: .infinity)
                Text("Kein Feed. Kein Wettlauf. Ein guter Gedanke reicht.")
                    .font(.system(.footnote, design: .serif)).foregroundStyle(.secondary)
            }.padding(24).padding(.bottom, 24)
        }
    }

    private var allowance: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: controller.state.limitReached ? "Freie Stunde aufgebraucht" : "Freie Tageszeit")
                Spacer()
                Text(controller.state.monitoringEnabled && controller.monitorReady ? "AKTIV" : controller.state.monitoringEnabled ? "PRÜFEN" : "PAUSIERT").font(.caption2.weight(.semibold))
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(controller.state.limitReached ? "0" : "≤ \(max(0, controller.state.freeMinutes - controller.state.confirmedMinutes))")
                    .font(.system(size: 48, weight: .light, design: .serif)).monospacedDigit()
                Text("min frei").font(.subheadline).foregroundStyle(.secondary)
            }
            GateProgressLine(value: Double(max(0, controller.state.freeMinutes - controller.state.confirmedMinutes)) / Double(controller.state.freeMinutes))
            Text(controller.state.freeMinutes == 2 ? "Testmodus · 2 Minuten. In Mehr auf Alltag wechseln." : "60 Minuten gemeinsam für ausgewählte Konsum-Apps und Websites.")
                .font(.caption).foregroundStyle(.secondary)
            if let date = controller.state.lastUsageUpdate {
                Text("Zuletzt bestätigt: \(date.formatted(date: .omitted, time: .shortened)) · Anzeige in Nutzungsschritten.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if !controller.state.monitoringEnabled || !controller.monitorReady {
                Button("Gate einrichten") { tab = 3 }.buttonStyle(GateButtonStyle())
            }
        }.padding(20).overlay(RoundedRectangle(cornerRadius: 14).stroke(GateDesign.line))
    }

    private func open(_ item: LauncherItem) {
        guard let url = item.validatedURL else { return }
        openURL(url) { accepted in
            if !accepted { controller.errorMessage = "„\(item.title)“ konnte nicht geöffnet werden. Prüfe den Link unter Mehr → Textliste." }
        }
    }
}

private struct RequestCard: View {
    @ObservedObject var controller: ScreenTimeController
    let request: GateRequest
    @State private var minutes = 5
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Eine bewusste Entscheidung")
            GateTargetLabel(target: request.target).font(.system(.title, design: .serif))
            Text("Wie viel Zeit möchtest du freigeben?").font(.subheadline).foregroundStyle(.secondary)
            Picker("Freigabedauer", selection: $minutes) {
                ForEach(LessonLoad.allowedMinutes, id: \.self) { Text("\($0) min").tag($0) }
            }.pickerStyle(.segmented)
            let attempt = controller.state.attempts[request.target.id] ?? GateAttempt()
            let count = LessonLoad.questionCount(minutes: minutes, consumedMinutes: controller.state.confirmedMinutes, failures: attempt.failures)
            Text("\(count) Fragen · Umfang wächst mit Dauer, Tagesnutzung und Fehlversuchen.")
                .font(.caption).foregroundStyle(.secondary)
            if let until = attempt.cooldownUntil, until > Date() {
                Text("Kurze Pause für diese App. Neuer Versuch ab \(until.formatted(date: .omitted, time: .shortened)).")
                    .font(.subheadline)
            } else {
                Button("Lektion beginnen") { controller.beginLesson(minutes: minutes) }.buttonStyle(GateButtonStyle())
            }
            Text("Nur diese \(request.target.kind.displayName). Andere Freigaben bleiben erhalten.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(20).background(GateDesign.surface).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct ProtectedTargetsView: View {
    @ObservedObject var controller: ScreenTimeController
    private var targets: [GateTarget] {
        let selected = GateShieldPolicy.selection(from: controller.state)
        return selected.applicationTokens.compactMap { token in
            (try? PropertyListEncoder().encode(token)).map { GateTarget(kind: .application, tokenData: $0) }
        } + selected.webDomainTokens.compactMap { token in
            (try? PropertyListEncoder().encode(token)).map { GateTarget(kind: .webDomain, tokenData: $0) }
        }
    }
    var body: some View {
        GateSection(title: "Apps einzeln freigeben") {
            ForEach(targets.filter { !GateShieldPolicy.isProtected($0, in: controller.state) }) { target in
                Button { controller.requestLesson(for: target) } label: {
                    HStack {
                        GateTargetLabel(target: target)
                        Spacer()
                        Text(controller.state.grant(for: target, at: Date()) == nil ? "Gesperrt" : "Frei").font(.caption).foregroundStyle(.secondary)
                    }.frame(minHeight: 44)
                }.buttonStyle(.plain).disabled(controller.state.grant(for: target, at: Date()) != nil)
                Divider()
            }
            Text("Auch erreichbar, wenn eine Shield-Mitteilung fehlt. Telefon und WhatsApp nicht in die Sperrauswahl aufnehmen.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

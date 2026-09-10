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

    init(controller: ScreenTimeController) {
        self.controller = controller
        self.learning = controller.learning
    }

    var body: some View {
        // The system owns the bar, its glass appearance and selection gestures.
        // Each tab keeps its own navigation stack when another tab is selected.
        TabView(selection: $tab) {
            NavigationStack {
                home
                    .background(GateDesign.paper)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Heute", systemImage: "house") }.tag(0)

            NavigationStack {
                LearningLibraryView(controller: controller, learning: learning)
                    .background(GateDesign.paper)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Lernen", systemImage: "books.vertical") }.tag(1)

            NavigationStack {
                GateStatisticsView(controller: controller, learning: learning)
                    .background(GateDesign.paper)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Bilanz", systemImage: "chart.bar.xaxis") }.tag(2)

            NavigationStack {
                GateSettingsView(controller: controller)
                    .background(GateDesign.paper)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Mehr", systemImage: "slider.horizontal.3") }.tag(3)
        }
        .tint(.primary)
        .onChange(of: tab) { _, _ in GateKeyboard.dismiss() }
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
            if phase == .active { controller.refreshSharedState(); controller.checkMonitoringNow() }
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
                    Button { controller.requestPause() } label: {
                        Label("Pause", systemImage: "pause.circle")
                            .font(.subheadline.weight(.medium)).padding(.vertical, 12)
                    }.buttonStyle(.plain).accessibilityLabel("Gate-Pause öffnen")
                }
                VStack(alignment: .leading, spacing: 16) {
                    Eyebrow(text: Date().formatted(.dateTime.day().month(.wide)))
                    Text(controller.state.limitReached ? "Erst verstehen.\nDann weiter." : "Platz für das,\nwas zählt.")
                        .font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                    Text(controller.state.monitoringEnabled
                         ? "Deine Aufmerksamkeit gehört dir."
                         : "Wähle deine Ablenkungen. Den Rest lässt Gate in Ruhe.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if controller.state.isTestMode {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Zwei-Minuten-Test aktiv", systemImage: "wrench.and.screwdriver").font(.headline)
                        Text("Aktuell gelten 2 statt \(GateState.everydayFreeMinutes) freie Minuten. Du kannst direkt zum Alltag zurückkehren.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("Auf Alltag wechseln") { controller.useEverydayMode() }
                            .buttonStyle(GateButtonStyle()).disabled(!controller.isAuthorized)
                    }.gateCard()
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
                                    Text(item.title).font(.title3.weight(.medium))
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
                Button("Einen Impuls unterbrechen") { controller.requestPause() }
                    .font(.footnote).underline().frame(maxWidth: .infinity)
                Text("Kein Feed. Kein Wettlauf. Ein guter Gedanke reicht.")
                    .font(.system(.footnote, design: .serif)).foregroundStyle(.secondary)
            }.padding(24).padding(.bottom, 24)
        }
    }

    private var allowance: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: controller.state.limitReached ? (controller.state.isTestMode ? "Testbudget aufgebraucht" : "Freies Budget aufgebraucht") : "Dein Tagesbudget")
                Spacer()
                Text(controller.state.monitoringEnabled && controller.monitorReady ? (controller.state.isTestMode ? "TEST" : "ALLTAG") : controller.state.monitoringEnabled ? "PRÜFEN" : "INAKTIV")
                    .font(.caption2.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(GateDesign.paper).clipShape(Capsule())
            }
            AllowanceGauge(remainingMinutes: controller.state.remainingFreeMinutes,
                           totalMinutes: controller.state.freeMinutes)
            Text("\(controller.state.confirmedMinutes) von \(controller.state.freeMinutes) Minuten durch iOS bestätigt.")
                .font(.caption).foregroundStyle(.secondary)
            Text("Die freie Restzeit ist eine Obergrenze zwischen iOS-Nutzungsmeldungen, kein Live-Zähler der gesamten Bildschirmzeit.")
                .font(.caption2).foregroundStyle(.secondary)
            if controller.state.monitoringEnabled { MonitoringStatusView(controller: controller) }
            if !controller.state.monitoringEnabled || !controller.monitorReady {
                Button("Gate einrichten") { tab = 3 }.buttonStyle(GateButtonStyle())
            }
        }.gateCard()
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
            Text("Ein konkretes Thema · bis zu \(count) Fragen. Mehr Zeit bedeutet mehr Tiefe, keinen Themenwechsel.")
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

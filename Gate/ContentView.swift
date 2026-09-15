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
    @State private var allowanceDetails = false

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
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Heute", systemImage: "house") }.tag(0)

            NavigationStack {
                LearningLibraryView(controller: controller, learning: learning)
                    .gateBackground()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Lernen", systemImage: "books.vertical") }.tag(1)

            NavigationStack {
                GateStatisticsView(controller: controller, learning: learning)
                    .gateBackground()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Bilanz", systemImage: "chart.bar.xaxis") }.tag(2)

            NavigationStack {
                GateSettingsView(controller: controller)
                    .gateBackground()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Mehr", systemImage: "slider.horizontal.3") }.tag(3)
        }
        .tint(GateDesign.accent)
        .onChange(of: tab) { _, _ in GateKeyboard.dismiss() }
        .sheet(isPresented: $onboarding) { GateOnboardingView(controller: controller) }
        .sheet(isPresented: $controller.showPause, onDismiss: { controller.closePause() }) {
            IntentionalPauseView(controller: controller)
        }
        .sheet(isPresented: $allowanceDetails) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("\(controller.state.confirmedMinutes) von \(controller.state.freeMinutes) Minuten bestätigt")
                            .font(.title3.weight(.semibold))
                        Text("Die Anzeige zeigt höchstens die verbleibende freie Zeit. iOS kann neue Nutzungsminuten verzögert melden.")
                            .font(.body).foregroundStyle(.secondary)
                        MonitoringStatusView(controller: controller, detailed: true)
                    }.padding(24)
                }
                .navigationTitle("Dein Tagesbudget").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { allowanceDetails = false }
                    }
                }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: Binding(get: { learning.isPresented }, set: { if !$0 { learning.suspend() } }), onDismiss: { controller.lessonDidClose() }) {
            if learning.session != nil {
                LessonView(controller: controller, learning: learning)
            } else {
                TopicChoiceView(learning: learning)
            }
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
        GateHomeSurface {
                GateHomeHeader { controller.requestPause() }
                allowance
                if controller.state.isTestMode {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Zwei-Minuten-Test aktiv", systemImage: "wrench.and.screwdriver").font(.headline)
                        Button("Auf Alltag wechseln") { controller.useEverydayMode() }
                            .buttonStyle(.bordered).disabled(!controller.isAuthorized)
                    }
                }
                if controller.selectedRequest == nil && controller.state.monitoringEnabled && controller.monitorReady {
                    Button("Etwas lernen") { controller.beginPractice() }
                        .buttonStyle(GateButtonStyle()).frame(maxWidth: 280)
                        .frame(maxWidth: .infinity)
                }

                // Requests and grants are siblings, NEVER if-grant / else-if-request.
                if let request = controller.selectedRequest {
                    RequestCard(controller: controller, request: request)
                }
                if controller.state.requests.count > 1 {
                    GateHomeSection(title: "Weitere Anfragen") {
                        ForEach(controller.state.requests.filter { $0.id != controller.selectedRequest?.id }) { request in
                            Button { controller.selectRequest(request) } label: {
                                HStack { GateTargetLabel(target: request.target); Spacer(); Text("Lektion").foregroundStyle(.secondary) }
                                    .padding(.vertical, 12)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                if !controller.activeGrants.isEmpty {
                    GateHomeSection(title: "Deine Freigaben") {
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
                            }.padding(.vertical, 12)
                            Divider()
                        }
                    }
                }
                if let message = controller.message {
                    HStack(alignment: .top) {
                        Text(message).font(.subheadline)
                        Spacer(minLength: 8)
                        Button { controller.message = nil } label: {
                            Image(systemName: "xmark").frame(width: 44, height: 44)
                        }.buttonStyle(.plain).accessibilityLabel("Hinweis schliessen")
                    }
                }
                GateHomeSection(title: "Das Wesentliche") {
                    VStack(spacing: 0) {
                        ForEach(controller.state.launcher.filter(\.enabled)) { item in
                            Button { open(item) } label: {
                                HStack {
                                    Text(item.title).font(.title3.weight(.medium))
                                    Spacer()
                                    Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                                }.frame(minHeight: 55).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
                if controller.state.limitReached && controller.state.monitoringEnabled {
                    ProtectedTargetsView(controller: controller)
                }
        }
    }

    private var allowance: some View {
        VStack(spacing: 18) {
            GateHomeBudget(remainingMinutes: controller.state.remainingFreeMinutes,
                           totalMinutes: controller.state.freeMinutes,
                           status: allowanceStatus) { allowanceDetails = true }
            if !controller.state.monitoringEnabled || !controller.monitorReady {
                Button("Gate einrichten") { tab = 3 }.buttonStyle(GateButtonStyle())
            }
        }
    }

    private var allowanceStatus: String? {
        if !controller.isAuthorized { return "Bildschirmzeit-Berechtigung fehlt" }
        if !controller.state.monitoringEnabled { return "Gate noch nicht aktiviert" }
        if !controller.monitorReady { return "Messung prüfen" }
        if controller.state.limitReached { return "Weitere Zeit durch Lernen" }
        return nil
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
            GateTargetLabel(target: request.target).font(.system(.title, design: .rounded))
            Text("Wie viel Zeit möchtest du freigeben?").font(.subheadline).foregroundStyle(.secondary)
            Picker("Freigabedauer", selection: $minutes) {
                ForEach(LessonLoad.allowedMinutes, id: \.self) { Text("\($0) min").tag($0) }
            }.pickerStyle(.segmented)
            let attempt = controller.state.attempts[request.target.id] ?? GateAttempt()
            Text("Ein Thema verstehen · jede Frage zählt")
                .font(.subheadline).foregroundStyle(.secondary)
            if let until = attempt.cooldownUntil, until > Date() {
                Text("Kurze Pause für diese App. Neuer Versuch ab \(until.formatted(date: .omitted, time: .shortened)).")
                    .font(.subheadline)
            } else {
                Button("Thema wählen") { controller.beginLesson(minutes: minutes) }.buttonStyle(GateButtonStyle())
            }
        }.padding(.vertical, 12)
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
        GateHomeSection(title: "Apps einzeln freigeben") {
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
        }
    }
}

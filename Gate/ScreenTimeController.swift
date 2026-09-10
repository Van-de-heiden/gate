import Combine
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications
import WidgetKit

@MainActor
final class ScreenTimeController: ObservableObject {
    @Published private(set) var state = GateState()
    @Published var selection = FamilyActivitySelection()
    @Published var protectedSelection = FamilyActivitySelection()
    @Published var showPause = false
    @Published private(set) var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published var isRequestingAuthorization = false
    @Published var message: String?
    @Published var errorMessage: String?
    @Published var selectedRequest: GateRequest?
    @Published private(set) var monitorReady = false
    let learning = LearningStore()
    private let activityCenter = DeviceActivityCenter()
    private var hasStorage = false
    private var pauseWaitingForLessonDismissal = false

    var isAuthorized: Bool { authorizationStatus == .approved }
    var activeGrants: [GateGrant] { state.activeGrants(at: Date()) }
    var hasSelection: Bool { !selection.applicationTokens.isEmpty || !selection.webDomainTokens.isEmpty }
    var selectionSummary: String { "\(selection.applicationTokens.count) Apps · \(selection.webDomainTokens.count) Websites" }

    init() {
        // Migration: these are the spike's two names, never other apps' monitors.
        activityCenter.stopMonitoring([DeviceActivityName("gate.daily"), DeviceActivityName("gate.grant")])
        refreshSharedState()
        selection = GateShieldPolicy.selection(from: state)
        protectedSelection = GateShieldPolicy.protectedSelection(from: state)
    }

    func refreshSharedState() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        do {
            state = try GateSharedStore.transaction(afterCommit: { state in
                if self.isAuthorized { GateShieldPolicy.apply(state) }
            }) { state in
                state.rollDay(at: Date())
                state.reconcileAllowance(at: Date())
                state.expireGrants(at: Date())
                return state
            }
            hasStorage = true
            presentPendingPause()
            monitorReady = isAuthorized && activityCenter.activities.contains(DeviceActivityName(state.dailyActivityName))
            let valid = Set(state.grants.map(\.activityName))
            let stale = activityCenter.activities.filter {
                $0.rawValue.hasPrefix("gate.grant.") && !valid.contains($0.rawValue)
            }
            if !stale.isEmpty { activityCenter.stopMonitoring(stale) }
            if let request = selectedRequest, !state.requests.contains(where: { $0.id == request.id }) {
                selectedRequest = nil
            }
            if selectedRequest == nil && learning.session == nil {
                selectedRequest = state.requests.sorted { $0.requestedAt > $1.requestedAt }.first
            }
        } catch { hasStorage = false; errorMessage = error.localizedDescription }
    }

    func requestAuthorization() async {
        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
            refreshSharedState()
        } catch { errorMessage = error.localizedDescription }
    }

    func startGate(testMode: Bool? = nil) {
        errorMessage = nil
        guard hasStorage, isAuthorized else { errorMessage = "Erlaube zuerst Bildschirmzeit und prüfe die App Group."; return }
        let saved = GateShieldPolicy.selection(from: state)
        let proposed = state.isSelectionLocked ? GateShieldPolicy.retaining(saved, adding: selection) : selection
        guard (!proposed.applicationTokens.isEmpty || !proposed.webDomainTokens.isEmpty), proposed.categoryTokens.isEmpty else {
            errorMessage = "Wähle einzelne Apps und Websites. Klappe Kategorien auf; ganze Kategorien würden auch wichtige Apps erfassen."
            return
        }
        do {
            // Do not trust the picker UI: deselection is merged back at the persistence boundary.
            selection = proposed
            let data = try PropertyListEncoder().encode(selection)
            let oldActivity = state.dailyActivityName
            let changed = saved.applicationTokens != selection.applicationTokens
                || saved.webDomainTokens != selection.webDomainTokens || saved.categoryTokens != selection.categoryTokens
            // Preserve today's usage when resuming or editing selection.
            try mutate { state in
                state.selectionData = data
                state.selectionLocked = true
                if let testMode {
                    if testMode { state.beginTestMode(at: Date()) }
                    else { state.useEverydayMode() }
                }
                state.monitoringEnabled = true
                state.reconcileAllowance(at: Date())
                if changed { state.dailyActivityName = "gate.daily.\(UUID().uuidString)" }
            }
            try installDailyMonitor()
            if changed { activityCenter.stopMonitoring([DeviceActivityName(oldActivity)]) }
            monitorReady = true
            message = state.isTestMode ? "Testmodus: 2 freie Minuten, nur für heute. Du kannst jederzeit auf Alltag wechseln." : "Gate ist bereit. 60 freie Minuten pro Tag, gemeinsam für deine Auswahl."
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Keep any already-required shields; do not clear other grants on an API failure.
            monitorReady = activityCenter.activities.contains(DeviceActivityName(state.dailyActivityName))
            errorMessage = "Monitoring konnte nicht eingerichtet werden: \(error.localizedDescription)"
        }
    }

    func useEverydayMode() {
        errorMessage = nil
        refreshSharedState()
        guard hasStorage, isAuthorized else {
            errorMessage = "Erlaube zuerst Bildschirmzeit und prüfe die App Group."; return
        }
        do {
            // Independent of any unsaved picker edits. Existing monitors already contain the 60-minute event.
            try mutate { $0.useEverydayMode() }
            if state.monitoringEnabled && !monitorReady { try installDailyMonitor() }
            refreshSharedState()
            message = "Alltag aktiv: 60 Minuten täglich. Der heutige bestätigte Verbrauch bleibt angerechnet."
        } catch { errorMessage = "Alltag konnte nicht vollständig aktiviert werden: \(error.localizedDescription)" }
    }

    private func installDailyMonitor() throws {
        let selected = GateShieldPolicy.selection(from: state)
        let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59), repeats: true)
        // These are confirmed checkpoints, not a fabricated live Screen Time total.
        let checkpoints = GateState.usageCheckpoints
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for minute in checkpoints {
            events[DeviceActivityEvent.Name("gate.usage.\(minute)")] = DeviceActivityEvent(
                applications: selected.applicationTokens, webDomains: selected.webDomainTokens,
                threshold: DateComponents(minute: minute), includesPastActivity: true)
        }
        try activityCenter.startMonitoring(DeviceActivityName(state.dailyActivityName), during: schedule, events: events)
    }

    func pauseGate() {
        guard !state.isSelectionLocked else {
            errorMessage = "Deine Auswahl ist verbindlich. Du kannst sie erweitern; eine Pause hebt sie nicht auf."
            return
        }
        do {
            let names = state.grants.map { DeviceActivityName($0.activityName) } + [DeviceActivityName(state.dailyActivityName)]
            try mutate { state in
                state.monitoringEnabled = false
                state.grants = []
                state.requests = []
            }
            activityCenter.stopMonitoring(names)
            monitorReady = false
            learning.suspend()
            selectedRequest = nil
            message = "Pausiert. Tagesverbrauch und Lernstand bleiben erhalten; der Inhaltsfilter bleibt gesetzt."
        } catch { errorMessage = error.localizedDescription }
    }

    func completeOnboarding() {
        do { try mutate { $0.onboardingComplete = true } }
        catch { errorMessage = error.localizedDescription }
    }

    func selectRequest(_ request: GateRequest) {
        learning.suspend()
        selectedRequest = request
    }

    func requestLesson(for target: GateTarget) {
        guard !GateShieldPolicy.isProtected(target, in: state) else { showPause = true; return }
        do {
            let request = try GateSharedStore.transaction { state -> GateRequest? in
                state.rollDay(at: Date())
                state.expireGrants(at: Date())
                return state.enqueue(target)
            }
            refreshSharedState()
            if let request { selectRequest(request) }
        } catch { errorMessage = error.localizedDescription }
    }

    func beginLesson(minutes: Int) {
        guard let request = selectedRequest, LessonLoad.allowedMinutes.contains(minutes) else { return }
        let attempt = state.attempts[request.target.id] ?? GateAttempt()
        guard (attempt.cooldownUntil ?? .distantPast) <= Date() else { return }
        guard activeGrants.count < 8 else { errorMessage = "Maximal acht Freigaben gleichzeitig. Beende zuerst eine laufende Freigabe."; return }
        learning.begin(request: request, minutes: minutes, consumed: state.confirmedMinutes, failures: attempt.failures)
    }

    func beginPractice(path: String? = nil, lesson: String? = nil, reviewOnly: Bool = false) {
        learning.begin(request: nil, minutes: 5, consumed: 0, failures: 0, path: path, lesson: lesson, reviewOnly: reviewOnly)
    }

    func submitLesson() {
        guard learning.session?.result == nil else { return }
        guard let result = learning.grade(), learning.error == nil else { return }
        if let target = learning.session?.target, !result.passed {
            do {
                try mutate { state in
                    var attempt = state.attempts[target.id] ?? GateAttempt()
                    attempt.fail(at: Date())
                    state.attempts[target.id] = attempt
                }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func retryLesson() {
        guard let current = learning.session, current.result?.passed == false else { return }
        if current.isPractice {
            learning.suspend()
            beginPractice(path: current.pathID, lesson: current.storageKey.hasPrefix("chapter.") ? current.lessonIDs.first : nil,
                          reviewOnly: current.storageKey == "review")
        } else {
            learning.suspend()
            beginLesson(minutes: current.grantMinutes)
        }
    }

    func finishLesson() {
        guard let session = learning.session, session.result?.passed == true, learning.error == nil else { return }
        if let target = session.target {
            do {
                try grantAccess(to: target, minutes: session.grantMinutes, requestID: session.requestID)
                message = "\(session.grantMinutes) aktive Minuten freigegeben. Weitere Apps kannst du unabhängig freigeben."
                learning.finish() // Success view closes; it must never cover the next request.
                selectedRequest = nil
                refreshSharedState()
            } catch { errorMessage = "Freigabe noch nicht erteilt: \(error.localizedDescription). Dein bestandener Test bleibt gespeichert." }
        } else { learning.finish() }
    }

    func endGrant(_ grant: GateGrant) {
        do {
            try mutate { $0.grants.removeAll { $0.id == grant.id } }
            activityCenter.stopMonitoring([DeviceActivityName(grant.activityName)])
        } catch { errorMessage = error.localizedDescription }
    }

    private func grantAccess(to target: GateTarget, minutes: Int, requestID: UUID?) throws {
        guard LessonLoad.allowedMinutes.contains(minutes) else { throw GateError.invalidGrant }
        refreshSharedState()
        guard isAuthorized, state.monitoringEnabled, state.limitReached,
              GateShieldPolicy.isSelected(target, in: state) else { throw GateError.selectionChanged }
        if state.grant(for: target, at: Date()) != nil { return }
        guard state.activeGrants(at: Date()).count < 8 else { throw GateError.tooManyGrants }
        guard (state.attempts[target.id]?.cooldownUntil ?? .distantPast) <= Date() else { throw GateError.cooldown }
        let now = Date()
        let grant = GateGrant(target: target, minutes: minutes, grantedAt: now, expiresAt: now.addingTimeInterval(30 * 60))
        // Reserve before calling DeviceActivity; an unarmed grant never removes a shield.
        try mutate { $0.grants.append(grant) }
        do {
            let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            let schedule = DeviceActivitySchedule(
                intervalStart: Calendar.current.dateComponents(fields, from: now),
                intervalEnd: Calendar.current.dateComponents(fields, from: grant.expiresAt), repeats: false)
            var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
            for minute in 1...minutes {
                events[DeviceActivityEvent.Name("gate.used.\(minute)")] = try grantEvent(target, minutes: minute)
            }
            try activityCenter.startMonitoring(DeviceActivityName(grant.activityName), during: schedule, events: events)
            try mutate { state in
                guard let index = state.grants.firstIndex(where: { $0.id == grant.id }) else { throw GateError.invalidGrant }
                state.grants[index].armed = true
                state.attempts[target.id] = GateAttempt()
                state.requests.removeAll { $0.target.id == target.id }
                state.recordGrant(minutes)
            }
            if let requestID { UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["gate.request.\(requestID.uuidString)"]) }
        } catch {
            activityCenter.stopMonitoring([DeviceActivityName(grant.activityName)])
            try? mutate { $0.grants.removeAll { $0.id == grant.id } }
            throw error
        }
    }

    private func grantEvent(_ target: GateTarget, minutes: Int) throws -> DeviceActivityEvent {
        let decoder = PropertyListDecoder()
        switch target.kind {
        case .application:
            return DeviceActivityEvent(applications: [try decoder.decode(ApplicationToken.self, from: target.tokenData)],
                threshold: DateComponents(minute: minutes), includesPastActivity: false)
        case .webDomain:
            return DeviceActivityEvent(webDomains: [try decoder.decode(WebDomainToken.self, from: target.tokenData)],
                threshold: DateComponents(minute: minutes), includesPastActivity: false)
        case .category: throw GateError.invalidGrant
        }
    }

    func saveLauncher(_ items: [LauncherItem]) {
        errorMessage = nil
        let retained = AdditiveSelection.launcher(state.launcher, adding: items)
        guard retained.count <= 12, retained.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespaces).isEmpty && $0.validatedURL != nil }) else {
            errorMessage = "Höchstens zwölf Einträge, jeweils mit Name und gültigem App-Link oder https-Link."; return
        }
        do {
            try mutate { $0.launcher = AdditiveSelection.launcher($0.launcher, adding: items) }
            WidgetCenter.shared.reloadAllTimelines()
        } catch { errorMessage = error.localizedDescription }
    }

    func handleURL(_ url: URL) {
        guard url.scheme == "gate" else { return }
        refreshSharedState()
        if url.host == "learn" { beginPractice() }
        if url.host == "pause" { requestPause() }
        if url.host == "request", let id = UUID(uuidString: url.lastPathComponent),
           let request = state.requests.first(where: { $0.id == id }) { selectRequest(request) }
    }

    func saveProtectedWebsites() {
        errorMessage = nil
        guard protectedSelection.applicationTokens.isEmpty, protectedSelection.categoryTokens.isEmpty else {
            errorMessage = "Hier nur einzelne Websites wählen, keine Apps oder Kategorien."
            return
        }
        do {
            try mutate { state in
                let merged = GateShieldPolicy.retaining(GateShieldPolicy.protectedSelection(from: state), adding: self.protectedSelection)
                state.protectedSelectionData = try PropertyListEncoder().encode(merged)
                let snapshot = state
                state.grants.removeAll { GateShieldPolicy.isProtected($0.target, in: snapshot) }
                state.requests.removeAll { GateShieldPolicy.isProtected($0.target, in: snapshot) }
            }
            protectedSelection = GateShieldPolicy.protectedSelection(from: state)
            message = "Schutz-Websites ergänzt. Sie bleiben auch während der freien Stunde und nach Prüfungen gesperrt."
        } catch { errorMessage = error.localizedDescription }
    }

    func requestPause() {
        do { try mutate { $0.pauseRequestedAt = Date() } }
        catch { errorMessage = error.localizedDescription }
        if learning.session != nil {
            // Present the next sheet only after the current one has actually dismissed.
            pauseWaitingForLessonDismissal = true
            learning.suspend()
        } else { showPause = true }
    }

    func lessonDidClose() {
        learning.checkpoint()
        pauseWaitingForLessonDismissal = false
        presentPendingPause()
    }

    private func presentPendingPause() {
        guard !pauseWaitingForLessonDismissal, learning.session == nil, state.onboardingComplete,
              let requested = state.pauseRequestedAt,
              Date().timeIntervalSince(requested) < 300 else { return }
        showPause = true
    }

    func closePause() {
        do { try mutate { $0.pauseRequestedAt = nil } }
        catch { errorMessage = error.localizedDescription }
        showPause = false
    }

    private func mutate(_ body: (inout GateState) throws -> Void) throws {
        state = try GateSharedStore.transaction(afterCommit: { state in
            if self.isAuthorized { GateShieldPolicy.apply(state) }
        }) { state in
            state.rollDay(at: Date())
            state.expireGrants(at: Date())
            state.reconcileAllowance(at: Date())
            try body(&state)
            return state
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "GateLauncher")
    }

    enum GateError: LocalizedError {
        case invalidGrant, selectionChanged, tooManyGrants, cooldown
        var errorDescription: String? {
            switch self {
            case .invalidGrant: return "Die Freigabe ist nicht mehr gültig."
            case .selectionChanged: return "Die Auswahl oder der Tagesstatus hat sich geändert. Öffne die gewünschte App erneut."
            case .tooManyGrants: return "Acht Freigaben laufen bereits."
            case .cooldown: return "Für diese App läuft noch die Abkühlzeit."
            }
        }
    }
}

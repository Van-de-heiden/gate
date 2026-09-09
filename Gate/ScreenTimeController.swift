import Combine
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

@MainActor
final class ScreenTimeController: ObservableObject {
    @Published var selection = GateStorage.loadSelection()
    @Published private(set) var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published private(set) var isMonitoring = GateStorage.monitoringEnabled
    @Published private(set) var limitReached = GateStorage.limitReached
    @Published private(set) var pendingTarget = GateStorage.pendingTarget
    @Published private(set) var activeGrant = GateStorage.activeGrant
    @Published private(set) var consecutiveFailures = GateStorage.consecutiveFailures
    @Published private(set) var cooldownUntil = GateStorage.cooldownUntil
    @Published private(set) var lesson = GateLesson.make(failureLevel: GateStorage.consecutiveFailures)
    @Published var answers: [String: Int] = [:]
    @Published var message: String?
    @Published var errorMessage: String?
    @Published var isRequestingAuthorization = false

    private let activityCenter = DeviceActivityCenter()
    private let settingsStore = ManagedSettingsStore()
    private let decoder = PropertyListDecoder()

    var isAuthorized: Bool {
        authorizationStatus != .notDetermined && authorizationStatus != .denied
    }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty ||
        !selection.categoryTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty
    }

    var selectionSummary: String {
        let apps = selection.applicationTokens.count
        let categories = selection.categoryTokens.count
        let websites = selection.webDomainTokens.count
        return "\(apps) Apps · \(websites) Websites · \(categories) Kategorien"
    }

    var canSubmitLesson: Bool {
        lesson.questions.allSatisfy { answers[$0.id] != nil } && cooldownRemaining <= 0
    }

    var cooldownRemaining: TimeInterval {
        guard let cooldownUntil else { return 0 }
        return max(0, cooldownUntil.timeIntervalSinceNow)
    }

    init() {
        applyAlwaysOnProtections()
        refreshSharedState()
    }

    func requestAuthorization() async {
        isRequestingAuthorization = true
        errorMessage = nil
        defer { isRequestingAuthorization = false }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            applyAlwaysOnProtections()
            message = "Bildschirmzeit-Zugriff erteilt."
        } catch {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            errorMessage = "Die Bildschirmzeit-Freigabe ist fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func startGate() {
        errorMessage = nil
        message = nil

        guard isAuthorized else {
            errorMessage = "Erteile Gate zuerst Zugriff auf Bildschirmzeit."
            return
        }
        guard hasSelection else {
            errorMessage = "Wähle mindestens eine einzelne Konsum-App oder Website aus."
            return
        }

        do {
            try GateStorage.saveSelection(selection)
            activityCenter.stopMonitoring([GateConstants.dailyActivity, GateConstants.grantActivity])
            clearUsageShields()
            GateStorage.resetSessionState()

            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
                intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
                repeats: true,
                warningTime: nil
            )
            let event = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: GateConstants.dailyFreeMinutes)
            )

            try activityCenter.startMonitoring(
                GateConstants.dailyActivity,
                during: schedule,
                events: [GateConstants.dailyLimitEvent: event]
            )

            GateStorage.monitoringEnabled = true
            isMonitoring = true
            limitReached = false
            pendingTarget = nil
            activeGrant = nil
            consecutiveFailures = 0
            cooldownUntil = nil
            answers = [:]
            lesson = .make(failureLevel: 0)
            applyAlwaysOnProtections()
            message = "Gate läuft. Die gemeinsame Freigrenze beträgt \(GateConstants.dailyFreeMinutes) Minuten."
        } catch {
            GateStorage.monitoringEnabled = false
            isMonitoring = false
            errorMessage = "Das Monitoring konnte nicht gestartet werden: \(error.localizedDescription)"
        }
    }

    func stopGate() {
        activityCenter.stopMonitoring([GateConstants.dailyActivity, GateConstants.grantActivity])
        clearUsageShields()
        GateStorage.monitoringEnabled = false
        GateStorage.resetSessionState()
        isMonitoring = false
        limitReached = false
        pendingTarget = nil
        activeGrant = nil
        consecutiveFailures = 0
        cooldownUntil = nil
        answers = [:]
        lesson = .make(failureLevel: 0)
        applyAlwaysOnProtections()
        message = "Gate wurde für den Test angehalten. Der Inhaltsfilter bleibt aktiv."
    }

    func refreshSharedState() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        isMonitoring = GateStorage.monitoringEnabled
        limitReached = GateStorage.limitReached

        if let storedCooldown = GateStorage.cooldownUntil, storedCooldown <= Date() {
            GateStorage.cooldownUntil = nil
        }

        if let storedGrant = GateStorage.activeGrant, storedGrant.expiresAt <= Date() {
            GateStorage.activeGrant = nil
            if GateStorage.limitReached {
                applyFullUsageShield()
            }
        }

        pendingTarget = GateStorage.pendingTarget
        activeGrant = GateStorage.activeGrant
        consecutiveFailures = GateStorage.consecutiveFailures
        cooldownUntil = GateStorage.cooldownUntil
        lesson = .make(failureLevel: consecutiveFailures)
    }

    func chooseAnswer(_ answer: Int, for question: LessonQuestion) {
        answers[question.id] = answer
    }

    func submitLesson() {
        errorMessage = nil
        message = nil

        guard cooldownRemaining <= 0 else {
            errorMessage = "Die Abkühlzeit läuft noch."
            return
        }
        guard let target = pendingTarget else {
            errorMessage = "Öffne zuerst eine gesperrte App oder Website und merke die Freischaltung dort vor."
            return
        }
        guard canSubmitLesson else {
            errorMessage = "Beantworte zuerst jede Frage."
            return
        }

        let correctAnswers = lesson.questions.reduce(into: 0) { score, question in
            if answers[question.id] == question.correctAnswer {
                score += 1
            }
        }
        let questionTotal = lesson.questions.count
        let score = Double(correctAnswers) / Double(questionTotal)

        guard score >= 0.8 else {
            registerFailedAttempt(correct: correctAnswers, total: questionTotal)
            return
        }

        do {
            try grantAccess(to: target, for: GateConstants.prototypeGrantMinutes)
            GateStorage.consecutiveFailures = 0
            GateStorage.cooldownUntil = nil
            consecutiveFailures = 0
            cooldownUntil = nil
            answers = [:]
            lesson = .make(failureLevel: 0)
            message = "Bestanden: \(correctAnswers)/\(questionTotal). Die angeforderte \(target.kind.displayName) ist für \(GateConstants.prototypeGrantMinutes) aktive Minuten frei."
        } catch {
            applyFullUsageShield()
            errorMessage = "Die Freigabe konnte nicht eingerichtet werden: \(error.localizedDescription)"
        }
    }

    private func registerFailedAttempt(correct: Int, total: Int) {
        let newFailureCount = consecutiveFailures + 1
        GateStorage.consecutiveFailures = newFailureCount
        consecutiveFailures = newFailureCount
        answers = [:]
        lesson = .make(failureLevel: newFailureCount)

        if newFailureCount.isMultiple(of: 3) {
            let until = Date().addingTimeInterval(TimeInterval(GateConstants.cooldownMinutes * 60))
            GateStorage.cooldownUntil = until
            cooldownUntil = until
            errorMessage = "Nicht bestanden: \(correct)/\(total). Nach drei Fehlversuchen folgt eine Pause von \(GateConstants.cooldownMinutes) Minuten; danach wartet eine umfangreichere Variante."
        } else {
            errorMessage = "Nicht bestanden: \(correct)/\(total). Keine Freigabe. Der nächste Versuch wird ungefähr 20 % umfangreicher."
        }
    }

    private func grantAccess(to target: GateTarget, for minutes: Int) throws {
        let expiry = Date().addingTimeInterval(TimeInterval(GateConstants.grantExpiryMinutes * 60))
        let grant = GateGrant(target: target, minutes: minutes, grantedAt: Date(), expiresAt: expiry)

        activityCenter.stopMonitoring([GateConstants.grantActivity])
        let schedule = makeGrantSchedule(expiringAt: expiry)
        let event = try makeGrantEvent(target: target, minutes: minutes)

        try activityCenter.startMonitoring(
            GateConstants.grantActivity,
            during: schedule,
            events: [GateConstants.grantLimitEvent: event]
        )

        try applyUsageShields(excluding: target)
        GateStorage.activeGrant = grant
        GateStorage.pendingTarget = nil
        activeGrant = grant
        pendingTarget = nil
    }

    private func makeGrantSchedule(expiringAt expiry: Date) -> DeviceActivitySchedule {
        let components: Set<Calendar.Component> = [.hour, .minute, .second]
        let calendar = Calendar.current
        return DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: Date()),
            intervalEnd: calendar.dateComponents(components, from: expiry),
            repeats: false,
            warningTime: nil
        )
    }

    private func makeGrantEvent(target: GateTarget, minutes: Int) throws -> DeviceActivityEvent {
        let threshold = DateComponents(minute: minutes)

        switch target.kind {
        case .application:
            let token = try decoder.decode(ApplicationToken.self, from: target.tokenData)
            return DeviceActivityEvent(applications: [token], threshold: threshold)
        case .webDomain:
            let token = try decoder.decode(WebDomainToken.self, from: target.tokenData)
            return DeviceActivityEvent(webDomains: [token], threshold: threshold)
        case .category:
            let token = try decoder.decode(ActivityCategoryToken.self, from: target.tokenData)
            return DeviceActivityEvent(categories: [token], threshold: threshold)
        }
    }

    private func applyUsageShields(excluding target: GateTarget) throws {
        var applications = selection.applicationTokens
        var categories = selection.categoryTokens
        var webDomains = selection.webDomainTokens

        switch target.kind {
        case .application:
            applications.remove(try decoder.decode(ApplicationToken.self, from: target.tokenData))
        case .webDomain:
            webDomains.remove(try decoder.decode(WebDomainToken.self, from: target.tokenData))
        case .category:
            categories.remove(try decoder.decode(ActivityCategoryToken.self, from: target.tokenData))
        }

        settingsStore.shield.applications = applications.isEmpty ? nil : applications
        settingsStore.shield.webDomains = webDomains.isEmpty ? nil : webDomains

        if categories.isEmpty {
            settingsStore.shield.applicationCategories = nil
            settingsStore.shield.webDomainCategories = nil
        } else {
            settingsStore.shield.applicationCategories = .specific(categories, except: Set())
            settingsStore.shield.webDomainCategories = .specific(categories, except: Set())
        }
    }

    private func applyFullUsageShield() {
        let storedSelection = GateStorage.loadSelection()
        settingsStore.shield.applications = storedSelection.applicationTokens.isEmpty ? nil : storedSelection.applicationTokens
        settingsStore.shield.webDomains = storedSelection.webDomainTokens.isEmpty ? nil : storedSelection.webDomainTokens

        if storedSelection.categoryTokens.isEmpty {
            settingsStore.shield.applicationCategories = nil
            settingsStore.shield.webDomainCategories = nil
        } else {
            settingsStore.shield.applicationCategories = .specific(storedSelection.categoryTokens, except: Set())
            settingsStore.shield.webDomainCategories = .specific(storedSelection.categoryTokens, except: Set())
        }
    }

    private func clearUsageShields() {
        settingsStore.shield.applications = nil
        settingsStore.shield.applicationCategories = nil
        settingsStore.shield.webDomains = nil
        settingsStore.shield.webDomainCategories = nil
    }

    private func applyAlwaysOnProtections() {
        guard isAuthorized else { return }
        settingsStore.webContent.blockedByFilter = .auto()
        settingsStore.media.denyExplicitContent = true
        settingsStore.media.denyBookstoreErotica = true
    }
}

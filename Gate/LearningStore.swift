import Combine
import Foundation

@MainActor
final class LearningStore: ObservableObject {
    @Published private(set) var catalog: LearningCatalog?
    @Published private(set) var progress = LearningProgress()
    @Published var session: LearningSession?
    @Published var error: String?
    private let file: URL

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = folder.appendingPathComponent("gate-learning-v1.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            guard let resource = Bundle.main.url(forResource: "curriculum", withExtension: "json") else {
                throw LearningCatalog.CatalogError.invalid
            }
            let catalog = try JSONDecoder().decode(LearningCatalog.self, from: Data(contentsOf: resource))
            try catalog.validate()
            self.catalog = catalog
            if FileManager.default.fileExists(atPath: file.path) {
                progress = try JSONDecoder().decode(LearningProgress.self, from: Data(contentsOf: file))
            }
        } catch {
            self.error = "Lerninhalte oder Lernstand konnten nicht geladen werden: \(error.localizedDescription)"
        }
    }

    var dueCount: Int { LearningScheduler.dueCount(progress, at: Date()) }

    func begin(request: GateRequest?, minutes: Int, consumed: Int, failures: Int, path: String? = nil,
               lesson: String? = nil, reviewOnly: Bool = false) {
        guard let catalog, error == nil else { return }
        let key = request?.target.id ?? (lesson.map { "chapter." + $0 } ?? (reviewOnly ? "review" : path.map { "path." + $0 } ?? "practice"))
        if let saved = progress.sessions[key], saved.result == nil || saved.result?.passed == true {
            session = saved
            return
        }
        var random = SystemRandomNumberGenerator()
        let remediation = progress.sessions[key]?.result?.passed == false ? progress.sessions[key]?.lessonIDs ?? [] : []
        session = LearningScheduler.makeSession(catalog: catalog, progress: progress, request: request,
            minutes: minutes, consumed: consumed, failures: failures, preferredPath: path,
            preferredLesson: lesson, reviewOnly: reviewOnly,
            remediation: remediation, now: Date(), random: &random)
        checkpoint()
    }

    func markRead(_ id: String) { edit { $0.readLessonIDs.insert(id) } }
    func answer(_ index: Int, for id: String) { edit { $0.responses[id] = index } }
    func answer(_ response: QuestionResponse, for id: String) {
        edit {
            if $0.typedResponses == nil { $0.typedResponses = [:] }
            $0.typedResponses?[id] = response
            $0.responses.removeValue(forKey: id)
        }
    }
    func setPhase(_ phase: String) { edit { $0.phase = phase } }
    func note(_ text: String, for id: String) { edit { $0.reflectionNotes[id] = text } }
    func tick() {
        guard session != nil, session?.result == nil else { return }
        session?.activeSeconds += 1
        if (session?.activeSeconds ?? 0).isMultiple(of: 10) { checkpoint() }
    }

    @discardableResult
    func grade() -> LearningResult? {
        guard var current = session else { return nil }
        let result = LearningScheduler.grade(&current, progress: &progress, now: Date())
        session = current
        checkpoint()
        return result
    }

    func finish() {
        guard let current = session else { return }
        progress.sessions.removeValue(forKey: current.storageKey)
        session = nil
        save()
    }

    func suspend() { checkpoint(); session = nil }

    func checkpoint() {
        if let current = session { progress.sessions[current.storageKey] = current }
        save()
    }

    private func edit(_ body: (inout LearningSession) -> Void) {
        guard var current = session, current.result == nil else { return }
        body(&current)
        session = current
        checkpoint()
    }

    private func save() {
        do { try JSONEncoder().encode(progress).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
        catch { self.error = "Lernstand konnte nicht gespeichert werden: \(error.localizedDescription)" }
    }
}

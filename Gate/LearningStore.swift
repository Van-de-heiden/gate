import Combine
import Foundation

@MainActor
final class LearningStore: ObservableObject {
    @Published private(set) var catalog: LearningCatalog?
    @Published private(set) var referenceCatalog: LearningCatalog?
    @Published private(set) var progress = LearningProgress()
    @Published var session: LearningSession?
    @Published private(set) var choice: TopicChoice?
    var isPresented: Bool { session != nil || choice != nil }

    struct TopicChoice {
        let offer: LearningTopicOffer
        let request: GateRequest?
        let minutes: Int
        let consumed: Int
        let failures: Int
    }
    @Published var error: String?
    private let file: URL

    init(fileURL: URL? = nil, suppliedCatalog: LearningCatalog? = nil) {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = fileURL ?? folder.appendingPathComponent("gate-learning-v1.json")
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let catalog: LearningCatalog
            if let suppliedCatalog { catalog = suppliedCatalog }
            else {
                guard let resource = Bundle.main.url(forResource: "curriculum", withExtension: "json") else {
                    throw LearningCatalog.CatalogError.invalid
                }
                catalog = try JSONDecoder().decode(LearningCatalog.self, from: Data(contentsOf: resource))
            }
            try catalog.validate()
            self.catalog = catalog
            if let reference = Bundle.main.url(forResource: "reference-curriculum", withExtension: "json") {
                referenceCatalog = try? JSONDecoder().decode(LearningCatalog.self, from: Data(contentsOf: reference))
            }
            if FileManager.default.fileExists(atPath: file.path) {
                progress = try JSONDecoder().decode(LearningProgress.self, from: Data(contentsOf: file))
                // Keep completed history and earned results; replace unfinished obsolete question decks.
                progress.reconcileCatalog(catalog)
                save()
            }
        } catch {
            self.error = "Lerninhalte oder Lernstand konnten nicht geladen werden: \(error.localizedDescription)"
        }
    }

    var dueCount: Int {
        guard let catalog else { return 0 }
        if catalog.version >= 8 {
            return Set(catalog.questions.map { $0.skillID ?? $0.id }).filter {
                (progress.skillMemories?[$0]?.due ?? .distantFuture) <= Date()
            }.count
        }
        return catalog.questions.filter { (progress.memories[$0.id]?.due ?? .distantFuture) <= Date() }.count
    }

    func offeredChapters(for topicID: String) -> [LearningLesson] {
        guard let choice, let catalog else { return [] }
        if catalog.version >= 8 {
            return FocusedLearning.plan(catalog: catalog, progress: progress, topicID: topicID,
                minutes: choice.minutes, offeredChapterID: choice.offer.chapterIDs?[topicID])
        }
        return catalog.chapters(in: topicID).filter { $0.id == choice.offer.chapterIDs?[topicID] }
    }

    func prepare(request: GateRequest?, minutes: Int, consumed: Int, failures: Int) {
        guard let catalog, error == nil else { return }
        let storageKey = LearningScheduler.storageKey(request: request)
        if let saved = progress.sessions[storageKey],
           saved.result?.passed == true || saved.catalogVersion == catalog.version {
            // Includes retries: begin uses the original topic's mistakes.
            begin(request: request, minutes: minutes, consumed: consumed, failures: failures,
                  topic: saved.topicID)
            return
        }
        let key = LearningProgress.offerKey(request: request)
        var random = SystemRandomNumberGenerator()
        guard let offer = progress.topicOffer(catalog: catalog, key: key, now: Date(), random: &random) else { return }
        save()
        guard error == nil else { return }
        if let topic = offer.selectedTopicID {
            begin(request: request, minutes: minutes, consumed: consumed, failures: failures, topic: topic)
        } else {
            choice = TopicChoice(offer: offer, request: request, minutes: minutes, consumed: consumed, failures: failures)
        }
    }

    func choose(_ topicID: String) {
        guard let choice, let catalog else { return }
        guard progress.chooseTopic(topicID, from: choice.offer.id, catalog: catalog) else {
            prepare(request: choice.request, minutes: choice.minutes, consumed: choice.consumed, failures: choice.failures)
            return
        }
        save()
        guard error == nil else { return }
        begin(request: choice.request, minutes: choice.minutes, consumed: choice.consumed,
              failures: choice.failures, topic: topicID)
    }

    func begin(request: GateRequest?, minutes: Int, consumed: Int, failures: Int, path: String? = nil,
               lesson: String? = nil, topic: String? = nil, reviewOnly: Bool = false) {
        guard let catalog, error == nil else { return }
        let key = LearningScheduler.storageKey(request: request, path: path, lesson: lesson,
                                               topic: topic, reviewOnly: reviewOnly)
        let saved = progress.sessions[key]
        if let saved, saved.result?.passed == true ||
            (saved.result == nil && (catalog.version < 8 || saved.grantMinutes == minutes)) {
            session = saved
            choice = nil
            return
        }
        var random = SystemRandomNumberGenerator()
        let remediation = progress.sessions[key]?.result?.passed == false ? progress.sessions[key]?.lessonIDs ?? [] : []
        let previous = progress.sessions[key]
        let gaps = previous?.result?.passed == false
            ? previous?.questions.filter { previous?.isCorrect($0) == false }.map(\.id) ?? [] : []
        // A failed deck keeps its original grant as well as its original scope.
        // Changing the picker must never turn a short retry into a longer reward.
        let plannedMinutes = saved?.result?.passed == false ? saved!.grantMinutes : minutes
        session = LearningScheduler.makeSession(catalog: catalog, progress: progress, request: request,
            minutes: plannedMinutes, consumed: consumed, failures: failures, preferredPath: path,
            preferredLesson: lesson, preferredTopic: topic, reviewOnly: reviewOnly,
            remediation: remediation, remediationQuestionIDs: gaps, now: Date(), random: &random)
        if catalog.version >= 8, let saved, saved.result == nil, var current = session,
           saved.topicID == current.topicID {
            // A changed minute selection gets a newly sized plan, never a larger
            // grant attached to the old short deck. Retain compatible reading work.
            current.readCardIDs = (saved.readCardIDs ?? []).intersection(Set(current.requiredCardIDs ?? []))
            current.revealedCardIDs = saved.revealedCardIDs
            current.readLessonIDs = saved.readLessonIDs.intersection(Set(current.lessonIDs))
            current.reflectionNotes.merge(saved.reflectionNotes) { _, old in old }
            current.activeSeconds = saved.activeSeconds
            session = current
        }
        choice = nil
        checkpoint()
    }

    func markRead(_ id: String) {
        edit { session in
            guard session.lessonIDs.contains(id) else { return }
            if let required = session.requiredCardIDs {
                let cards = required.filter { $0.hasPrefix(id + ".step.") }
                guard Set(cards).isSubset(of: session.readCardIDs ?? []) else { return }
            }
            session.readLessonIDs.insert(id)
        }
    }
    func markCardRead(_ id: String) { edit { _ = $0.completeReadingCard(id) } }
    func answer(_ index: Int, for id: String) { answer(QuestionResponse(indices: [index]), for: id) }
    func answer(_ response: QuestionResponse, for id: String) { edit { $0.setAnswer(response, for: id) } }
    func setPhase(_ phase: String) {
        edit { session in
            guard phase == "learn" || (phase == "quiz" && session.readyForQuiz) else { return }
            session.phase = phase
        }
    }
    func setPosition(_ position: Int) {
        edit { if $0.phase == "learn" { $0.readerIndex = position } else if $0.phase == "quiz" { $0.quizIndex = position } }
    }
    func probe(_ response: QuestionResponse, for id: String) {
        answer(response, for: id)
    }
    func submitProbe(_ id: String, cardID: String) {
        edit { $0.submitInlineQuestion(id, cardID: cardID) }
    }
    func reveal(_ id: String) {
        edit { if $0.revealedCardIDs == nil { $0.revealedCardIDs = [] }; $0.revealedCardIDs?.insert(id) }
    }
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
        progress.topicOffers?.removeValue(forKey: current.requestID.map { "request." + $0.uuidString } ?? "practice")
        session = nil
        choice = nil
        save()
    }

    func suspend() { checkpoint(); session = nil; choice = nil }

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

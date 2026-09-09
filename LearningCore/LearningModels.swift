import Foundation

#if SWIFT_PACKAGE
extension LearningCatalog {
    static func packageCatalog() throws -> LearningCatalog {
        let url = Bundle.module.url(forResource: "curriculum", withExtension: "json")!
        return try JSONDecoder().decode(LearningCatalog.self, from: Data(contentsOf: url))
    }
}
#endif

struct LearningPath: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let number: String
}

struct LessonSource: Codable {
    let title: String
    let url: String
}

struct LessonVisual: Codable {
    let kind: String
    let title: String
    let labels: [String]
    let values: [Double]?
    let caption: String
}

struct LessonPhoto: Codable {
    let url: String
    let caption: String
    let credit: String
    let sourceURL: String
}

struct LessonCard: Codable {
    let title: String
    let text: String
}

struct LearningQuestion: Codable, Identifiable {
    let id: String
    let prompt: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

struct LearningLesson: Codable, Identifiable {
    let id: String
    let pathID: String
    let order: Int
    let title: String
    let objective: String
    let cards: [LessonCard]
    let visual: LessonVisual
    let photo: LessonPhoto?
    let reflection: String
    let takeaway: String
    let source: LessonSource
    let questions: [LearningQuestion]
}

struct LearningCatalog: Codable {
    let version: Int
    let paths: [LearningPath]
    let lessons: [LearningLesson]
    var questions: [LearningQuestion] { lessons.flatMap(\.questions) }
    func lesson(forQuestion id: String) -> LearningLesson? { lessons.first { $0.questions.contains { $0.id == id } } }
    func orderedLessons(in pathID: String) -> [LearningLesson] { lessons.filter { $0.pathID == pathID }.sorted { $0.order < $1.order } }

    func validate() throws {
        let pathIDs = Set(paths.map(\.id))
        guard pathIDs.count == paths.count, Set(lessons.map(\.id)).count == lessons.count,
              Set(questions.map(\.id)).count == questions.count,
              paths.allSatisfy({ orderedLessons(in: $0.id).count >= 3 }),
              lessons.allSatisfy({ pathIDs.contains($0.pathID) && $0.cards.count >= 2 && $0.questions.count >= 4 }),
              questions.allSatisfy({ $0.options.count >= 3 && $0.options.indices.contains($0.correctIndex) })
        else { throw CatalogError.invalid }
    }
    enum CatalogError: Error { case invalid }
}

struct QuestionMemory: Codable {
    var streak = 0
    var attempts = 0
    var correctAttempts = 0
    var due = Date.distantPast
    var lastStrengthenedAt: Date?

    mutating func record(correct: Bool, now: Date) {
        attempts += 1
        if correct {
            correctAttempts += 1
            if lastStrengthenedAt == nil || now.timeIntervalSince(lastStrengthenedAt!) >= 20 * 3600 {
                streak = min(streak + 1, 5)
                lastStrengthenedAt = now
            }
            let days = [1, 3, 7, 14, 30][streak - 1]
            due = now.addingTimeInterval(Double(days) * 86400)
        } else {
            streak = 0
            lastStrengthenedAt = nil
            due = now.addingTimeInterval(10 * 60)
        }
    }
}

struct LearningResult: Codable, Identifiable {
    let id: UUID
    let completedAt: Date
    let lessonIDs: [String]
    let correct: Int
    let total: Int
    let passed: Bool
    let practice: Bool
    let activeSeconds: Int
}

struct LearningProgress: Codable {
    var version = 1
    var memories: [String: QuestionMemory] = [:]
    var completedLessonIDs: Set<String> = []
    var recentPathIDs: [String] = []
    var results: [LearningResult] = []
    var sessions: [String: LearningSession] = [:]
}

struct SessionQuestion: Codable, Identifiable {
    let question: LearningQuestion
    let lessonID: String
    let isReview: Bool
    // Preserve the permutation on reopen; correct answer is not always A.
    let optionOrder: [Int]
    var id: String { question.id }
}

struct LearningSession: Codable, Identifiable {
    let id: UUID
    let storageKey: String
    let target: GateTarget?
    let requestID: UUID?
    let grantMinutes: Int
    let pathID: String
    let lessonIDs: [String]
    let questions: [SessionQuestion]
    var readLessonIDs: Set<String> = []
    var responses: [String: Int] = [:]
    var reflectionNotes: [String: String] = [:]
    var activeSeconds = 0
    var phase = "learn"
    var result: LearningResult?
    var estimatedSeconds: Int { max(45, questions.count * 12 + lessonIDs.count * 30) }
    var readyForQuiz: Bool { Set(lessonIDs).isSubset(of: readLessonIDs) }
    var isPractice: Bool { target == nil }
}

enum LearningScheduler {
    static func dueCount(_ progress: LearningProgress, at now: Date) -> Int {
        progress.memories.values.filter { $0.due <= now }.count
    }

    static func makeSession<R: RandomNumberGenerator>(
        catalog: LearningCatalog, progress: LearningProgress, request: GateRequest?,
        minutes: Int, consumed: Int, failures: Int, preferredPath: String? = nil,
        remediation: [String] = [], now: Date, random: inout R
    ) -> LearningSession {
        let count = LessonLoad.questionCount(minutes: minutes, consumedMinutes: consumed, failures: failures)
        let due = catalog.questions.filter { (progress.memories[$0.id]?.due ?? .distantFuture) <= now }
            .sorted { (progress.memories[$0.id]?.due ?? now) < (progress.memories[$1.id]?.due ?? now) }
        let remainingPaths = catalog.paths.filter { !progress.recentPathIDs.suffix(2).contains($0.id) }
        let pool = remainingPaths.isEmpty ? catalog.paths : remainingPaths
        let pathID = preferredPath ?? remediation.first.flatMap { id in catalog.lessons.first { $0.id == id }?.pathID }
            ?? pool.randomElement(using: &random)?.id ?? catalog.paths[0].id
        let ordered = catalog.orderedLessons(in: pathID)
        let next = ordered.first { !progress.completedLessonIDs.contains($0.id) }
            ?? ordered.min { a, b in
                let aDue = a.questions.map { progress.memories[$0.id]?.due ?? .distantPast }.min() ?? .distantPast
                let bDue = b.questions.map { progress.memories[$0.id]?.due ?? .distantPast }.min() ?? .distantPast
                return aDue < bDue
            }!
        var selected: [LearningQuestion] = []
        var seen = Set<String>()
        func append(_ question: LearningQuestion) {
            if selected.count < count && seen.insert(question.id).inserted { selected.append(question) }
        }
        // Retrieval from earlier lessons is mixed in, before adding fresh material.
        for question in due.prefix(max(1, count / 3)) { append(question) }
        for id in remediation {
            for question in (catalog.lessons.first { $0.id == id }?.questions.shuffled(using: &random) ?? []) { append(question) }
        }
        for question in next.questions.shuffled(using: &random) { append(question) }
        for lesson in ordered where lesson.id != next.id {
            for question in lesson.questions.shuffled(using: &random) { append(question) }
        }
        // Extreme attempts may need more than one path's bank; every extra question gets its lesson.
        for question in catalog.questions.shuffled(using: &random) { append(question) }
        var lessonIDs: [String] = []
        let deck = selected.shuffled(using: &random).map { question -> SessionQuestion in
            let lesson = catalog.lesson(forQuestion: question.id)!
            if !lessonIDs.contains(lesson.id) { lessonIDs.append(lesson.id) }
            return SessionQuestion(question: question, lessonID: lesson.id,
                isReview: progress.memories[question.id] != nil,
                optionOrder: Array(question.options.indices).shuffled(using: &random))
        }
        lessonIDs.sort { a, b in
            let first = catalog.lessons.first { $0.id == a }!
            let second = catalog.lessons.first { $0.id == b }!
            return first.pathID == second.pathID ? first.order < second.order : first.pathID < second.pathID
        }
        let key = request?.target.id ?? "practice"
        return LearningSession(id: UUID(), storageKey: key, target: request?.target, requestID: request?.id,
            grantMinutes: minutes, pathID: pathID, lessonIDs: lessonIDs, questions: deck)
    }

    @discardableResult
    static func grade(_ session: inout LearningSession, progress: inout LearningProgress, now: Date) -> LearningResult? {
        guard session.result == nil, session.readyForQuiz,
              session.questions.allSatisfy({ session.responses[$0.id] != nil }) else { return session.result }
        let correct = session.questions.filter { session.responses[$0.id] == $0.question.correctIndex }.count
        let passed = LessonLoad.passes(correct: correct, total: session.questions.count)
        for item in session.questions {
            var memory = progress.memories[item.id] ?? QuestionMemory()
            memory.record(correct: session.responses[item.id] == item.question.correctIndex, now: now)
            progress.memories[item.id] = memory
        }
        if passed {
            for id in session.lessonIDs {
                let items = session.questions.filter { $0.lessonID == id }
                if !items.isEmpty && items.allSatisfy({ session.responses[$0.id] == $0.question.correctIndex }) {
                    progress.completedLessonIDs.insert(id)
                }
            }
        }
        let result = LearningResult(id: session.id, completedAt: now, lessonIDs: session.lessonIDs,
            correct: correct, total: session.questions.count, passed: passed, practice: session.isPractice,
            activeSeconds: session.activeSeconds)
        session.result = result
        session.phase = "result"
        progress.results.append(result)
        progress.results = Array(progress.results.suffix(2000))
        progress.recentPathIDs.append(session.pathID)
        progress.recentPathIDs = Array(progress.recentPathIDs.suffix(8))
        return result
    }
}

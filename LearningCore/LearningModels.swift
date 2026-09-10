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
    var artwork: String?
    var category: String?
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
    // Optional additions keep every existing chapter and saved catalogue decodable.
    var kind: String?
    var image: String?
    var imageDescription: String?
    var caption: String?
    var reveal: String?
    var probe: LearningQuestion?
    var visual: LessonVisual?
}

struct LearningTopic: Codable, Identifiable {
    let id: String
    let pathID: String
    let title: String
    let hook: String
    var format: String?
}

struct LearningQuestion: Codable, Identifiable {
    let id: String
    let prompt: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
    var format: QuestionFormat?
    var correctIndices: [Int]?
    var correctOrder: [Int]?
    var pairs: [QuestionPair]?
    var acceptedAnswers: [String]?
    var numberAnswer: Double?
    var tolerance: Double?
    var unit: String?
    var hint: String?

    var kind: QuestionFormat { format ?? .singleChoice }
    var correctAnswer: String {
        switch kind {
        case .singleChoice: return options.indices.contains(correctIndex) ? options[correctIndex] : ""
        case .multipleChoice: return (correctIndices ?? []).map { options[$0] }.joined(separator: " · ")
        case .ordering: return (correctOrder ?? []).map { options[$0] }.joined(separator: " → ")
        case .matching: return (pairs ?? []).map { "\($0.left) → \($0.right)" }.joined(separator: "\n")
        case .recall, .cloze: return acceptedAnswers?.first ?? ""
        case .numeric:
            return (numberAnswer ?? 0).formatted(.number.precision(.fractionLength(0...3))) + (unit.map { " " + $0 } ?? "")
        }
    }

    var isValid: Bool {
        guard !id.isEmpty, !prompt.isEmpty, !explanation.isEmpty, Set(options).count == options.count else { return false }
        switch kind {
        case .singleChoice: return options.count >= 2 && options.indices.contains(correctIndex)
        case .multipleChoice:
            guard let indices = correctIndices else { return false }
            return options.count >= 3 && !indices.isEmpty && indices.count < options.count
                && Set(indices).count == indices.count && indices.allSatisfy(options.indices.contains)
        case .ordering:
            return options.count >= 3 && correctOrder?.count == options.count && Set(correctOrder ?? []) == Set(options.indices)
        case .matching:
            guard let pairs else { return false }
            return pairs.count >= 2 && options.count == pairs.count
                && Set(pairs.map(\.left)).count == pairs.count && Set(pairs.map(\.right)).count == pairs.count
        case .recall, .cloze: return !(acceptedAnswers ?? []).isEmpty && (acceptedAnswers ?? []).allSatisfy { !Self.normalized($0).isEmpty }
        case .numeric: return numberAnswer?.isFinite == true && (tolerance ?? 0) >= 0 && (tolerance ?? 0).isFinite
        }
    }

    func isComplete(_ response: QuestionResponse?) -> Bool {
        guard let response else { return false }
        switch kind {
        case .singleChoice: return response.indices.count == 1 && response.indices.allSatisfy(options.indices.contains)
        case .multipleChoice: return !response.indices.isEmpty && response.indices.allSatisfy(options.indices.contains)
        case .ordering: return response.indices.count == options.count && Set(response.indices) == Set(options.indices)
        case .matching:
            return response.matches.count == (pairs?.count ?? 0) && Set(response.matches.keys) == Set(options.indices)
                && Set(response.matches.values) == Set(options.indices)
        case .recall, .cloze: return !Self.normalized(response.text).isEmpty
        case .numeric: return Self.parseNumber(response.text) != nil
        }
    }

    func isCorrect(_ response: QuestionResponse?) -> Bool {
        guard isComplete(response), let response else { return false }
        switch kind {
        case .singleChoice: return response.indices == [correctIndex]
        case .multipleChoice: return Set(response.indices) == Set(correctIndices ?? [])
        case .ordering: return response.indices == correctOrder
        case .matching: return response.matches.allSatisfy { $0.key == $0.value }
        case .recall, .cloze: return (acceptedAnswers ?? []).contains { Self.normalized($0) == Self.normalized(response.text) }
        case .numeric:
            guard let actual = Self.parseNumber(response.text), let expected = numberAnswer else { return false }
            return abs(actual - expected) <= (tolerance ?? 0.001)
        }
    }

    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_CH"))
            .replacingOccurrences(of: "ß", with: "ss")
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
    static func parseNumber(_ text: String) -> Double? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "").replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
        guard let number = Double(clean), number.isFinite else { return nil }
        return number
    }
}

enum QuestionFormat: String, Codable, CaseIterable, Hashable {
    case singleChoice, multipleChoice, ordering, matching, recall, cloze, numeric
    var title: String {
        switch self {
        case .singleChoice: return "Fallentscheidung"
        case .multipleChoice: return "Mehrfachauswahl"
        case .ordering: return "Reihenfolge"
        case .matching: return "Zuordnen"
        case .recall: return "Aktiv abrufen"
        case .cloze: return "Lücke ergänzen"
        case .numeric: return "Selbst rechnen"
        }
    }
}
struct QuestionPair: Codable { let left: String; let right: String }
struct QuestionResponse: Codable, Equatable {
    var indices: [Int] = []
    var matches: [Int: Int] = [:]
    var text = ""
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
    var mission: String?
    var artwork: String?
    var topicID: String?
    var topicOrder: Int?
    var topicKey: String { topicID ?? id }
    var readingSeconds: Int {
        max(35, cards.map { ($0.text + " " + ($0.reveal ?? "")).split(separator: " ").count }.reduce(0, +) * 60 / 190)
    }
}

struct LearningCatalog: Codable {
    let version: Int
    let paths: [LearningPath]
    let lessons: [LearningLesson]
    var topics: [LearningTopic]?
    var questions: [LearningQuestion] { lessons.flatMap(\.questions) }
    func lesson(forQuestion id: String) -> LearningLesson? { lessons.first { $0.questions.contains { $0.id == id } } }
    func orderedLessons(in pathID: String) -> [LearningLesson] { lessons.filter { $0.pathID == pathID }.sorted { $0.order < $1.order } }
    var allTopics: [LearningTopic] {
        (topics ?? []) + lessons.filter { $0.topicID == nil }.map {
            LearningTopic(id: $0.id, pathID: $0.pathID, title: $0.title, hook: $0.objective, format: "Grundlage")
        }
    }
    func topic(_ id: String) -> LearningTopic? { allTopics.first { $0.id == id } }
    func chapters(in topicID: String) -> [LearningLesson] {
        lessons.filter { $0.topicKey == topicID }.sorted { ($0.topicOrder ?? $0.order) < ($1.topicOrder ?? $1.order) }
    }
    func topicID(forLesson id: String) -> String? { lessons.first { $0.id == id }?.topicKey }

    func validate() throws {
        let pathIDs = Set(paths.map(\.id))
        let probes = lessons.flatMap(\.cards).compactMap(\.probe)
        guard pathIDs.count == paths.count, Set(lessons.map(\.id)).count == lessons.count,
              Set(questions.map(\.id)).count == questions.count,
              Set(probes.map(\.id)).count == probes.count,
              Set(probes.map(\.id)).isDisjoint(with: Set(questions.map(\.id))),
              paths.allSatisfy({ orderedLessons(in: $0.id).count >= 3 }),
              lessons.allSatisfy({ pathIDs.contains($0.pathID) && $0.cards.count >= 2 && $0.questions.count >= 4 }),
              questions.allSatisfy({ $0.isValid }),
              Set(allTopics.map(\.id)).count == allTopics.count,
              allTopics.allSatisfy({ topic in
                  !topic.title.isEmpty && !topic.hook.isEmpty && !chapters(in: topic.id).isEmpty
                      && pathIDs.contains(topic.pathID)
              }),
              (topics ?? []).allSatisfy({ topic in
                  let topicChapters = chapters(in: topic.id)
                  return topicChapters.enumerated().allSatisfy { $0.element.topicOrder == $0.offset + 1 }
              }),
              lessons.allSatisfy({ lesson in
                  topic(lesson.topicKey)?.pathID == lesson.pathID && lesson.cards.allSatisfy { card in
                      !card.title.isEmpty && !card.text.isEmpty && (card.probe?.isValid ?? true)
                          && (card.image == nil || (card.imageDescription?.isEmpty == false && card.caption?.isEmpty == false))
                  }
              })
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
    var recentTopicIDs: [String]?
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
    var requiredQuestionIDs: [String: [String]]?
    var readLessonIDs: Set<String> = []
    var responses: [String: Int] = [:]
    // Optional so the entire v0.2 saved-session file remains decodable.
    var typedResponses: [String: QuestionResponse]?
    var reflectionNotes: [String: String] = [:]
    var activeSeconds = 0
    var phase = "learn"
    var result: LearningResult?
    var topicID: String?
    var readingEstimateSeconds: Int?
    var readerIndex: Int?
    var quizIndex: Int?
    var probeResponses: [String: QuestionResponse]?
    var revealedCardIDs: Set<String>?
    var estimatedSeconds: Int { max(60, questions.count * 20 + (readingEstimateSeconds ?? lessonIDs.count * 55)) }
    var readyForQuiz: Bool { Set(lessonIDs).isSubset(of: readLessonIDs) }
    var isPractice: Bool { target == nil }
    func response(for item: SessionQuestion) -> QuestionResponse? {
        if let response = typedResponses?[item.id] { return response }
        if let index = responses[item.id], item.question.kind == .singleChoice {
            return QuestionResponse(indices: [index])
        }
        return nil
    }
    var answeredCount: Int { questions.filter { $0.question.isComplete(response(for: $0)) }.count }
    var allAnswered: Bool { answeredCount == questions.count }
    func isCorrect(_ item: SessionQuestion) -> Bool { item.question.isCorrect(response(for: item)) }
}

enum LearningScheduler {
    static func storageKey(request: GateRequest?, path: String? = nil, lesson: String? = nil,
                           topic: String? = nil, reviewOnly: Bool = false) -> String {
        if let request { return request.target.id }
        if let lesson { return "chapter." + lesson }
        if let topic { return "topic." + topic }
        if reviewOnly { return "review" }
        if let path { return "path." + path }
        return "practice"
    }

    static func dueCount(_ progress: LearningProgress, at now: Date) -> Int {
        progress.memories.values.filter { $0.due <= now }.count
    }

    static func makeSession<R: RandomNumberGenerator>(
        catalog: LearningCatalog, progress: LearningProgress, request: GateRequest?,
        minutes: Int, consumed: Int, failures: Int, preferredPath: String? = nil,
        preferredLesson: String? = nil, preferredTopic: String? = nil, reviewOnly: Bool = false,
        remediation: [String] = [], remediationQuestionIDs: [String] = [], now: Date, random: inout R
    ) -> LearningSession {
        let focusedLesson = preferredLesson.flatMap { id in catalog.lessons.first { $0.id == id } }
        let count = focusedLesson?.questions.count ?? LessonLoad.questionCount(minutes: minutes, consumedMinutes: consumed, failures: failures)
        let due = catalog.questions.filter { (progress.memories[$0.id]?.due ?? .distantFuture) <= now }
            .sorted { (progress.memories[$0.id]?.due ?? now) < (progress.memories[$1.id]?.due ?? now) }
        // A topic is a concrete question/case, NOT a broad path such as philosophy.
        // Pick it once, before choosing questions. Due items and retries cannot cross it.
        let remediationTopic = remediation.first.flatMap { catalog.topicID(forLesson: $0) }
        let explicitTopic = focusedLesson?.topicKey ?? remediationTopic ?? preferredTopic
        let eligible = catalog.allTopics.filter { preferredPath == nil || $0.pathID == preferredPath }
        let available = eligible.isEmpty ? catalog.allTopics : eligible
        let overdue = due.first { question in
            guard let lesson = catalog.lesson(forQuestion: question.id) else { return false }
            return available.contains { $0.id == lesson.topicKey }
                && (reviewOnly || catalog.chapters(in: lesson.topicKey).flatMap(\.questions).count >= count)
        }.flatMap { catalog.lesson(forQuestion: $0.id)?.topicKey }
        let topicID: String
        if let explicitTopic, catalog.topic(explicitTopic) != nil {
            topicID = explicitTopic
        } else if let overdue {
            topicID = overdue
        } else {
            let sufficient = available.filter { catalog.chapters(in: $0.id).flatMap(\.questions).count >= count }
            var candidates = sufficient.isEmpty ? available : sufficient
            let freshPaths = candidates.filter { !progress.recentPathIDs.suffix(2).contains($0.pathID) }
            if !freshPaths.isEmpty { candidates = freshPaths }
            let freshTopics = candidates.filter { !(progress.recentTopicIDs ?? []).suffix(3).contains($0.id) }
            if !freshTopics.isEmpty { candidates = freshTopics }
            let unfinished = candidates.filter { catalog.chapters(in: $0.id).contains { !progress.completedLessonIDs.contains($0.id) } }
            if !unfinished.isEmpty { candidates = unfinished }
            // Prefer the new authored cases, but keep the foundation library available.
            let stories = candidates.filter { catalog.chapters(in: $0.id).count > 1 }
            if !stories.isEmpty { candidates = stories }
            topicID = candidates.randomElement(using: &random)!.id
        }
        let topic = catalog.topic(topicID)!
        let ordered = catalog.chapters(in: topicID)
        let scopedDue = due.filter { catalog.lesson(forQuestion: $0.id)?.topicKey == topicID }
        let gaps = ordered.flatMap(\.questions).filter { remediationQuestionIDs.contains($0.id) }
        var taught: [LearningLesson]
        if let focusedLesson {
            taught = [focusedLesson]
        } else if reviewOnly && !scopedDue.isEmpty {
            let ids = Set(scopedDue.prefix(count).compactMap { catalog.lesson(forQuestion: $0.id)?.id })
            taught = ordered.filter { ids.contains($0.id) }
        } else {
            let depth = min(ordered.count, minutes <= 5 ? 1 : minutes <= 10 ? 2 : minutes <= 15 ? 3 : 4)
            let next = ordered.firstIndex { !progress.completedLessonIDs.contains($0.id) } ?? 0
            let start = min(next, max(0, ordered.count - depth))
            taught = Array(ordered.dropFirst(start).prefix(depth))
            // Add earlier context / more practice ONLY inside the same case.
            for lesson in ordered where !taught.contains(where: { $0.id == lesson.id }) {
                if taught.flatMap(\.questions).count >= count { break }
                taught.append(lesson)
            }
            if let dueLesson = scopedDue.first.flatMap({ catalog.lesson(forQuestion: $0.id) }),
               !taught.contains(where: { $0.id == dueLesson.id }) { taught.append(dueLesson) }
            for lesson in ordered where gaps.contains(where: { gap in lesson.questions.contains { $0.id == gap.id } }) {
                if !taught.contains(where: { $0.id == lesson.id }) { taught.append(lesson) }
            }
            taught.sort { ($0.topicOrder ?? $0.order) < ($1.topicOrder ?? $1.order) }
        }
        var selected: [LearningQuestion] = []
        var seen = Set<String>()
        func append(_ question: LearningQuestion) {
            if selected.count < count && seen.insert(question.id).inserted { selected.append(question) }
        }
        // Spread formats and prioritise gaps, instead of completing a chapter after one lucky answer.
        func balanced(_ questions: [LearningQuestion]) -> [LearningQuestion] {
            let shuffled = questions.shuffled(using: &random).sorted {
                (progress.memories[$0.id]?.correctAttempts ?? 0) < (progress.memories[$1.id]?.correctAttempts ?? 0)
            }
            var kinds = Set<QuestionFormat>()
            let first = shuffled.filter { kinds.insert($0.kind).inserted }
            let ids = Set(first.map(\.id))
            return first + shuffled.filter { !ids.contains($0.id) }
        }
        if focusedLesson != nil {
            for question in balanced(taught[0].questions) { append(question) }
        } else if reviewOnly && !scopedDue.isEmpty {
            for question in scopedDue { append(question) }
        } else {
            let taughtIDs = Set(taught.map(\.id))
            for question in gaps { append(question) }
            for question in scopedDue.filter({ taughtIDs.contains(catalog.lesson(forQuestion: $0.id)!.id) }).prefix(max(1, count / 3)) { append(question) }
            let decks = taught.map { balanced($0.questions) }
            // Round-robin gives every taught chapter an assessment, not just the first.
            for index in 0..<(decks.map(\.count).max() ?? 0) {
                for deck in decks where deck.indices.contains(index) { append(deck[index]) }
            }
        }
        let lessonIDs = taught.map(\.id)
        let deck = selected.shuffled(using: &random).map { question -> SessionQuestion in
            let lesson = catalog.lesson(forQuestion: question.id)!
            return SessionQuestion(question: question, lessonID: lesson.id,
                isReview: progress.memories[question.id] != nil,
                optionOrder: Array(question.options.indices).shuffled(using: &random))
        }
        let key = storageKey(request: request, path: preferredPath, lesson: preferredLesson,
                             topic: preferredTopic, reviewOnly: reviewOnly)
        return LearningSession(id: UUID(), storageKey: key, target: request?.target, requestID: request?.id,
            grantMinutes: minutes, pathID: topic.pathID, lessonIDs: lessonIDs, questions: deck,
            requiredQuestionIDs: Dictionary(uniqueKeysWithValues: lessonIDs.map { id in
                (id, catalog.lessons.first { $0.id == id }!.questions.map(\.id))
            }), topicID: topicID,
            readingEstimateSeconds: taught.map { $0.readingSeconds + $0.cards.filter { $0.probe != nil }.count * 15 }.reduce(0, +))
    }

    @discardableResult
    static func grade(_ session: inout LearningSession, progress: inout LearningProgress, now: Date) -> LearningResult? {
        guard session.result == nil, session.readyForQuiz,
              session.allAnswered else { return session.result }
        let correct = session.questions.filter { session.isCorrect($0) }.count
        let passed = LessonLoad.passes(correct: correct, total: session.questions.count)
        for item in session.questions {
            var memory = progress.memories[item.id] ?? QuestionMemory()
            memory.record(correct: session.isCorrect(item), now: now)
            progress.memories[item.id] = memory
        }
        if passed {
            for id in session.lessonIDs {
                let items = session.questions.filter { $0.lessonID == id }
                // Require coverage of the full chapter across attempts. Retain existing completed IDs.
                let chapterQuestionIDs = session.requiredQuestionIDs?[id] ?? items.map(\.id)
                if !items.isEmpty && items.allSatisfy({ session.isCorrect($0) })
                    && chapterQuestionIDs.allSatisfy({ (progress.memories[$0]?.correctAttempts ?? 0) > 0 }) {
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
        if let topic = session.topicID {
            progress.recentTopicIDs = Array(((progress.recentTopicIDs ?? []) + [topic]).suffix(8))
        }
        return result
    }
}

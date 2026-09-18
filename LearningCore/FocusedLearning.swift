import Foundation

/// Version 8: the unit of depth is an authored chapter, never an idle timer.
enum FocusedLearning {
    static func chapterCount(for minutes: Int) -> Int {
        switch minutes {
        case ...5: return 1
        case ...10: return 2
        case ...15: return 3
        case ...20: return 4
        default: return 5
        }
    }

    static func plan(catalog: LearningCatalog, progress: LearningProgress, topicID: String,
                     minutes: Int, offeredChapterID: String? = nil) -> [LearningLesson] {
        let chapters = catalog.chapters(in: topicID)
        guard !chapters.isEmpty else { return [] }
        let next = chapters.firstIndex { $0.id == offeredChapterID }
            ?? chapters.firstIndex { !progress.hasFinished($0) } ?? 0
        let count = min(chapters.count, chapterCount(for: minutes))
        // At a course's end, bring earlier context back instead of mixing subjects
        // or charging for five chapters while teaching only one.
        let start = min(next, chapters.count - count)
        return Array(chapters[start..<(start + count)])
    }

    static func makeSession<R: RandomNumberGenerator>(catalog: LearningCatalog, progress: LearningProgress,
        request: GateRequest?, minutes: Int, failures: Int, preferredPath: String?, preferredLesson: String?,
        preferredTopic: String?, reviewOnly: Bool, remediation: [String], remediationQuestionIDs: [String],
        now: Date, random: inout R) -> LearningSession {
        let due = catalog.questions.filter { (progress.skillMemories?[$0.skillID ?? $0.id]?.due ?? .distantFuture) <= now }
            .sorted { (progress.skillMemories?[$0.skillID ?? $0.id]?.due ?? now) < (progress.skillMemories?[$1.skillID ?? $1.id]?.due ?? now) }
        let focused = preferredLesson.flatMap { id in catalog.lessons.first { $0.id == id } }
        let previousTopic = remediation.first.flatMap { catalog.topicID(forLesson: $0) }
        let explicit = previousTopic ?? focused?.topicKey ?? preferredTopic
        let possible = catalog.allTopics.filter { preferredPath == nil || $0.pathID == preferredPath }
        let pool = possible.isEmpty ? catalog.allTopics : possible
        let fresh = pool.filter { progress.nextChapter(in: $0.id, catalog: catalog) != nil }
        let recent = (fresh.isEmpty ? pool : fresh).filter { !(progress.recentTopicIDs ?? []).suffix(3).contains($0.id) }
        let dueTopic = reviewOnly ? due.first.flatMap { catalog.lesson(forQuestion: $0.id)?.topicKey } : nil
        let topicID = explicit.flatMap { catalog.topic($0)?.id } ?? dueTopic
            ?? (recent.isEmpty ? (fresh.isEmpty ? pool : fresh) : recent).randomElement(using: &random)!.id
        let topic = catalog.topic(topicID)!
        let ordered = catalog.chapters(in: topicID)
        let scopedDue = due.filter { catalog.lesson(forQuestion: $0.id)?.topicKey == topicID }
        let offer = progress.topicOffers?[LearningProgress.offerKey(request: request)]
        let offered = offer?.selectedTopicID == topicID ? offer?.chapterIDs?[topicID] : nil
        let taught: [LearningLesson]
        if !remediation.isEmpty {
            // Keep the full original scope on retry, not only the easiest remaining question.
            taught = ordered.filter { remediation.contains($0.id) }
        } else if let focused, request == nil { taught = [focused] }
        else if reviewOnly && request == nil && !scopedDue.isEmpty {
            let ids = Set(scopedDue.compactMap { catalog.lesson(forQuestion: $0.id)?.id })
            taught = Array(ordered.filter { ids.contains($0.id) }.prefix(5))
        } else {
            taught = plan(catalog: catalog, progress: progress, topicID: topicID,
                          minutes: minutes, offeredChapterID: offered)
        }
        let key = LearningScheduler.storageKey(request: request, path: preferredPath, lesson: preferredLesson,
                                               topic: preferredTopic, reviewOnly: reviewOnly)
        let priorIDs = Set(progress.sessions[key]?.questions.map(\.id) ?? [])
        let dueSkills = Set(scopedDue.map { $0.skillID ?? $0.id })
        var selected: [LearningQuestion] = []
        for lesson in taught {
            let families = Dictionary(grouping: lesson.questions, by: { $0.skillID ?? $0.id })
            for skill in families.keys.sorted() {
                if reviewOnly && request == nil && !scopedDue.isEmpty && !dueSkills.contains(skill) { continue }
                let variants = families[skill]!
                let alternatives = variants.filter { !priorIDs.contains($0.id) }
                selected.append((alternatives.isEmpty ? variants : alternatives).randomElement(using: &random)!)
            }
        }
        let deck = selected.shuffled(using: &random).map { question -> SessionQuestion in
            var order = Array(question.options.indices).shuffled(using: &random)
            // Ordering should never arrive already solved by chance.
            if question.kind == .ordering, order == question.correctOrder, order.count > 1 {
                order.swapAt(0, 1)
            }
            return SessionQuestion(question: question, lessonID: catalog.lesson(forQuestion: question.id)!.id,
                isReview: progress.skillMemories?[question.skillID ?? question.id] != nil, optionOrder: order)
        }
        let taughtIDs = Set(taught.map(\.id))
        let repairs = Array(catalog.questions.filter {
            remediationQuestionIDs.contains($0.id)
                && taughtIDs.contains(catalog.lesson(forQuestion: $0.id)?.id ?? "")
        }.prefix(5))
        let cardIDs = repairs.map { "repair." + $0.id } + taught.flatMap { lesson in
            lesson.cards.indices.map { lesson.id + ".step.\($0)" }
        }
        let reveals = Set(taught.flatMap { lesson in lesson.cards.indices.compactMap { index in
            lesson.cards[index].reveal == nil ? nil : lesson.id + ".step.\(index)"
        } })
        let repairSeconds = repairs.reduce(0) { $0 + ($1.prompt + " " + $1.explanation).split(separator: " ").count * 60 / 190 }
        return LearningSession(id: UUID(), storageKey: key, target: request?.target, requestID: request?.id,
            grantMinutes: minutes, pathID: topic.pathID, lessonIDs: taught.map(\.id), questions: deck,
            requiredQuestionIDs: Dictionary(uniqueKeysWithValues: taught.map { lesson in
                (lesson.id, deck.filter { $0.lessonID == lesson.id }.map(\.id))
            }), reflectionNotes: (progress.savedNotes ?? [:]).filter { taughtIDs.contains($0.key) },
            topicID: topicID, readingEstimateSeconds: taught.reduce(repairSeconds) { $0 + $1.readingSeconds },
            catalogVersion: catalog.version, inlineQuestionIDs: [], lockedQuestionIDs: [],
            requiredCardIDs: cardIDs, readCardIDs: [], requiredRevealCardIDs: reveals,
            repairQuestions: repairs, reviewLessonIDs: Set(taught.filter { progress.hasFinished($0) }.map(\.id)))
    }
}

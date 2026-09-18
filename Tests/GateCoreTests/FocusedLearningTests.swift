import XCTest
@testable import GateCore

/// v8 behavior; the older suites deliberately retain v7 as a migration fixture.
final class FocusedLearningTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let target = GateTarget(kind: .application, tokenData: Data("focused-app".utf8))

    private func round(_ catalog: LearningCatalog, minutes: Int = 5, topic: String = "deep.cash",
                       progress: LearningProgress = .init(), remediation: [String] = [],
                       gaps: [String] = [], seed: UInt64 = 1) -> LearningSession {
        var random = SeededRandom(state: seed)
        return LearningScheduler.makeSession(catalog: catalog, progress: progress,
            request: GateRequest(target: target), minutes: minutes, consumed: 30,
            failures: remediation.isEmpty ? 0 : 1, preferredTopic: topic,
            remediation: remediation, remediationQuestionIDs: gaps, now: now, random: &random)
    }

    private func read(_ session: inout LearningSession) {
        for id in session.requiredCardIDs ?? [] {
            if session.revealedCardIDs == nil { session.revealedCardIDs = [] }
            session.revealedCardIDs?.insert(id)
            XCTAssertTrue(session.completeReadingCard(id), id)
        }
        session.readLessonIDs = Set(session.lessonIDs)
    }

    private func wrong(_ question: LearningQuestion) -> QuestionResponse {
        switch question.kind {
        case .singleChoice: return .init(indices: [(question.correctIndex + 1) % question.options.count])
        case .numeric: return .init(text: String(question.numberAnswer! + 1000))
        case .recall, .cloze: return .init(text: "unbekannt")
        case .matching: return .init(matches: Dictionary(uniqueKeysWithValues:
            question.options.indices.map { ($0, ($0 + 1) % question.options.count) }))
        case .ordering: return .init(indices: Array(question.correctOrder!.reversed()))
        case .multipleChoice: return .init(indices: Array(question.options.indices))
        }
    }

    func testActiveCatalogAndPreservedReferenceAreDifferentCompleteEditions() throws {
        let catalog = try LearningCatalog.packageCatalog()
        try catalog.validate()
        XCTAssertEqual(catalog.version, 8)
        XCTAssertEqual(catalog.allTopics.count, 10)
        XCTAssertEqual(catalog.lessons.count, 50)
        XCTAssertEqual(catalog.questions.count, 300)
        XCTAssertEqual(Set(catalog.questions.map(\.kind)), [.singleChoice, .numeric, .recall, .matching, .ordering])
        let reference = try LearningCatalog.legacyCatalog()
        XCTAssertEqual(reference.version, 7)
        XCTAssertEqual(reference.lessons.count, 100)
        XCTAssertTrue(Set(reference.lessons.map(\.id)).isDisjoint(with: Set(catalog.lessons.map(\.id))))
        for lesson in catalog.lessons {
            XCTAssertEqual(lesson.assessmentCount, 3)
            XCTAssertEqual(lesson.questions.count, 6)
            XCTAssertTrue(lesson.cards.allSatisfy { $0.probe == nil })
            XCTAssertTrue(lesson.cards.contains { $0.reveal != nil })
        }
    }

    func testEveryAssessmentVariantAcceptsItsAnswerAndRejectsWrongOrMissingInput() throws {
        for question in try LearningCatalog.packageCatalog().questions {
            XCTAssertTrue(question.isValid, question.id)
            XCTAssertTrue(question.isCorrect(correctResponse(question)), question.id)
            XCTAssertTrue(question.isComplete(wrong(question)), question.id)
            XCTAssertFalse(question.isCorrect(wrong(question)), question.id)
            XCTAssertFalse(question.isComplete(nil), question.id)
            XCTAssertFalse(question.isCorrect(.init()), question.id)
        }
    }

    func testEveryLongerGrantAddsReadingAndAssessmentWithinOneTopic() throws {
        let catalog = try LearningCatalog.packageCatalog()
        for topic in catalog.allTopics {
            var previousReading = 0
            for (index, minutes) in [5, 10, 15, 20, 30].enumerated() {
                for seed in UInt64(1)...UInt64(8) {
                    let session = round(catalog, minutes: minutes, topic: topic.id, seed: seed)
                    XCTAssertEqual(session.lessonIDs.count, index + 1)
                    XCTAssertEqual(session.questions.count, (index + 1) * 3)
                    XCTAssertEqual(Set(session.lessonIDs.compactMap { catalog.topicID(forLesson: $0) }), [topic.id])
                    XCTAssertEqual(Set(session.questions.map(\.lessonID)), Set(session.lessonIDs))
                    XCTAssertEqual(Set(session.questions.compactMap { $0.question.skillID }).count, session.questions.count)
                    XCTAssertGreaterThan(session.readingEstimateSeconds!, previousReading)
                    XCTAssertEqual(session.requiredCardIDs?.count, (index + 1) * 3)
                    for item in session.questions where item.question.kind == .ordering {
                        XCTAssertNotEqual(item.optionOrder, item.question.correctOrder)
                    }
                }
                previousReading = round(catalog, minutes: minutes, topic: topic.id).readingEstimateSeconds!
            }
        }
    }

    func testPagesAndWorkedExampleMustBeCompletedInOrderBeforeGrading() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var session = round(catalog)
        let pages = try XCTUnwrap(session.requiredCardIDs)
        XCTAssertFalse(session.completeReadingCard(pages.last!))
        for item in session.questions { session.setAnswer(correctResponse(item.question), for: item.id) }
        session.readLessonIDs = Set(session.lessonIDs)
        var progress = LearningProgress()
        XCTAssertNil(LearningScheduler.grade(&session, progress: &progress, now: now))
        XCTAssertTrue(progress.results.isEmpty)
        XCTAssertTrue(session.completeReadingCard(pages[0]))
        XCTAssertTrue(session.completeReadingCard(pages[1]))
        XCTAssertFalse(session.completeReadingCard(pages[2]))
        session.revealedCardIDs = [pages[2]]
        XCTAssertTrue(session.completeReadingCard(pages[2]))
        XCTAssertTrue(session.readyForQuiz)
        XCTAssertTrue(try XCTUnwrap(LearningScheduler.grade(&session, progress: &progress, now: now)).passed)
        XCTAssertFalse(session.completeReadingCard(pages[0]))
        _ = LearningScheduler.grade(&session, progress: &progress, now: now)
        XCTAssertEqual(progress.results.count, 1)
        XCTAssertTrue(progress.hasCompleted(catalog.chapters(in: "deep.cash")[0]))
    }

    func testEightyPercentCannotHideOneEntirelyFailedChapter() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var session = round(catalog, minutes: 30)
        read(&session)
        for item in session.questions {
            session.setAnswer(item.lessonID == session.lessonIDs.last ? wrong(item.question) : correctResponse(item.question), for: item.id)
        }
        var progress = LearningProgress()
        let result = try XCTUnwrap(LearningScheduler.grade(&session, progress: &progress, now: now))
        XCTAssertEqual(result.correct, 12)
        XCTAssertEqual(result.total, 15)
        XCTAssertFalse(result.passed)
        XCTAssertTrue(progress.completedLessonIDs.isEmpty)
    }

    func testEightyPercentWithAtLeastTwoCorrectPerChapterCanPass() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var session = round(catalog, minutes: 30)
        read(&session)
        let mistakes = Set(session.lessonIDs.prefix(3).compactMap { id in session.questions.first { $0.lessonID == id }?.id })
        for item in session.questions {
            session.setAnswer(mistakes.contains(item.id) ? wrong(item.question) : correctResponse(item.question), for: item.id)
        }
        var progress = LearningProgress()
        XCTAssertTrue(try XCTUnwrap(LearningScheduler.grade(&session, progress: &progress, now: now)).passed)
        XCTAssertTrue(catalog.chapters(in: "deep.cash").allSatisfy { progress.hasFinished($0) })
        XCTAssertEqual(progress.completedLessonIDs.count, 2)
    }

    func testRetryRetainsScopeChangesEveryVariantAndAddsOnlyRelevantRepairs() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var first = round(catalog, minutes: 20)
        read(&first)
        for item in first.questions { first.setAnswer(wrong(item.question), for: item.id) }
        var progress = LearningProgress()
        _ = LearningScheduler.grade(&first, progress: &progress, now: now)
        progress.sessions[first.storageKey] = first
        let unrelated = catalog.chapters(in: "deep.heat")[0].questions[0].id
        let retry = round(catalog, minutes: 20, progress: progress, remediation: first.lessonIDs,
                          gaps: first.questions.map(\.id) + [unrelated])
        XCTAssertEqual(retry.lessonIDs, first.lessonIDs)
        XCTAssertEqual(retry.questions.count, first.questions.count)
        XCTAssertEqual(retry.grantMinutes, first.grantMinutes)
        XCTAssertTrue(Set(retry.questions.map(\.id)).isDisjoint(with: Set(first.questions.map(\.id))))
        XCTAssertEqual(retry.repairQuestions?.count, 5)
        XCTAssertFalse(retry.repairQuestions!.contains { $0.id == unrelated })
        XCTAssertGreaterThan(retry.requiredCardIDs!.count, first.requiredCardIDs!.count)
        XCTAssertGreaterThan(retry.readingEstimateSeconds!, first.readingEstimateSeconds!)
        XCTAssertEqual(retry.requiredCardIDs?.first, "repair." + retry.repairQuestions![0].id)
    }

    func testEndOfCourseUsesLabelledContextAndPreviewMatchesPlan() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var progress = LearningProgress()
        var first = round(catalog, minutes: 20)
        read(&first)
        for item in first.questions { first.setAnswer(correctResponse(item.question), for: item.id) }
        _ = LearningScheduler.grade(&first, progress: &progress, now: now)
        let session = round(catalog, minutes: 15, progress: progress)
        XCTAssertEqual(session.lessonIDs, ["deep.cash.3", "deep.cash.4", "deep.cash.5"])
        XCTAssertEqual(session.reviewLessonIDs, ["deep.cash.3", "deep.cash.4"])
        XCTAssertEqual(FocusedLearning.plan(catalog: catalog, progress: progress, topicID: "deep.cash",
            minutes: 15, offeredChapterID: "deep.cash.5").map(\.id), session.lessonIDs)
    }

    func testSpacedReviewUsesSkillsSoAnAlternateClearsTheSameDueItem() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var first = round(catalog)
        read(&first)
        for item in first.questions { first.setAnswer(correctResponse(item.question), for: item.id) }
        var progress = LearningProgress()
        _ = LearningScheduler.grade(&first, progress: &progress, now: now)
        let original = first.questions[0]
        let skill = original.question.skillID!
        progress.skillMemories?[skill]?.due = now.addingTimeInterval(-1)
        progress.sessions["review"] = first
        var random = SeededRandom(state: 9)
        var review = LearningScheduler.makeSession(catalog: catalog, progress: progress, request: nil,
            minutes: 5, consumed: 30, failures: 0, reviewOnly: true, now: now, random: &random)
        XCTAssertEqual(review.questions.count, 1)
        XCTAssertEqual(review.questions[0].question.skillID, skill)
        XCTAssertNotEqual(review.questions[0].id, original.id)
        read(&review)
        review.setAnswer(correctResponse(review.questions[0].question), for: review.questions[0].id)
        _ = LearningScheduler.grade(&review, progress: &progress, now: now)
        XCTAssertGreaterThan(progress.skillMemories![skill]!.due, now)
        XCTAssertEqual(progress.skillMemories![skill]!.streak, 1, "Same-day variants do not fabricate spaced mastery")
    }

    func testUpgradeKeepsOldHistoryNotesAndEarnedGrantButRetiresOldUnfinishedDeck() throws {
        let legacy = try LearningCatalog.legacyCatalog()
        var random = SeededRandom(state: 1)
        var old = LearningScheduler.makeSession(catalog: legacy, progress: .init(), request: GateRequest(target: target),
            minutes: 5, consumed: 30, failures: 0, now: now, random: &random)
        old.reflectionNotes = [old.lessonIDs[0]: "Eigene Notiz"]
        var progress = LearningProgress()
        progress.sessions["unfinished"] = old
        old.readLessonIDs = Set(old.lessonIDs)
        for item in old.questions {
            old.setAnswer(correctResponse(item.question), for: item.id)
            if old.inlineQuestionIDs!.contains(item.id) { old.submitInlineQuestion(item.id, cardID: item.lessonID + ".step.3") }
        }
        XCTAssertTrue(try XCTUnwrap(LearningScheduler.grade(&old, progress: &progress, now: now)).passed)
        progress.sessions["earned"] = old
        let catalog = try LearningCatalog.packageCatalog()
        progress.reconcileCatalog(catalog)
        XCTAssertNil(progress.sessions["unfinished"])
        XCTAssertEqual(progress.sessions["earned"]?.id, old.id)
        XCTAssertEqual(progress.savedNotes?[old.lessonIDs[0]], "Eigene Notiz")
        XCTAssertEqual(progress.results.count, 1)
        XCTAssertTrue(catalog.lessons.allSatisfy { !progress.hasFinished($0) })
    }

    @MainActor
    func testStoreResizesUnfinishedRoundPreservesReadingAndRestoresExactDeck() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("learning.json")
        let catalog = try LearningCatalog.packageCatalog()
        let request = GateRequest(target: target)
        let store = LearningStore(fileURL: file, suppliedCatalog: catalog)
        store.prepare(request: request, minutes: 5, consumed: 30, failures: 0)
        let topic = try XCTUnwrap(store.choice?.offer.topicIDs.first)
        XCTAssertEqual(store.offeredChapters(for: topic).count, 1)
        store.choose(topic)
        let short = try XCTUnwrap(store.session)
        store.markRead(short.lessonIDs[0])
        store.setPhase("quiz")
        XCTAssertEqual(store.session?.phase, "learn")
        XCTAssertTrue(store.session!.readLessonIDs.isEmpty)
        store.markCardRead(short.requiredCardIDs![0])
        store.note("Meine Erklärung", for: short.lessonIDs[0])
        store.suspend()
        store.prepare(request: request, minutes: 30, consumed: 30, failures: 0)
        let full = try XCTUnwrap(store.session)
        XCTAssertNotEqual(full.id, short.id)
        XCTAssertEqual(full.topicID, topic)
        XCTAssertEqual(full.grantMinutes, 30)
        XCTAssertEqual(full.lessonIDs.count, 5)
        XCTAssertEqual(full.questions.count, 15)
        XCTAssertEqual(full.readCardIDs, [short.requiredCardIDs![0]])
        XCTAssertEqual(full.reflectionNotes[short.lessonIDs[0]], "Meine Erklärung")
        store.suspend()
        let cold = LearningStore(fileURL: file, suppliedCatalog: catalog)
        cold.prepare(request: request, minutes: 30, consumed: 30, failures: 0)
        XCTAssertEqual(cold.session?.id, full.id)
        XCTAssertEqual(cold.session?.questions.map(\.optionOrder), full.questions.map(\.optionOrder))
        XCTAssertEqual(cold.session?.readCardIDs, full.readCardIDs)
        XCTAssertNil(cold.error)
    }

    @MainActor
    func testFailedOrPassedShortDeckCannotBeRelabelledAsThirtyMinuteReward() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let catalog = try LearningCatalog.packageCatalog()
        let request = GateRequest(target: target)
        let store = LearningStore(fileURL: folder.appendingPathComponent("learning.json"), suppliedCatalog: catalog)
        store.begin(request: request, minutes: 5, consumed: 30, failures: 0, topic: "deep.cash")
        var session = try XCTUnwrap(store.session)
        read(&session)
        for item in session.questions { session.setAnswer(wrong(item.question), for: item.id) }
        store.session = session
        XCTAssertFalse(try XCTUnwrap(store.grade()).passed)
        store.suspend()
        store.prepare(request: request, minutes: 30, consumed: 30, failures: 1)
        XCTAssertEqual(store.session?.grantMinutes, 5)
        XCTAssertEqual(store.session?.lessonIDs.count, 1)
        session = try XCTUnwrap(store.session)
        read(&session)
        for item in session.questions { session.setAnswer(correctResponse(item.question), for: item.id) }
        store.session = session
        XCTAssertTrue(try XCTUnwrap(store.grade()).passed)
        let passedID = store.session?.id
        store.suspend()
        store.prepare(request: request, minutes: 30, consumed: 30, failures: 1)
        XCTAssertEqual(store.session?.id, passedID)
        XCTAssertEqual(store.session?.grantMinutes, 5)
    }
}

import XCTest
@testable import GateCore

final class LearningRefreshTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private func session(topic: String = "case.cash", progress: LearningProgress = .init(), review: Bool = false) throws -> LearningSession {
        var random = SeededRandom(state: 17)
        return LearningScheduler.makeSession(catalog: try .legacyCatalog(), progress: progress, request: nil,
            minutes: 30, consumed: 999, failures: 99, preferredTopic: topic, reviewOnly: review, now: now, random: &random)
    }

    func testInlineAnswerCountsOnceAndCannotBeChangedAfterFeedback() throws {
        var round = try session()
        let inline = round.questions.first { round.inlineQuestionIDs!.contains($0.id) }!
        let wrong = QuestionResponse(indices: [(inline.question.correctIndex + 1) % inline.question.options.count])
        round.setAnswer(wrong, for: inline.id)
        XCTAssertTrue(round.submitInlineQuestion(inline.id, cardID: "case.cash.step.2"))
        round.setAnswer(correctResponse(inline.question), for: inline.id)
        XCTAssertEqual(round.response(for: inline), wrong)
        XCTAssertFalse(round.submitInlineQuestion(inline.id, cardID: "case.cash.step.2"))
        XCTAssertFalse(round.finalQuestions.contains { $0.id == inline.id })
        for question in round.finalQuestions { round.setAnswer(correctResponse(question.question), for: question.id) }
        round.readLessonIDs = Set(round.lessonIDs)
        var progress = LearningProgress()
        let result = try XCTUnwrap(LearningScheduler.grade(&round, progress: &progress, now: now))
        XCTAssertEqual(result.total, round.questions.count)
        XCTAssertEqual(result.correct, round.questions.count - 1)
        XCTAssertFalse(result.passed)
        XCTAssertEqual(progress.memories[inline.id]?.attempts, 1)
        XCTAssertEqual(progress.memories[inline.id]?.correctAttempts, 0)
        XCTAssertEqual(progress.memories[inline.id]?.due, now.addingTimeInterval(600))
        _ = LearningScheduler.grade(&round, progress: &progress, now: now)
        XCTAssertEqual(progress.results.count, 1)
    }

    func testSkippingInlineSubmissionCannotPassEvenWhenAllAnswersAreFilled() throws {
        var round = try session()
        round.readLessonIDs = Set(round.lessonIDs)
        for item in round.questions { round.setAnswer(correctResponse(item.question), for: item.id) }
        XCTAssertTrue(round.allAnswered)
        XCTAssertFalse(round.readyForQuiz)
        var progress = LearningProgress()
        XCTAssertNil(LearningScheduler.grade(&round, progress: &progress, now: now))
        XCTAssertTrue(progress.memories.isEmpty)
    }

    func testMissingOrUnselectedQuestionCannotBeLocked() throws {
        var round = try session()
        let inline = round.inlineQuestionIDs!.first!
        XCTAssertFalse(round.submitInlineQuestion(inline, cardID: "card"))
        let final = round.questions.first { !round.inlineQuestionIDs!.contains($0.id) }!
        round.setAnswer(correctResponse(final.question), for: final.id)
        XCTAssertFalse(round.submitInlineQuestion(final.id, cardID: "card"))
        round.setAnswer(.init(indices: [0]), for: "unknown")
        XCTAssertNil(round.typedResponses?["unknown"])
        XCTAssertTrue(round.lockedQuestionIDs!.isEmpty)
    }

    func testLockedAnswerAndFinalDeckSurviveRestart() throws {
        var round = try session(topic: "case.rates")
        let item = round.questions.first { round.inlineQuestionIDs!.contains($0.id) }!
        round.setAnswer(correctResponse(item.question), for: item.id)
        round.submitInlineQuestion(item.id, cardID: item.lessonID + ".step.2")
        round.readerIndex = 2
        let restored = try JSONDecoder().decode(LearningSession.self, from: JSONEncoder().encode(round))
        XCTAssertEqual(restored.lockedQuestionIDs, round.lockedQuestionIDs)
        XCTAssertEqual(restored.inlineQuestionIDs, round.inlineQuestionIDs)
        XCTAssertEqual(restored.typedResponses, round.typedResponses)
        XCTAssertEqual(restored.finalQuestions.map(\.id), round.finalQuestions.map(\.id))
        XCTAssertEqual(restored.questions.map(\.optionOrder), round.questions.map(\.optionOrder))
        XCTAssertEqual(restored.readerIndex, 2)
    }

    func testDueReviewCanFinishEntirelyWithItsOneInlineQuestion() throws {
        let catalog = try LearningCatalog.legacyCatalog()
        let probe = catalog.chapters(in: "case.cash")[0].cards.compactMap(\.probe)[0]
        var progress = LearningProgress()
        progress.memories[probe.id] = QuestionMemory(due: now.addingTimeInterval(-1))
        var round = try session(progress: progress, review: true)
        round.setAnswer(correctResponse(probe), for: probe.id)
        round.submitInlineQuestion(probe.id, cardID: "case.cash.step.2")
        round.readLessonIDs = Set(round.lessonIDs)
        XCTAssertTrue(round.finalQuestions.isEmpty)
        XCTAssertTrue(round.readyForQuiz)
        XCTAssertTrue(try XCTUnwrap(LearningScheduler.grade(&round, progress: &progress, now: now)).passed)
        XCTAssertEqual(progress.results[0].total, 1)
        XCTAssertFalse(progress.completedLessonIDs.contains("case.cash.1"))
    }

    func testDueReviewWithOnlyFinalQuestionDoesNotRequireAnAbsentInlineProbe() throws {
        let catalog = try LearningCatalog.legacyCatalog()
        let question = catalog.chapters(in: "case.cash")[0].questions[1]
        var progress = LearningProgress()
        progress.memories[question.id] = QuestionMemory(due: now.addingTimeInterval(-1))
        var round = try session(progress: progress, review: true)
        round.readLessonIDs = Set(round.lessonIDs)
        XCTAssertTrue(round.inlineQuestionIDs!.isEmpty)
        XCTAssertTrue(round.readyForQuiz)
        XCTAssertEqual(round.finalQuestions.map(\.id), [question.id])
    }

    func testCatalogUpgradePreservesEarnedResultHistoryAndWriting() throws {
        var unfinished = try session()
        unfinished.catalogVersion = 4
        unfinished.reflectionNotes = ["case.cash.1": "Mein eigener Vergleich"]
        var earned = try session(topic: "case.recall")
        earned.catalogVersion = 4
        earned.readLessonIDs = Set(earned.lessonIDs)
        earned.lockedQuestionIDs = earned.inlineQuestionIDs
        earned.typedResponses = Dictionary(uniqueKeysWithValues: earned.questions.map { ($0.id, correctResponse($0.question)) })
        var progress = LearningProgress()
        let result = try XCTUnwrap(LearningScheduler.grade(&earned, progress: &progress, now: now))
        progress.sessions = [unfinished.storageKey: unfinished, earned.storageKey: earned]
        let oldMemories = Set(progress.memories.keys)
        progress.reconcileCatalogVersion(6)
        XCTAssertNil(progress.sessions[unfinished.storageKey])
        XCTAssertEqual(progress.sessions[earned.storageKey]?.result?.id, result.id)
        XCTAssertEqual(progress.results.count, 1)
        XCTAssertEqual(Set(progress.memories.keys), oldMemories)
        XCTAssertTrue(progress.completedLessonIDs.contains("case.recall.1"))
        XCTAssertEqual(try session(progress: progress).reflectionNotes["case.cash.1"], "Mein eigener Vergleich")
        let restored = try JSONDecoder().decode(LearningProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(restored.savedNotes, progress.savedNotes)
    }

    func testNewQuestionsDoNotInheritMasteryOfReplacedQuestionIDs() throws {
        let catalog = try LearningCatalog.legacyCatalog()
        XCTAssertTrue(catalog.questions.allSatisfy { $0.id.contains(".v6.q") || $0.id.contains(".v7.q") })
        XCTAssertFalse(catalog.questions.contains { $0.kind == .numeric })
        XCTAssertTrue(catalog.lessons.flatMap(\.cards).allSatisfy { $0.image == nil })
        let media = catalog.lessons.flatMap(\.cards).compactMap(\.media)
        XCTAssertEqual(Set(media.map(\.url)).count, 15)
        XCTAssertTrue(media.allSatisfy { $0.alt?.isEmpty == false && $0.license?.isEmpty == false })
    }

    func testDayPhaseUsesLocalCalendarAndEveryBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 7200)!
        for (hour, expected) in [(0, GateDayPhase.night), (4, .night), (5, .morning), (8, .morning),
                                 (9, .day), (16, .day), (17, .evening), (20, .evening), (21, .night), (23, .night)] {
            let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: hour))!
            XCTAssertEqual(GateDayPhase.at(date, calendar: calendar), expected, "Local hour \(hour)")
        }
    }
}

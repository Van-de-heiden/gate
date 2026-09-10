import XCTest
@testable import GateCore

func correctResponse(_ question: LearningQuestion) -> QuestionResponse {
    switch question.kind {
    case .singleChoice: return QuestionResponse(indices: [question.correctIndex])
    case .multipleChoice: return QuestionResponse(indices: question.correctIndices!)
    case .ordering: return QuestionResponse(indices: question.correctOrder!)
    case .matching: return QuestionResponse(matches: Dictionary(uniqueKeysWithValues: question.options.indices.map { ($0, $0) }))
    case .recall, .cloze: return QuestionResponse(text: question.acceptedAnswers!.first!)
    case .numeric: return QuestionResponse(text: String(question.numberAnswer!))
    }
}

final class LearningExpansionTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testAllPublishedQuestionsHaveGradableAnswersAndRejectMissingAnswers() throws {
        let catalog = try LearningCatalog.packageCatalog()
        XCTAssertEqual(Set(catalog.questions.map(\.kind)), Set(QuestionFormat.allCases))
        for question in catalog.questions {
            XCTAssertTrue(question.isValid, question.id)
            XCTAssertTrue(question.isCorrect(correctResponse(question)), question.id)
            XCTAssertFalse(question.isCorrect(nil), question.id)
            XCTAssertFalse(question.isCorrect(QuestionResponse()), question.id)
        }
    }

    func testWrongAnswersDoNotReceiveCreditInAnyFormat() throws {
        let catalog = try LearningCatalog.packageCatalog()
        for question in catalog.questions {
            var answer = correctResponse(question)
            switch question.kind {
            case .singleChoice: answer.indices = [(question.correctIndex + 1) % question.options.count]
            case .multipleChoice: answer.indices = Array(question.options.indices)
            case .ordering: answer.indices.reverse()
            case .matching:
                answer.matches = Dictionary(uniqueKeysWithValues: question.options.indices.map { ($0, ($0 + 1) % question.options.count) })
            case .recall, .cloze: answer.text = "Nicht " + answer.text
            case .numeric: answer.text = String(question.numberAnswer! + 100)
            }
            XCTAssertFalse(question.isCorrect(answer), question.id)
        }
    }

    func testNumericalInputSupportsSwissAndGermanFormattingWithoutAcceptingGarbage() throws {
        let question = try LearningCatalog.packageCatalog().questions.first { $0.numberAnswer == 1102.5 }!
        for value in ["1’102,50", "1'102.5", "1102.50", " 1102,5 "] {
            XCTAssertTrue(question.isCorrect(QuestionResponse(text: value)), value)
        }
        for value in ["", "NaN", "inf", "1.102,5", "1102 CHF", "1200"] {
            XCTAssertFalse(question.isCorrect(QuestionResponse(text: value)), value)
        }
    }

    func testRecallAllowsCaseAndUmlautsButNotSubstringGuessing() throws {
        let question = try LearningCatalog.packageCatalog().questions.first { $0.acceptedAnswers?.contains("Liquidität") == true }!
        XCTAssertTrue(question.isCorrect(QuestionResponse(text: "  LIQUIDITÄT! ")))
        XCTAssertTrue(question.isCorrect(QuestionResponse(text: "liquiditaet")))
        XCTAssertFalse(question.isCorrect(QuestionResponse(text: "Liquidität ist die falsche Antwort")))
    }

    func testMatchingRequiresACompleteBijection() throws {
        let question = try LearningCatalog.packageCatalog().questions.first { $0.kind == .matching }!
        let repeated = QuestionResponse(matches: Dictionary(uniqueKeysWithValues: question.options.indices.map { ($0, 0) }))
        XCTAssertFalse(question.isComplete(repeated))
        XCTAssertFalse(question.isCorrect(QuestionResponse(matches: [0: 0])))
    }

    func testExplicitChapterPracticeContainsTheWholeChosenChapter() throws {
        let catalog = try LearningCatalog.packageCatalog()
        let lesson = catalog.lessons.first { $0.id == "money.compound" }!
        var random = SeededRandom(state: 44)
        let session = LearningScheduler.makeSession(catalog: catalog, progress: .init(), request: nil,
            minutes: 5, consumed: 0, failures: 0, preferredLesson: lesson.id, now: now, random: &random)
        XCTAssertEqual(session.lessonIDs, [lesson.id])
        XCTAssertEqual(Set(session.questions.map(\.id)), Set(lesson.questions.map(\.id)))
        XCTAssertEqual(session.storageKey, "chapter.money.compound")
    }

    func testAChapterIsNotCompletedAfterOneLuckyAnswer() throws {
        let catalog = try LearningCatalog.packageCatalog()
        let lesson = catalog.lessons.first { $0.id == "case.cash.1" }!
        var random = SeededRandom(state: 7)
        var session = LearningScheduler.makeSession(catalog: catalog, progress: .init(), request: nil,
            minutes: 5, consumed: 0, failures: 0, preferredTopic: "case.cash", now: now, random: &random)
        XCTAssertEqual(session.lessonIDs, [lesson.id])
        XCTAssertLessThan(session.questions.count, lesson.questions.count)
        session.readLessonIDs = Set(session.lessonIDs)
        session.typedResponses = Dictionary(uniqueKeysWithValues: session.questions.map { ($0.id, correctResponse($0.question)) })
        var progress = LearningProgress()
        XCTAssertTrue(LearningScheduler.grade(&session, progress: &progress, now: now)!.passed)
        XCTAssertFalse(progress.completedLessonIDs.contains(lesson.id))
    }

    func testFullCoverageCompletesChapterAndRepetitionDoesNotDuplicateResult() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var random = SeededRandom(state: 1)
        var session = LearningScheduler.makeSession(catalog: catalog, progress: .init(), request: nil,
            minutes: 5, consumed: 0, failures: 0, preferredLesson: "business.problem", now: now, random: &random)
        session.readLessonIDs = Set(session.lessonIDs)
        session.typedResponses = Dictionary(uniqueKeysWithValues: session.questions.map { ($0.id, correctResponse($0.question)) })
        var progress = LearningProgress()
        XCTAssertTrue(LearningScheduler.grade(&session, progress: &progress, now: now)!.passed)
        XCTAssertTrue(progress.completedLessonIDs.contains("business.problem"))
        _ = LearningScheduler.grade(&session, progress: &progress, now: now)
        XCTAssertEqual(progress.results.count, 1)
    }

    func testReviewOnlyDoesNotAddUnrelatedNewMaterialWhenDueItemsExist() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var progress = LearningProgress()
        let dueID = catalog.questions[0].id
        progress.memories[dueID] = QuestionMemory(due: now.addingTimeInterval(-1))
        var random = SeededRandom(state: 2)
        let session = LearningScheduler.makeSession(catalog: catalog, progress: progress, request: nil,
            minutes: 5, consumed: 0, failures: 0, reviewOnly: true, now: now, random: &random)
        XCTAssertEqual(session.questions.map(\.id), [dueID])
        XCTAssertTrue(session.questions.allSatisfy(\.isReview))
    }

    func testVersionTwoSessionAndProgressStillDecode() throws {
        let catalog = try LearningCatalog.packageCatalog()
        let lesson = catalog.lessons.first { $0.id == "learn.recall" }!
        let question = lesson.questions.first { $0.format == nil }!
        let legacy = LearningSession(id: UUID(), storageKey: "practice", target: nil, requestID: nil,
            grantMinutes: 5, pathID: lesson.pathID, lessonIDs: [lesson.id],
            questions: [SessionQuestion(question: question, lessonID: lesson.id, isReview: false, optionOrder: Array(question.options.indices))],
            readLessonIDs: [lesson.id], responses: [question.id: question.correctIndex])
        let restored = try JSONDecoder().decode(LearningSession.self, from: JSONEncoder().encode(legacy))
        XCTAssertNil(restored.typedResponses)
        XCTAssertNil(restored.requiredQuestionIDs)
        XCTAssertTrue(restored.isCorrect(restored.questions[0]))
        var progress = LearningProgress()
        progress.completedLessonIDs = [lesson.id]
        progress.sessions["practice"] = legacy
        let roundTrip = try JSONDecoder().decode(LearningProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(roundTrip.completedLessonIDs, [lesson.id])
        XCTAssertTrue(roundTrip.sessions["practice"]!.allAnswered)
    }

    func testSelectionLockMigratesAndSurvivesDayChange() throws {
        var state = GateState()
        state.selectionData = Data("old selection".utf8)
        state.protectedSelectionData = Data("protected".utf8)
        XCTAssertNil(state.selectionLocked)
        XCTAssertTrue(state.isSelectionLocked)
        state.rollDay(at: Date().addingTimeInterval(86400))
        let saved = try JSONDecoder().decode(GateState.self, from: JSONEncoder().encode(state))
        XCTAssertTrue(saved.isSelectionLocked)
        XCTAssertEqual(saved.protectedSelectionData, state.protectedSelectionData)
    }

    func testPickerDeselectionAndEmptySelectionCannotDropSavedTargets() {
        XCTAssertEqual(AdditiveSelection.retaining(Set(["YouTube", "Snapchat"]), adding: Set(["TikTok"])), Set(["YouTube", "Snapchat", "TikTok"]))
        XCTAssertEqual(AdditiveSelection.retaining(Set(["YouTube"]), adding: Set<String>()), Set(["YouTube"]))
    }

    func testLauncherCanReorderAndAddButCannotRemoveDisableOrReplaceSavedLink() {
        let a = LauncherItem(title: "A", url: "a://")
        let b = LauncherItem(title: "B", url: "b://")
        let c = LauncherItem(title: "C", url: "c://")
        var edited = a; edited.url = "replacement://"; edited.enabled = false
        let result = AdditiveSelection.launcher([a,b], adding: [b,edited,c])
        XCTAssertEqual(result.map(\.id), [b.id,a.id,c.id])
        XCTAssertEqual(result[1].url, a.url)
        XCTAssertTrue(result[1].enabled)
        XCTAssertEqual(AdditiveSelection.launcher([a,b], adding: []).map(\.id), [a.id,b.id])
    }
}

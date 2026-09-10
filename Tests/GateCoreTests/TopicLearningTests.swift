import XCTest
@testable import GateCore

final class TopicLearningTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testStorageKeysShareOneExplicitPriorityForPersistenceAndPlanning() {
        let request = GateRequest(target: GateTarget(kind: .application, tokenData: Data("A".utf8)))
        XCTAssertEqual(LearningScheduler.storageKey(request: request, path: "money", lesson: "money.compound", topic: "case.compound", reviewOnly: true), request.target.id)
        XCTAssertEqual(LearningScheduler.storageKey(request: nil, path: "money", lesson: "money.compound", topic: "case.compound", reviewOnly: true), "chapter.money.compound")
        XCTAssertEqual(LearningScheduler.storageKey(request: nil, path: "money", topic: "case.compound", reviewOnly: true), "topic.case.compound")
        XCTAssertEqual(LearningScheduler.storageKey(request: nil, path: "money", reviewOnly: true), "review")
        XCTAssertEqual(LearningScheduler.storageKey(request: nil, path: "money"), "path.money")
        XCTAssertEqual(LearningScheduler.storageKey(request: nil), "practice")
    }

    private func round(_ catalog: LearningCatalog, minutes: Int = 5, topic: String? = nil,
                       progress: LearningProgress = .init(), failures: Int = 0,
                       remediation: [String] = [], gaps: [String] = [], seed: UInt64 = 1) -> LearningSession {
        var random = SeededRandom(state: seed)
        let target = GateTarget(kind: .application, tokenData: Data("A".utf8))
        return LearningScheduler.makeSession(catalog: catalog, progress: progress,
            request: GateRequest(target: target), minutes: minutes, consumed: 30, failures: failures,
            preferredTopic: topic, remediation: remediation, remediationQuestionIDs: gaps,
            now: now, random: &random)
    }

    private func assertOneTopic(_ session: LearningSession, catalog: LearningCatalog,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotNil(session.topicID, file: file, line: line)
        XCTAssertFalse(session.questions.isEmpty, file: file, line: line)
        XCTAssertEqual(Set(session.lessonIDs.compactMap { catalog.topicID(forLesson: $0) }),
                       Set([session.topicID!]), file: file, line: line)
        XCTAssertTrue(session.questions.allSatisfy {
            catalog.topicID(forLesson: $0.lessonID) == session.topicID && session.lessonIDs.contains($0.lessonID)
        }, file: file, line: line)
        XCTAssertEqual(Set(session.questions.map(\.id)).count, session.questions.count, file: file, line: line)
    }

    func testEveryNewCaseHasFourOrderedChaptersAndTwentyQuestions() throws {
        let catalog = try LearningCatalog.packageCatalog()
        for topic in catalog.topics! {
            let chapters = catalog.chapters(in: topic.id)
            XCTAssertEqual(chapters.map(\.topicOrder), [1, 2, 3, 4])
            XCTAssertTrue(chapters.allSatisfy { $0.pathID == topic.pathID })
            XCTAssertEqual(chapters.flatMap(\.questions).count, 20)
            XCTAssertTrue(chapters.allSatisfy { $0.cards.contains { $0.image != nil || $0.visual != nil } })
        }
    }

    func testEveryGrantSizeAndFailureLevelStaysInOneConcreteTopic() throws {
        let catalog = try LearningCatalog.packageCatalog()
        for minutes in LessonLoad.allowedMinutes {
            for failures in [0, 1, 4] {
                for seed in UInt64(1)...UInt64(12) {
                    let session = round(catalog, minutes: minutes, failures: failures, seed: seed)
                    assertOneTopic(session, catalog: catalog)
                    XCTAssertEqual(session.questions.count,
                                   LessonLoad.questionCount(minutes: minutes, consumedMinutes: 30, failures: failures))
                }
            }
        }
    }

    func testPhilosophyDoesNotMeanMixingTwoDifferentPhilosophyCases() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var progress = LearningProgress()
        for lesson in catalog.chapters(in: "case.socrates") {
            for question in lesson.questions { progress.memories[question.id] = QuestionMemory(due: now.addingTimeInterval(-100)) }
        }
        let session = round(catalog, minutes: 30, topic: "case.stoic", progress: progress)
        assertOneTopic(session, catalog: catalog)
        XCTAssertEqual(session.topicID, "case.stoic")
        XCTAssertEqual(session.pathID, "philosophy")
        XCTAssertEqual(session.lessonIDs, ["case.stoic.1", "case.stoic.2", "case.stoic.3", "case.stoic.4"])
    }

    func testDueQuestionsChooseOneCaseBeforeTheDeckIsBuilt() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var progress = LearningProgress()
        for topic in ["case.cash", "case.press", "case.stoic"] {
            for chapter in catalog.chapters(in: topic) {
                for question in chapter.questions {
                    progress.memories[question.id] = QuestionMemory(due: now.addingTimeInterval(topic == "case.cash" ? -200 : -100))
                }
            }
        }
        let session = round(catalog, minutes: 30, progress: progress)
        assertOneTopic(session, catalog: catalog)
        XCTAssertEqual(session.topicID, "case.cash")
        XCTAssertTrue(session.questions.allSatisfy(\.isReview))
    }

    func testVoluntaryReviewUsesOnlyDueQuestionsWithinOneTopic() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var progress = LearningProgress()
        let first = catalog.chapters(in: "case.stoic")[0].questions[0]
        let other = catalog.chapters(in: "case.socrates")[0].questions[0]
        progress.memories[first.id] = QuestionMemory(due: now.addingTimeInterval(-2))
        progress.memories[other.id] = QuestionMemory(due: now.addingTimeInterval(-1))
        var random = SeededRandom(state: 5)
        let session = LearningScheduler.makeSession(catalog: catalog, progress: progress, request: nil,
            minutes: 5, consumed: 0, failures: 0, reviewOnly: true, now: now, random: &random)
        assertOneTopic(session, catalog: catalog)
        XCTAssertEqual(session.questions.map(\.id), [first.id])
        XCTAssertEqual(session.lessonIDs, ["case.stoic.1"])
    }

    func testRetriesKeepTheOriginalCaseAndPrioritiseActualErrors() throws {
        let catalog = try LearningCatalog.packageCatalog()
        let first = round(catalog, minutes: 15, topic: "case.press")
        let failed = Array(first.questions.prefix(3).map(\.id))
        var progress = LearningProgress()
        let unrelated = catalog.chapters(in: "case.sleep")[0].questions[0]
        progress.memories[unrelated.id] = QuestionMemory(due: now.addingTimeInterval(-100))
        let retry = round(catalog, minutes: 15, progress: progress, failures: 1,
                          remediation: first.lessonIDs, gaps: failed, seed: 9)
        assertOneTopic(retry, catalog: catalog)
        XCTAssertEqual(retry.topicID, first.topicID)
        XCTAssertGreaterThan(retry.questions.count, first.questions.count)
        XCTAssertTrue(Set(failed).isSubset(of: Set(retry.questions.map(\.id))))
        XCTAssertFalse(retry.questions.contains { $0.id == unrelated.id })
    }

    func testRetryCannotSmuggleAnUnrelatedGapIntoTheCase() throws {
        let catalog = try LearningCatalog.packageCatalog()
        let unrelated = catalog.chapters(in: "case.socrates")[0].questions[0].id
        let session = round(catalog, minutes: 20, topic: "case.stoic", failures: 2,
                            remediation: ["case.stoic.2"], gaps: [unrelated])
        assertOneTopic(session, catalog: catalog)
        XCTAssertFalse(session.questions.contains { $0.id == unrelated })
    }

    func testLongerRoundsDeepenTheSameStoryInOrder() throws {
        let catalog = try LearningCatalog.packageCatalog()
        for (minutes, depth) in [(5, 1), (10, 2), (15, 3), (20, 4), (30, 4)] {
            let session = round(catalog, minutes: minutes, topic: "case.cash")
            XCTAssertEqual(session.lessonIDs, Array((1...depth).map { "case.cash.\($0)" }))
            XCTAssertEqual(Set(session.questions.map(\.lessonID)), Set(session.lessonIDs))
            assertOneTopic(session, catalog: catalog)
        }
    }

    func testCompletedChapterAdvancesWithinTheCase() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var progress = LearningProgress()
        progress.completedLessonIDs = ["case.cash.1", "case.cash.2"]
        let session = round(catalog, topic: "case.cash", progress: progress)
        XCTAssertEqual(session.lessonIDs, ["case.cash.3"])
        assertOneTopic(session, catalog: catalog)
    }

    func testLongRoundRetainsContextWhenOnlyLastChapterIsUnfinished() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var progress = LearningProgress()
        progress.completedLessonIDs = ["case.cash.1", "case.cash.2", "case.cash.3"]
        let session = round(catalog, minutes: 30, topic: "case.cash", progress: progress)
        XCTAssertEqual(session.lessonIDs, catalog.chapters(in: "case.cash").map(\.id))
        assertOneTopic(session, catalog: catalog)
    }

    func testAnOldFoundationChapterIsItsOwnTopicNotAFillerForAnother() throws {
        let catalog = try LearningCatalog.packageCatalog()
        let session = round(catalog, minutes: 30, topic: "money.compound")
        XCTAssertEqual(session.lessonIDs, ["money.compound"])
        XCTAssertEqual(session.questions.count, catalog.chapters(in: "money.compound")[0].questions.count)
        assertOneTopic(session, catalog: catalog)
    }

    func testEveryInlineProbeIsGradableButSeparateFromTheExamBank() throws {
        let catalog = try LearningCatalog.packageCatalog()
        let probes = catalog.lessons.flatMap(\.cards).compactMap(\.probe)
        XCTAssertEqual(probes.count, 48)
        XCTAssertEqual(Set(probes.map(\.id)).count, probes.count)
        XCTAssertTrue(Set(probes.map(\.id)).isDisjoint(with: Set(catalog.questions.map(\.id))))
        for probe in probes {
            XCTAssertTrue(probe.isValid, probe.id)
            XCTAssertTrue(probe.isCorrect(correctResponse(probe)), probe.id)
            XCTAssertFalse(probe.isComplete(nil), probe.id)
        }
    }

    func testProbeResponsesCannotGrantCreditOrMarkTheQuizAnswered() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var session = round(catalog, topic: "case.cash")
        let probe = catalog.chapters(in: "case.cash")[0].cards.compactMap(\.probe)[0]
        session.probeResponses = [probe.id: correctResponse(probe)]
        session.readLessonIDs = Set(session.lessonIDs)
        var progress = LearningProgress()
        XCTAssertEqual(session.answeredCount, 0)
        XCTAssertNil(LearningScheduler.grade(&session, progress: &progress, now: now))
        XCTAssertTrue(progress.results.isEmpty)
        XCTAssertTrue(progress.memories.isEmpty)
        XCTAssertTrue(progress.completedLessonIDs.isEmpty)
    }

    func testBookmarksRevealsAndNotesSurviveAColdDecode() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var session = round(catalog, minutes: 30, topic: "case.cash")
        let probe = catalog.chapters(in: "case.cash")[0].cards.compactMap(\.probe)[0]
        session.readerIndex = 8
        session.quizIndex = 2
        session.probeResponses = [probe.id: correctResponse(probe)]
        session.revealedCardIDs = ["case.cash.1.step.2"]
        session.reflectionNotes = ["case.cash.1": "Ergebnis ist noch kein Kontoguthaben."]
        session.typedResponses = [session.questions[0].id: correctResponse(session.questions[0].question)]
        let restored = try JSONDecoder().decode(LearningSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(restored.id, session.id)
        XCTAssertEqual(restored.topicID, session.topicID)
        XCTAssertEqual(restored.readerIndex, 8)
        XCTAssertEqual(restored.quizIndex, 2)
        XCTAssertEqual(restored.probeResponses, session.probeResponses)
        XCTAssertEqual(restored.revealedCardIDs, session.revealedCardIDs)
        XCTAssertEqual(restored.reflectionNotes, session.reflectionNotes)
        XCTAssertEqual(restored.typedResponses, session.typedResponses)
        XCTAssertEqual(restored.questions.map(\.optionOrder), session.questions.map(\.optionOrder))
        XCTAssertEqual(restored.target, session.target)
    }

    func testLegacyMixedRoundAndProgressArePreservedWithoutPretendingTheyAreNew() throws {
        let catalog = try LearningCatalog.packageCatalog()
        let ids = ["money.compound", "business.problem"]
        let deck = ids.map { id -> SessionQuestion in
            let q = catalog.lessons.first { $0.id == id }!.questions[0]
            return SessionQuestion(question: q, lessonID: id, isReview: false, optionOrder: Array(q.options.indices))
        }
        let legacy = LearningSession(id: UUID(), storageKey: "practice", target: nil, requestID: nil,
            grantMinutes: 5, pathID: "money", lessonIDs: ids, questions: deck,
            readLessonIDs: Set(ids), typedResponses: [deck[0].id: correctResponse(deck[0].question)],
            reflectionNotes: [ids[0]: "Meine alte Notiz"])
        var progress = LearningProgress()
        progress.sessions["practice"] = legacy
        progress.completedLessonIDs = ["learn.recall"]
        progress.memories["learn.recall.q1"] = QuestionMemory(streak: 2, attempts: 3, correctAttempts: 2)
        let restored = try JSONDecoder().decode(LearningProgress.self, from: JSONEncoder().encode(progress))
        let saved = restored.sessions["practice"]!
        XCTAssertNil(saved.topicID)
        XCTAssertNil(saved.readerIndex)
        XCTAssertNil(restored.recentTopicIDs)
        XCTAssertEqual(saved.lessonIDs, ids)
        XCTAssertEqual(saved.reflectionNotes, legacy.reflectionNotes)
        XCTAssertEqual(saved.typedResponses, legacy.typedResponses)
        XCTAssertEqual(saved.readLessonIDs, Set(ids))
        XCTAssertEqual(restored.completedLessonIDs, progress.completedLessonIDs)
        XCTAssertEqual(restored.memories["learn.recall.q1"]?.streak, 2)
    }

    func testSuccessfulGradeRecordsTopicHistoryWithoutResettingOldCompletion() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var session = round(catalog, topic: "case.cash")
        session.readLessonIDs = Set(session.lessonIDs)
        session.typedResponses = Dictionary(uniqueKeysWithValues: session.questions.map { ($0.id, correctResponse($0.question)) })
        var progress = LearningProgress()
        progress.completedLessonIDs = ["money.compound"]
        XCTAssertTrue(LearningScheduler.grade(&session, progress: &progress, now: now)!.passed)
        XCTAssertEqual(progress.recentTopicIDs, ["case.cash"])
        XCTAssertTrue(progress.completedLessonIDs.contains("money.compound"))
        XCTAssertFalse(progress.completedLessonIDs.contains("case.cash.1"))
    }

    func testReadingEstimateAccountsForActualWordsAndInlinePractice() throws {
        let catalog = try LearningCatalog.packageCatalog()
        let short = round(catalog, topic: "case.cash")
        let long = round(catalog, minutes: 30, topic: "case.cash")
        let chapters = catalog.chapters(in: "case.cash")
        let expected = chapters.reduce(0) { $0 + $1.readingSeconds + $1.cards.filter { $0.probe != nil }.count * 15 }
        XCTAssertEqual(long.readingEstimateSeconds, expected)
        XCTAssertEqual(long.estimatedSeconds, expected + long.questions.count * 20)
        XCTAssertGreaterThan(long.estimatedSeconds, short.estimatedSeconds)
    }

    func testInvalidTopicMetadataIsRejected() throws {
        var catalog = try LearningCatalog.packageCatalog()
        catalog.topics?.append(LearningTopic(id: "case.empty", pathID: "history", title: "Empty", hook: "No chapters"))
        XCTAssertThrowsError(try catalog.validate())
        catalog = try LearningCatalog.packageCatalog()
        catalog.topics?[0] = LearningTopic(id: "case.press", pathID: "money", title: "Wrong path", hook: "Mismatch")
        XCTAssertThrowsError(try catalog.validate())
    }

    func testNewDurationOptionsKeepTheThirtyMinuteFreeBudget() {
        XCTAssertEqual(GateState.everydayFreeMinutes, 30)
        XCTAssertEqual(LessonLoad.allowedMinutes, [5, 10, 15, 20, 30])
        XCTAssertEqual(LessonLoad.questionCount(minutes: 20, consumedMinutes: 30, failures: 0), 9)
        XCTAssertEqual(LessonLoad.questionCount(minutes: 30, consumedMinutes: 30, failures: 0), 12)
        XCTAssertLessThanOrEqual(LessonLoad.questionCount(minutes: 30, consumedMinutes: 999, failures: 99), 20)
    }
}

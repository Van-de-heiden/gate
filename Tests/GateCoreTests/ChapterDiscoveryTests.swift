import XCTest
@testable import GateCore

final class ChapterDiscoveryTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func complete(_ session: inout LearningSession, progress: inout LearningProgress) {
        session.readLessonIDs = Set(session.lessonIDs)
        for item in session.questions { session.setAnswer(correctResponse(item.question), for: item.id) }
        session.lockedQuestionIDs = session.inlineQuestionIDs
        XCTAssertTrue(LearningScheduler.grade(&session, progress: &progress, now: now)?.passed == true)
    }

    func testAllHundredChaptersAreOfferedOnceBeforeAnyReviewAcrossRestarts() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var progress = LearningProgress()
        var seen = Set<String>()
        var random = SeededRandom(state: 13)
        for index in 0..<100 {
            let request = GateRequest(target: GateTarget(kind: .application, tokenData: Data("app".utf8)))
            let key = LearningProgress.offerKey(request: request)
            let offer = try XCTUnwrap(progress.topicOffer(catalog: catalog, key: key, now: now, random: &random))
            XCTAssertFalse(offer.isReview!)
            for id in offer.chapterIDs!.values { XCTAssertFalse(seen.contains(id)) }
            let topic = offer.topicIDs[index % offer.topicIDs.count]
            XCTAssertTrue(progress.chooseTopic(topic, from: key, catalog: catalog))
            var session = LearningScheduler.makeSession(catalog: catalog, progress: progress, request: request,
                minutes: index % 2 == 0 ? 5 : 30, consumed: 30, failures: 0, preferredTopic: topic,
                now: now, random: &random)
            XCTAssertEqual(session.lessonIDs, [offer.chapterIDs![topic]!])
            XCTAssertTrue(seen.insert(session.lessonIDs[0]).inserted)
            complete(&session, progress: &progress)
            progress.topicOffers?.removeValue(forKey: key)
            progress = try JSONDecoder().decode(LearningProgress.self, from: JSONEncoder().encode(progress))
        }
        XCTAssertEqual(seen, Set(catalog.lessons.map(\.id)))
        let review = try XCTUnwrap(progress.topicOffer(catalog: catalog, key: "after", now: now, random: &random))
        XCTAssertTrue(review.isReview!)
        XCTAssertEqual(review.topicIDs.count, 2)
    }

    func testLastUnseenTopicIsOfferedAloneInsteadOfMixingInRepeats() throws {
        let catalog = try LearningCatalog.packageCatalog()
        let last = catalog.lessons.last!
        var progress = LearningProgress()
        for lesson in catalog.lessons where lesson.id != last.id {
            progress.completedLessonIDs.insert(lesson.id)
            for q in lesson.questions { progress.memories[q.id] = QuestionMemory(attempts: 1, correctAttempts: 1) }
        }
        var random = SeededRandom(state: 1)
        let offer = try XCTUnwrap(progress.topicOffer(catalog: catalog, key: "last", now: now, random: &random))
        XCTAssertEqual(offer.topicIDs, [last.topicKey])
        XCTAssertEqual(offer.chapterIDs?[last.topicKey], last.id)
        XCTAssertFalse(offer.isReview!)
    }

    func testStaleUnchosenOfferIsReplacedAfterItsChapterWasCompletedElsewhere() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var progress = LearningProgress()
        var random = SeededRandom(state: 2)
        let first = try XCTUnwrap(progress.topicOffer(catalog: catalog, key: "A", now: now, random: &random))
        let id = first.chapterIDs!.values.first!
        let lesson = catalog.lessons.first { $0.id == id }!
        progress.completedLessonIDs.insert(id)
        for q in lesson.questions { progress.memories[q.id] = QuestionMemory(attempts: 1, correctAttempts: 1) }
        let replacement = try XCTUnwrap(progress.topicOffer(catalog: catalog, key: "A", now: now, random: &random))
        XCTAssertFalse(replacement.chapterIDs!.values.contains(id))
    }

    func testAdditiveCatalogKeepsCompatibleSessionPositionAndAnswers() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var random = SeededRandom(state: 1)
        var session = LearningScheduler.makeSession(catalog: catalog, progress: .init(), request: nil,
            minutes: 5, consumed: 0, failures: 0, preferredLesson: "case.press.1", now: now, random: &random)
        session.catalogVersion = 6
        session.readerIndex = 2
        session.setAnswer(correctResponse(session.questions[0].question), for: session.questions[0].id)
        var progress = LearningProgress()
        progress.sessions[session.storageKey] = session
        progress.reconcileCatalog(catalog)
        let restored = try XCTUnwrap(progress.sessions[session.storageKey])
        XCTAssertEqual(restored.id, session.id)
        XCTAssertEqual(restored.readerIndex, 2)
        XCTAssertEqual(restored.typedResponses, session.typedResponses)
        XCTAssertEqual(restored.catalogVersion, 7)
    }

    func testFinishedChaptersStayFinishedAfterResultHistoryIsPruned() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var random = SeededRandom(state: 1)
        var progress = LearningProgress()
        var session = LearningScheduler.makeSession(catalog: catalog, progress: progress, request: nil,
            minutes: 5, consumed: 0, failures: 0, preferredLesson: "case.press.1", now: now, random: &random)
        complete(&session, progress: &progress)
        progress.results = []
        XCTAssertTrue(progress.hasFinished(catalog.lessons.first { $0.id == "case.press.1" }!))
        XCTAssertEqual(progress.nextChapter(in: "case.press", catalog: catalog)?.id, "case.press.2")
    }
}

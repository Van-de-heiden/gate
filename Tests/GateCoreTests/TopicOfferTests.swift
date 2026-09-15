import XCTest
@testable import GateCore

final class TopicOfferTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testPairIsDistinctUsesDifferentPathsAndSurvivesRestart() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var progress = LearningProgress()
        var random = SeededRandom(state: 7)
        let offer = try XCTUnwrap(progress.topicOffer(catalog: catalog, key: "request.A", now: now, random: &random))
        XCTAssertEqual(offer.topicIDs.count, 2)
        XCTAssertEqual(Set(offer.topicIDs).count, 2)
        XCTAssertEqual(Set(offer.topicIDs.compactMap { catalog.topic($0)?.pathID }).count, 2)
        var restored = try JSONDecoder().decode(LearningProgress.self, from: JSONEncoder().encode(progress))
        random = SeededRandom(state: 900)
        XCTAssertEqual(restored.topicOffer(catalog: catalog, key: "request.A", now: now.addingTimeInterval(100), random: &random), offer)
    }

    func testNewRoundsExploreTheCatalogAndAvoidRecentTopics() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var seen = Set<String>()
        var progress = LearningProgress()
        progress.recentTopicIDs = Array(catalog.allTopics.prefix(3).map(\.id))
        for seed in 1...100 {
            var random = SeededRandom(state: UInt64(seed))
            let offer = try XCTUnwrap(progress.topicOffer(catalog: catalog, key: "round.\(seed)", now: now.addingTimeInterval(Double(seed)), random: &random))
            XCTAssertTrue(Set(offer.topicIDs).isDisjoint(with: Set(progress.recentTopicIDs!)))
            seen.formUnion(offer.topicIDs)
        }
        XCTAssertEqual(seen, Set(catalog.allTopics.dropFirst(3).map(\.id)))
        XCTAssertLessThanOrEqual(progress.topicOffers!.count, 32)
    }

    func testSelectionRequiresAnOfferedTopicAndCannotBeChanged() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var progress = LearningProgress()
        var random = SeededRandom(state: 11)
        let pair = try XCTUnwrap(progress.topicOffer(catalog: catalog, key: "A", now: now, random: &random))
        let other = catalog.allTopics.first { !pair.topicIDs.contains($0.id) }!.id
        XCTAssertFalse(progress.chooseTopic(other, from: "A", catalog: catalog))
        XCTAssertFalse(progress.chooseTopic(pair.topicIDs[0], from: "missing", catalog: catalog))
        XCTAssertTrue(progress.chooseTopic(pair.topicIDs[0], from: "A", catalog: catalog))
        XCTAssertFalse(progress.chooseTopic(pair.topicIDs[1], from: "A", catalog: catalog))
        XCTAssertTrue(progress.chooseTopic(pair.topicIDs[0], from: "A", catalog: catalog))
        let saved = try JSONDecoder().decode(LearningProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(saved.topicOffers?["A"]?.selectedTopicID, pair.topicIDs[0])
    }

    func testRequestsIncludingNewRequestForSameAppHaveSeparateOffers() {
        let target = GateTarget(kind: .application, tokenData: Data("A".utf8))
        let first = GateRequest(target: target)
        let second = GateRequest(target: target)
        XCTAssertNotEqual(LearningProgress.offerKey(request: first), LearningProgress.offerKey(request: second))
        XCTAssertNotEqual(LearningProgress.offerKey(request: first), LearningProgress.offerKey(request: nil))
    }

    func testSmallCatalogsDoNotDuplicateAnOptionOrCrash() throws {
        let full = try LearningCatalog.packageCatalog()
        let topic = full.allTopics[0]
        var catalog = LearningCatalog(version: full.version, paths: full.paths,
            lessons: full.chapters(in: topic.id), topics: [topic])
        var progress = LearningProgress()
        var random = SeededRandom(state: 2)
        XCTAssertEqual(progress.topicOffer(catalog: catalog, key: "A", now: now, random: &random)?.topicIDs.count, 1)
        catalog = LearningCatalog(version: full.version, paths: [], lessons: [], topics: [])
        XCTAssertNil(progress.topicOffer(catalog: catalog, key: "A", now: now, random: &random))
    }

    func testMissingRetiredTopicInvalidatesThePair() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var progress = LearningProgress()
        progress.topicOffers = ["A": LearningTopicOffer(id: "A", catalogVersion: catalog.version,
            topicIDs: ["retired", catalog.allTopics[0].id], createdAt: now, selectedTopicID: "retired")]
        var random = SeededRandom(state: 2)
        let fresh = try XCTUnwrap(progress.topicOffer(catalog: catalog, key: "A", now: now, random: &random))
        XCTAssertNil(fresh.selectedTopicID)
        XCTAssertFalse(fresh.topicIDs.contains("retired"))
        XCTAssertEqual(fresh.topicIDs.count, 2)
    }

    func testCatalogUpdateRetiresOffersAndFailedDeckButKeepsHistoryAndNotes() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var random = SeededRandom(state: 2)
        var failed = LearningScheduler.makeSession(catalog: catalog, progress: .init(), request: nil,
            minutes: 5, consumed: 0, failures: 0, preferredTopic: "case.cash", now: now, random: &random)
        failed.catalogVersion = 5
        failed.reflectionNotes = ["case.cash.1": "Meine Notiz"]
        failed.result = LearningResult(id: failed.id, completedAt: now, lessonIDs: failed.lessonIDs,
            correct: 0, total: failed.questions.count, passed: false, practice: true, activeSeconds: 20)
        var progress = LearningProgress()
        progress.sessions[failed.storageKey] = failed
        progress.results = [failed.result!]
        progress.topicOffers = ["A": LearningTopicOffer(id: "A", catalogVersion: 5, topicIDs: ["retired"], createdAt: now)]
        progress.reconcileCatalogVersion(6)
        XCTAssertTrue(progress.sessions.isEmpty)
        XCTAssertTrue(progress.topicOffers!.isEmpty)
        XCTAssertEqual(progress.results.count, 1)
        XCTAssertEqual(progress.savedNotes?["case.cash.1"], "Meine Notiz")
    }

    func testOldCompletionDoesNotLabelRewrittenChapterAsMastered() throws {
        let lesson = try LearningCatalog.packageCatalog().lessons[0]
        var progress = LearningProgress()
        progress.completedLessonIDs.insert(lesson.id)
        progress.memories[lesson.id + ".v5.q1"] = QuestionMemory(correctAttempts: 2)
        XCTAssertFalse(progress.hasCompleted(lesson))
        for question in lesson.questions { progress.memories[question.id] = QuestionMemory(correctAttempts: 1) }
        XCTAssertTrue(progress.hasCompleted(lesson))
    }

    func testTextOnlyChaptersAreValidInExpandedCatalog() throws {
        let catalog = try LearningCatalog.packageCatalog()
        var data = try JSONSerialization.jsonObject(with: JSONEncoder().encode(catalog)) as! [String: Any]
        var lessons = data["lessons"] as! [[String: Any]]
        var cards = lessons[0]["cards"] as! [[String: Any]]
        for index in cards.indices { cards[index].removeValue(forKey: "media") }
        lessons[0]["cards"] = cards; data["lessons"] = lessons
        let missing = try JSONDecoder().decode(LearningCatalog.self, from: JSONSerialization.data(withJSONObject: data))
        XCTAssertNoThrow(try missing.validate())
    }
}

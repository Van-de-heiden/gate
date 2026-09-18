import XCTest
@testable import GateCore

final class LearningChoiceFlowTests: XCTestCase {
    @MainActor
    func testChooseSuspendRestartAndChangedMinutesResumeSameSession() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("progress.json")
        let catalog = try LearningCatalog.legacyCatalog()
        let request = GateRequest(target: GateTarget(kind: .application, tokenData: Data("A".utf8)))
        let store = LearningStore(fileURL: file, suppliedCatalog: catalog)
        store.prepare(request: request, minutes: 5, consumed: 30, failures: 0)
        XCTAssertNil(store.session)
        let offer = try XCTUnwrap(store.choice?.offer)
        store.suspend()
        let resumed = LearningStore(fileURL: file, suppliedCatalog: catalog)
        resumed.prepare(request: request, minutes: 30, consumed: 90, failures: 2)
        XCTAssertEqual(resumed.choice?.offer, offer)
        resumed.choose(offer.topicIDs[1])
        let session = try XCTUnwrap(resumed.session)
        XCTAssertNil(resumed.choice)
        XCTAssertEqual(session.topicID, offer.topicIDs[1])
        XCTAssertEqual(session.grantMinutes, 30)
        XCTAssertEqual(session.lessonIDs, [try XCTUnwrap(offer.chapterIDs?[offer.topicIDs[1]])])
        resumed.suspend()
        let cold = LearningStore(fileURL: file, suppliedCatalog: catalog)
        cold.prepare(request: request, minutes: 5, consumed: 30, failures: 0)
        XCTAssertEqual(cold.session?.id, session.id)
        XCTAssertEqual(cold.session?.grantMinutes, 30)
        XCTAssertNil(cold.choice)
        XCTAssertNil(cold.error)
    }

    @MainActor
    func testFailedRoundRetriesSameTopicWithoutAnotherPair() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let catalog = try LearningCatalog.legacyCatalog()
        let request = GateRequest(target: GateTarget(kind: .application, tokenData: Data("A".utf8)))
        let store = LearningStore(fileURL: folder.appendingPathComponent("progress.json"), suppliedCatalog: catalog)
        store.prepare(request: request, minutes: 5, consumed: 30, failures: 0)
        let chosen = try XCTUnwrap(store.choice?.offer.topicIDs.first)
        store.choose(chosen)
        let first = try XCTUnwrap(store.session)
        for item in first.questions {
            let wrong: QuestionResponse
            switch item.question.kind {
            case .multipleChoice: wrong = .init(indices: Array(item.question.options.indices))
            case .ordering: wrong = .init(indices: Array(item.question.correctOrder!.reversed()))
            default: wrong = .init(indices: [(item.question.correctIndex + 1) % item.question.options.count])
            }
            store.answer(wrong, for: item.id)
            if first.inlineQuestionIDs!.contains(item.id) { store.submitProbe(item.id, cardID: item.lessonID + ".step.3") }
        }
        for lesson in first.lessonIDs { store.markRead(lesson) }
        XCTAssertFalse(try XCTUnwrap(store.grade()).passed)
        store.suspend()
        store.prepare(request: request, minutes: 5, consumed: 30, failures: 1)
        XCTAssertNil(store.choice)
        XCTAssertEqual(store.session?.topicID, chosen)
        XCTAssertNotEqual(store.session?.id, first.id)
        XCTAssertNil(store.session?.result)
    }

    @MainActor
    func testFinishingRemovesRequestOfferWithoutTouchingOtherApp() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LearningStore(fileURL: folder.appendingPathComponent("progress.json"), suppliedCatalog: try .legacyCatalog())
        let a = GateRequest(target: GateTarget(kind: .application, tokenData: Data("A".utf8)))
        let b = GateRequest(target: GateTarget(kind: .application, tokenData: Data("B".utf8)))
        store.prepare(request: b, minutes: 5, consumed: 30, failures: 0)
        let other = store.choice?.offer
        store.suspend()
        store.prepare(request: a, minutes: 5, consumed: 30, failures: 0)
        store.choose(try XCTUnwrap(store.choice?.offer.topicIDs.first))
        let session = try XCTUnwrap(store.session)
        for item in session.questions {
            store.answer(correctResponse(item.question), for: item.id)
            if session.inlineQuestionIDs!.contains(item.id) { store.submitProbe(item.id, cardID: item.lessonID + ".step.3") }
        }
        for id in session.lessonIDs { store.markRead(id) }
        XCTAssertTrue(try XCTUnwrap(store.grade()).passed)
        store.finish()
        XCTAssertNil(store.progress.topicOffers?[LearningProgress.offerKey(request: a)])
        XCTAssertEqual(store.progress.topicOffers?[LearningProgress.offerKey(request: b)], other)
        XCTAssertFalse(store.isPresented)
    }
}

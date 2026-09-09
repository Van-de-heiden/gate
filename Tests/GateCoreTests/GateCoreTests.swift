import XCTest
@testable import GateCore

final class GateCoreTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    func target(_ name: String) -> GateTarget { GateTarget(kind: .application, tokenData: Data(name.utf8)) }
    func activeState() -> GateState {
        var state = GateState()
        state.day = Calendar.current.startOfDay(for: now)
        state.monitoringEnabled = true
        state.limitReached = true
        return state
    }
    func grant(_ name: String, expires: TimeInterval = 1800) -> GateGrant {
        GateGrant(target: target(name), minutes: 5, grantedAt: now,
            expiresAt: now.addingTimeInterval(expires), armed: true)
    }
    func catalog() throws -> LearningCatalog { try LearningCatalog.packageCatalog() }
    func session(minutes: Int = 5, failures: Int = 0, progress: LearningProgress = .init(), seed: UInt64 = 1) throws -> LearningSession {
        var random = SeededRandom(state: seed)
        return LearningScheduler.makeSession(catalog: try catalog(), progress: progress,
            request: GateRequest(target: target("A")), minutes: minutes, consumed: 60, failures: failures,
            now: now, random: &random)
    }

    func testCurriculumHasSixteenCompletePathsAndUniqueQuestions() throws {
        let catalog = try catalog()
        try catalog.validate()
        XCTAssertEqual(catalog.paths.count, 16)
        XCTAssertEqual(catalog.lessons.count, 96)
        XCTAssertEqual(catalog.questions.count, 504)
        XCTAssertTrue(catalog.lessons.allSatisfy { $0.source.url.hasPrefix("https://") })
    }

    func testAnActiveAStillAllowsRequestForB() {
        var state = activeState()
        state.grants = [grant("A")]
        XCTAssertNotNil(state.enqueue(target("B"), at: now))
        XCTAssertNotNil(state.grant(for: target("A"), at: now))
        XCTAssertEqual(state.requests.count, 1)
    }

    func testRequestsForSameAppDeduplicateRegardlessOfTime() {
        var state = activeState()
        let first = state.enqueue(target("A"), at: now)
        let again = state.enqueue(target("A"), at: now.addingTimeInterval(3))
        XCTAssertEqual(first?.id, again?.id)
        XCTAssertEqual(state.requests.count, 1)
    }

    func testGrantedTargetCannotStackAnotherRequest() {
        var state = activeState()
        state.grants = [grant("A")]
        XCTAssertNil(state.enqueue(target("A"), at: now))
    }

    func testExpiryOfADoesNotCloseB() {
        var state = activeState()
        state.grants = [grant("A", expires: 5), grant("B", expires: 100)]
        state.expireGrants(at: now.addingTimeInterval(6))
        XCTAssertNil(state.grant(for: target("A"), at: now.addingTimeInterval(6)))
        XCTAssertNotNil(state.grant(for: target("B"), at: now.addingTimeInterval(6)))
    }

    func testGrantMonitorNamesAreUniqueEvenForSameTarget() {
        XCTAssertNotEqual(grant("A").activityName, grant("A").activityName)
    }

    func testUnarmedGrantNeverUnlocks() {
        var value = grant("A")
        value.armed = false
        XCTAssertFalse(value.isActive(at: now))
    }

    func testUsageExhaustionIsIndependent() {
        var state = activeState()
        var a = grant("A")
        a.usedMinutes = 5
        state.grants = [a, grant("B")]
        state.expireGrants(at: now)
        XCTAssertEqual(state.activeGrants(at: now).map(\.target.id), [target("B").id])
    }

    func testFailuresArePerTarget() {
        var state = activeState()
        var attempt = GateAttempt()
        for _ in 0..<3 { attempt.fail(at: now) }
        state.attempts[target("A").id] = attempt
        XCTAssertEqual(state.attempts[target("A").id]?.cooldownUntil, now.addingTimeInterval(900))
        XCTAssertNil(state.attempts[target("B").id])
    }

    func testDayRolloverResetsDailyStateNotHistory() {
        var state = activeState()
        state.recordUsage(90, at: now)
        state.grants = [grant("A")]
        state.rollDay(at: now.addingTimeInterval(86400))
        XCTAssertFalse(state.limitReached)
        XCTAssertEqual(state.confirmedMinutes, 0)
        XCTAssertTrue(state.grants.isEmpty)
        XCTAssertEqual(state.history.last?.confirmedMinutes, 90)
        XCTAssertTrue(state.monitoringEnabled)
    }

    func testSameDayCannotResetAllowance() {
        var state = activeState()
        state.recordUsage(70, at: now)
        state.rollDay(at: now)
        XCTAssertEqual(state.confirmedMinutes, 70)
        XCTAssertTrue(state.limitReached)
    }

    func testOutOfOrderUsageCallbacksDoNotReduceTime() {
        var state = activeState()
        state.recordUsage(90, at: now)
        state.recordUsage(30, at: now)
        XCTAssertEqual(state.confirmedMinutes, 90)
    }

    func testLessonLoadIsModerateIncreasingAndBounded() {
        XCTAssertEqual(LessonLoad.questionCount(minutes: 5, consumedMinutes: 60, failures: 0), 3)
        XCTAssertEqual(LessonLoad.questionCount(minutes: 10, consumedMinutes: 60, failures: 0), 5)
        XCTAssertEqual(LessonLoad.questionCount(minutes: 15, consumedMinutes: 60, failures: 0), 7)
        XCTAssertGreaterThan(LessonLoad.questionCount(minutes: 5, consumedMinutes: 120, failures: 2), 3)
        XCTAssertEqual(LessonLoad.questionCount(minutes: 15, consumedMinutes: 999, failures: 99), 14)
    }

    func testPassBoundaryUsesIntegerArithmetic() {
        XCTAssertTrue(LessonLoad.passes(correct: 4, total: 5))
        XCTAssertFalse(LessonLoad.passes(correct: 2, total: 3))
        XCTAssertFalse(LessonLoad.passes(correct: 0, total: 0))
    }

    func testSpacedRepetitionAndFailureReset() {
        var memory = QuestionMemory()
        memory.record(correct: true, now: now)
        XCTAssertEqual(memory.due, now.addingTimeInterval(86400))
        memory.record(correct: true, now: now.addingTimeInterval(86400))
        XCTAssertEqual(memory.streak, 2)
        XCTAssertEqual(memory.due, now.addingTimeInterval(4 * 86400))
        memory.record(correct: false, now: now.addingTimeInterval(4 * 86400))
        XCTAssertEqual(memory.streak, 0)
        XCTAssertEqual(memory.due, now.addingTimeInterval(4 * 86400 + 600))
    }

    func testImmediateRepetitionDoesNotFakeMastery() {
        var memory = QuestionMemory()
        for second in 0..<10 { memory.record(correct: true, now: now.addingTimeInterval(Double(second))) }
        XCTAssertEqual(memory.streak, 1)
    }

    func testEveryQuestionHasATaughtLessonAndShuffledOptions() throws {
        let result = try session(minutes: 15, failures: 4)
        XCTAssertEqual(Set(result.questions.map(\.id)).count, result.questions.count)
        for item in result.questions {
            XCTAssertTrue(result.lessonIDs.contains(item.lessonID))
            XCTAssertEqual(Set(item.optionOrder), Set(item.question.options.indices))
        }
    }

    func testRecentPathsAreNotRepeatedWhenAlternativesExist() throws {
        var progress = LearningProgress()
        progress.recentPathIDs = ["learn", "think"]
        for seed in UInt64(1)...UInt64(20) {
            XCTAssertFalse(progress.recentPathIDs.contains(try session(progress: progress, seed: seed).pathID))
        }
    }

    func testDueQuestionHasPriority() throws {
        let question = try catalog().questions[0]
        var progress = LearningProgress()
        progress.memories[question.id] = QuestionMemory(due: now.addingTimeInterval(-60))
        XCTAssertTrue(try session(progress: progress).questions.contains { $0.id == question.id && $0.isReview })
    }

    func testCannotGradeUnreadOrIncompleteSession() throws {
        var value = try session()
        var progress = LearningProgress()
        value.typedResponses = Dictionary(uniqueKeysWithValues: value.questions.map { ($0.id, correctResponse($0.question)) })
        XCTAssertNil(LearningScheduler.grade(&value, progress: &progress, now: now))
        value.readLessonIDs = Set(value.lessonIDs)
        value.responses = [:]; value.typedResponses = nil
        XCTAssertNil(LearningScheduler.grade(&value, progress: &progress, now: now))
    }

    func testGradeIsIdempotentAndRoundTripPreservesTargetAndResponses() throws {
        var value = try session()
        value.readLessonIDs = Set(value.lessonIDs)
        value.typedResponses = Dictionary(uniqueKeysWithValues: value.questions.map { ($0.id, correctResponse($0.question)) })
        var progress = LearningProgress()
        XCTAssertTrue(LearningScheduler.grade(&value, progress: &progress, now: now)?.passed == true)
        _ = LearningScheduler.grade(&value, progress: &progress, now: now)
        XCTAssertEqual(progress.results.count, 1)
        let restored = try JSONDecoder().decode(LearningSession.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(restored.target, target("A"))
        XCTAssertEqual(restored.responses, value.responses)
        XCTAssertEqual(restored.questions.map(\.optionOrder), value.questions.map(\.optionOrder))
    }

    func testInvalidLauncherSchemesAreRejected() {
        for url in ["javascript:alert(1)", "file:///private", "data:text/html,test", "gate://home", "https://"] {
            XCTAssertNil(LauncherItem(title: "Test", url: url).validatedURL)
        }
        XCTAssertNotNil(LauncherItem(title: "YouTube", url: "https://www.youtube.com").validatedURL)
        XCTAssertNotNil(LauncherItem(title: "Kontakt", url: "tel:0123456789").validatedURL)
    }
}

struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

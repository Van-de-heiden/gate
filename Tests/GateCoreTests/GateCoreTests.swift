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
            request: GateRequest(target: target("A")), minutes: minutes, consumed: GateState.everydayFreeMinutes, failures: failures,
            now: now, random: &random)
    }

    func testCurriculumHasSixteenCompletePathsAndUniqueQuestions() throws {
        let catalog = try catalog()
        try catalog.validate()
        XCTAssertEqual(catalog.paths.count, 16)
        XCTAssertEqual(catalog.lessons.count, 144)
        XCTAssertEqual(catalog.questions.count, 744)
        XCTAssertEqual(catalog.topics?.count, 12)
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

    func testLegacyTwoMinuteModeMigratesWithoutErasingUsage() {
        var state = activeState()
        state.freeMinutes = 2
        state.recordUsage(2, at: now)
        state.grants = [grant("A")]
        state.reconcileAllowance(at: now)
        XCTAssertEqual(state.freeMinutes, 30)
        XCTAssertEqual(state.remainingFreeMinutes, 28)
        XCTAssertFalse(state.limitReached)
        XCTAssertEqual(state.grants.count, 1)
        XCTAssertEqual(state.history.last?.confirmedMinutes, 2)
    }

    func testDefaultBudgetHasTwoMinutesLeftAtTwentyEightAndBlocksAtThirty() {
        var state = activeState()
        XCTAssertEqual(state.freeMinutes, 30)
        state.recordDailyUsageEvent("gate.usage.28", activity: state.dailyActivityName, at: now)
        XCTAssertEqual(state.remainingFreeMinutes, 2)
        XCTAssertFalse(state.limitReached)
        state.recordDailyUsageEvent("gate.usage.29", activity: state.dailyActivityName, at: now.addingTimeInterval(60))
        XCTAssertEqual(state.remainingFreeMinutes, 1)
        XCTAssertFalse(state.limitReached)
        state.recordDailyUsageEvent("gate.usage.30", activity: state.dailyActivityName, at: now.addingTimeInterval(120))
        XCTAssertEqual(state.remainingFreeMinutes, 0)
        XCTAssertTrue(state.limitReached)
    }

    func testPersistedSixtyMinuteBudgetMigratesWithoutResettingUsage() throws {
        var old = activeState()
        old.freeMinutes = 60
        old.selectionData = Data("saved selection".utf8)
        old.recordUsage(28, at: now)
        let activity = old.dailyActivityName
        var restored = try JSONDecoder().decode(GateState.self, from: JSONEncoder().encode(old))
        restored.reconcileAllowance(at: now)
        XCTAssertEqual(restored.freeMinutes, 30)
        XCTAssertEqual(restored.remainingFreeMinutes, 2)
        XCTAssertFalse(restored.limitReached)
        XCTAssertEqual(restored.confirmedMinutes, 28)
        XCTAssertEqual(restored.lastUsageUpdate, now)
        XCTAssertEqual(restored.history.last?.confirmedMinutes, 28)
        XCTAssertEqual(restored.selectionData, old.selectionData)
        XCTAssertEqual(restored.dailyActivityName, activity)
        restored.reconcileAllowance(at: now.addingTimeInterval(60))
        XCTAssertEqual(restored.remainingFreeMinutes, 2)
    }

    func testLoweredBudgetAppliesShieldsWithoutRevokingIndependentEarnedGrants() {
        var state = activeState()
        state.freeMinutes = 60
        state.recordUsage(35, at: now)
        state.grants = [grant("A"), grant("B")]
        let previousPolicy = state.protectionInputs
        state.reconcileAllowance(at: now)
        XCTAssertEqual(state.freeMinutes, 30)
        XCTAssertTrue(state.limitReached)
        XCTAssertEqual(state.remainingFreeMinutes, 0)
        XCTAssertNotEqual(state.protectionInputs, previousPolicy)
        XCTAssertEqual(state.activeGrants(at: now).count, 2)
        XCTAssertEqual(state.confirmedMinutes, 35)
        XCTAssertEqual(state.lastUsageUpdate, now)
        state.useEverydayMode()
        XCTAssertTrue(state.limitReached)
        XCTAssertEqual(state.remainingFreeMinutes, 0)
    }

    func testExplicitTestModeStillBlocksAtTwoMinutes() {
        var state = activeState()
        state.beginTestMode(at: now)
        state.recordUsage(1, at: now)
        state.reconcileAllowance(at: now)
        XCTAssertTrue(state.isTestMode)
        XCTAssertEqual(state.remainingFreeMinutes, 1)
        XCTAssertFalse(state.limitReached)
        state.recordUsage(2, at: now)
        XCTAssertTrue(state.limitReached)
    }

    func testEverydaySwitchRetainsUsageAndDoesNotChangeMonitorOrSelection() {
        var state = activeState()
        state.selectionData = Data("saved".utf8)
        state.beginTestMode(at: now)
        state.recordUsage(2, at: now)
        let activity = state.dailyActivityName
        state.requests = [GateRequest(target: target("A"))]
        state.useEverydayMode()
        XCTAssertFalse(state.limitReached)
        XCTAssertEqual(state.remainingFreeMinutes, 28)
        XCTAssertEqual(state.selectionData, Data("saved".utf8))
        XCTAssertEqual(state.dailyActivityName, activity)
        XCTAssertTrue(state.requests.isEmpty)
        state.recordUsage(2, at: now)
        XCTAssertFalse(state.limitReached)
        state.recordUsage(30, at: now)
        XCTAssertTrue(state.limitReached)
    }

    func testEverydaySwitchDoesNotGiveFreshAllowanceAfterExhaustion() {
        var state = activeState()
        state.beginTestMode(at: now)
        state.recordUsage(70, at: now)
        state.useEverydayMode()
        XCTAssertEqual(state.confirmedMinutes, 70)
        XCTAssertTrue(state.limitReached)
        XCTAssertEqual(state.remainingFreeMinutes, 0)
    }

    func testTestModeEndsAtNextDayAndOnLegacyRelaunch() throws {
        var state = activeState()
        state.beginTestMode(at: now)
        state.recordUsage(2, at: now)
        var restored = try JSONDecoder().decode(GateState.self, from: JSONEncoder().encode(state))
        restored.reconcileAllowance(at: now)
        XCTAssertTrue(restored.isTestMode)
        restored.rollDay(at: now.addingTimeInterval(86400))
        XCTAssertEqual(restored.freeMinutes, 30)
        XCTAssertEqual(restored.remainingFreeMinutes, 30)
        XCTAssertNil(restored.testModeStartedAt)
    }

    func testStaleLimitFlagCannotShowZeroWithOneConfirmedMinute() {
        var state = activeState()
        state.confirmedMinutes = 1
        state.limitReached = true
        state.reconcileAllowance(at: now)
        XCTAssertFalse(state.limitReached)
        XCTAssertEqual(state.remainingFreeMinutes, 29)
    }

    func testEveryDailyMonitorContainsBothBudgetsAndMonotonicCheckpoints() {
        XCTAssertTrue(GateState.usageCheckpoints.contains(2))
        XCTAssertTrue(GateState.usageCheckpoints.contains(30))
        XCTAssertTrue(GateState.usageCheckpoints.contains(60))
        XCTAssertTrue(GateState.usageCheckpoints.contains(1))
        for minute in [15, 16, 45, 46, 59, 61, 239, 240, 241, 330, 1440] {
            XCTAssertTrue(GateState.usageCheckpoints.contains(minute), "Missing minute \(minute)")
        }
        XCTAssertEqual(GateState.usageCheckpoints.count, 1440)
        XCTAssertEqual(GateState.usageCheckpoints.max(), 1440)
    }

    func testRemainingFifteenMinutesAdvancesOnNextRealMinute() {
        var state = activeState()
        state.recordDailyUsageEvent("gate.usage.15", activity: state.dailyActivityName, at: now)
        XCTAssertEqual(state.remainingFreeMinutes, 15)
        state.recordDailyUsageEvent("gate.usage.16", activity: state.dailyActivityName, at: now.addingTimeInterval(60))
        XCTAssertEqual(state.remainingFreeMinutes, 14)
        XCTAssertEqual(state.history.last?.confirmedMinutes, 16)
        XCTAssertEqual(state.lastUsageUpdate, now.addingTimeInterval(60))
    }

    func testDuplicateAndOlderCallbacksCannotPretendToBeNewUsage() {
        var state = activeState()
        state.recordDailyUsageEvent("gate.usage.45", activity: state.dailyActivityName, at: now)
        state.recordDailyUsageEvent("gate.usage.45", activity: state.dailyActivityName, at: now.addingTimeInterval(60))
        state.recordDailyUsageEvent("gate.usage.30", activity: state.dailyActivityName, at: now.addingTimeInterval(120))
        XCTAssertEqual(state.confirmedMinutes, 45)
        XCTAssertEqual(state.lastUsageUpdate, now)
        XCTAssertEqual(state.lastDailyMonitorCallbackAt, now.addingTimeInterval(120))
    }

    func testOnlyCanonicalRegisteredDailyEventsConfirmUsage() {
        var state = activeState()
        for name in ["45", "gate.used.45", "gate.usage.0", "gate.usage.-1", "gate.usage.1441", "gate.usage.045", "gate.usage.+45"] {
            state.recordDailyUsageEvent(name, activity: state.dailyActivityName, at: now)
        }
        state.recordDailyUsageEvent("gate.usage.45", activity: "gate.daily.retired", at: now)
        XCTAssertEqual(state.confirmedMinutes, 0)
        XCTAssertNil(state.lastUsageUpdate)
        XCTAssertNil(state.lastDailyMonitorCallbackAt)
        state.monitoringEnabled = false
        state.recordDailyUsageEvent("gate.usage.45", activity: state.dailyActivityName, at: now)
        XCTAssertEqual(state.confirmedMinutes, 0)
    }

    func testReconnectionAndElapsedWallTimeDoNotInventConsumption() {
        var state = activeState()
        state.recordUsage(15, at: now)
        state.grants = [grant("A", expires: 3600)]
        let later = now.addingTimeInterval(600)
        state.lastDailyMonitorInstallAt = later
        state.rollDay(at: later)
        state.reconcileAllowance(at: later)
        state.expireGrants(at: later)
        XCTAssertEqual(state.remainingFreeMinutes, 15)
        XCTAssertEqual(state.lastUsageUpdate, now)
        XCTAssertEqual(state.grants.count, 1)
        XCTAssertEqual(state.history.last?.confirmedMinutes, 15)
    }

    func testPreviousMonitorWorksUntilReplacementIsConfirmed() {
        var state = activeState()
        let previousName = state.dailyActivityName
        state.previousDailyActivityName = previousName
        state.dailyActivityName = "gate.daily.replacement"
        state.recordDailyUsageEvent("gate.usage.45", activity: previousName, at: now)
        XCTAssertEqual(state.confirmedMinutes, 45)
        state.recordDailyUsageEvent("gate.usage.46", activity: state.dailyActivityName, at: now.addingTimeInterval(60))
        state.previousDailyActivityName = nil
        state.recordDailyUsageEvent("gate.usage.50", activity: previousName, at: now.addingTimeInterval(120))
        XCTAssertEqual(state.confirmedMinutes, 46)
        XCTAssertEqual(state.lastUsageUpdate, now.addingTimeInterval(60))
    }

    func testDailyUsageCanPassTheOldFourHourCutoff() {
        var state = activeState()
        state.recordDailyUsageEvent("gate.usage.240", activity: state.dailyActivityName, at: now)
        state.recordDailyUsageEvent("gate.usage.330", activity: state.dailyActivityName, at: now.addingTimeInterval(5400))
        XCTAssertEqual(state.confirmedMinutes, 330)
        XCTAssertEqual(state.history.last?.confirmedMinutes, 330)
        XCTAssertTrue(state.limitReached)
        XCTAssertEqual(state.remainingFreeMinutes, 0)
    }

    func testMonitorChecksAreThrottledWithoutLosingForegroundRecovery() {
        XCTAssertTrue(GateMonitorCadence.shouldCheck(at: now, lastAttempt: nil, enabled: true, authorized: true, checking: false))
        for seconds in [0.0, 3, 30, 59] {
            XCTAssertFalse(GateMonitorCadence.shouldCheck(at: now.addingTimeInterval(seconds), lastAttempt: now,
                enabled: true, authorized: true, checking: false))
        }
        XCTAssertTrue(GateMonitorCadence.shouldCheck(at: now.addingTimeInterval(60), lastAttempt: now,
            enabled: true, authorized: true, checking: false))
        XCTAssertTrue(GateMonitorCadence.shouldCheck(at: now.addingTimeInterval(10), lastAttempt: now,
            enabled: true, authorized: true, checking: false, force: true))
        XCTAssertTrue(GateMonitorCadence.shouldCheck(at: now.addingTimeInterval(-60), lastAttempt: now,
            enabled: true, authorized: true, checking: false))
    }

    func testForcedCheckCannotOverlapOrIgnoreAuthorization() {
        XCTAssertFalse(GateMonitorCadence.shouldCheck(at: now, lastAttempt: nil,
            enabled: true, authorized: true, checking: true, force: true))
        XCTAssertFalse(GateMonitorCadence.shouldCheck(at: now, lastAttempt: nil,
            enabled: true, authorized: false, checking: false, force: true))
        XCTAssertFalse(GateMonitorCadence.shouldCheck(at: now, lastAttempt: nil,
            enabled: false, authorized: true, checking: false, force: true))
    }

    func testUsageRefreshDoesNotRewriteUnchangedShields() {
        var state = activeState()
        state.recordUsage(15, at: now)
        let before = state.protectionInputs
        state.recordUsage(16, at: now.addingTimeInterval(60))
        state.lastDailyMonitorCallbackAt = now.addingTimeInterval(60)
        XCTAssertEqual(state.protectionInputs, before)
        state.recordUsage(30, at: now.addingTimeInterval(900))
        XCTAssertNotEqual(state.protectionInputs, before)
    }

    func testGrantProgressChangesPolicyOnlyWhenExemptionEnds() {
        var state = activeState()
        state.grants = [grant("A"), grant("B")]
        let initial = state.protectionInputs
        state.grants[0].usedMinutes = 4
        XCTAssertEqual(state.protectionInputs, initial)
        state.grants[0].usedMinutes = 5
        XCTAssertNotEqual(state.protectionInputs, initial)
        XCTAssertEqual(state.protectionInputs.exemptTargetIDs, [target("B").id])
    }

    func testExpiredGrantMustChangeProtectionEvenPastItsDeadline() {
        var state = activeState()
        state.grants = [grant("A", expires: 5), grant("B", expires: 100)]
        let before = state.protectionInputs
        state.expireGrants(at: now.addingTimeInterval(6))
        XCTAssertNotEqual(state.protectionInputs, before)
        XCTAssertEqual(state.protectionInputs.exemptTargetIDs, [target("B").id])
    }

    func testOldStateDecodesWithoutMonitoringMetadata() throws {
        var state = activeState()
        state.recordUsage(15, at: now)
        state.lastDailyMonitorCallbackAt = now
        state.lastDailyMonitorInstallAt = now
        state.previousDailyActivityName = "gate.daily.previous"
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        for key in ["lastDailyMonitorCallbackAt", "lastDailyMonitorInstallAt", "previousDailyActivityName"] { json.removeValue(forKey: key) }
        let restored = try JSONDecoder().decode(GateState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.remainingFreeMinutes, 15)
        XCTAssertEqual(restored.lastUsageUpdate, now)
        XCTAssertNil(restored.lastDailyMonitorCallbackAt)
        XCTAssertNil(restored.previousDailyActivityName)
    }

    func testLessonLoadIsModerateIncreasingAndBounded() {
        XCTAssertEqual(LessonLoad.questionCount(minutes: 5, consumedMinutes: 30, failures: 0), 3)
        XCTAssertEqual(LessonLoad.questionCount(minutes: 10, consumedMinutes: 30, failures: 0), 5)
        XCTAssertEqual(LessonLoad.questionCount(minutes: 15, consumedMinutes: 30, failures: 0), 7)
        XCTAssertEqual(LessonLoad.questionCount(minutes: 5, consumedMinutes: 59, failures: 0), 3)
        XCTAssertEqual(LessonLoad.questionCount(minutes: 5, consumedMinutes: 60, failures: 0), 4)
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

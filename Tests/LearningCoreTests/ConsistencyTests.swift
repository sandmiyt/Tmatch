import XCTest
@testable import TijingLearningCore

final class ConsistencyTests: XCTestCase {
    private func cache() -> OrderedResponseCache {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return OrderedResponseCache(directory: folder)
    }
    func testLateResponseCannotOverwriteNewerCache() {
        let cache = cache()
        let old = cache.begin("user.1")
        let new = cache.begin("user.1")
        cache.store(Data("new".utf8), key: "user.1", ticket: new)
        cache.store(Data("old".utf8), key: "user.1", ticket: old)
        XCTAssertEqual(cache.read("user.1"), Data("new".utf8))
    }
    func testLogoutClearInvalidatesInFlightWrites() {
        let cache = cache()
        let ticket = cache.begin("user.1")
        cache.clear()
        cache.store(Data("private".utf8), key: "user.1", ticket: ticket)
        XCTAssertNil(cache.read("user.1"))
        let fresh = cache.begin("user.2")
        cache.store(Data("other".utf8), key: "user.2", ticket: fresh)
        XCTAssertNotNil(cache.read("user.2"))
    }
    func testRemovalInvalidatesOnlyItsOwnKey() {
        let cache = cache()
        let a = cache.begin("a"), b = cache.begin("b")
        cache.remove("a")
        cache.store(Data(), key: "a", ticket: a)
        cache.store(Data(), key: "b", ticket: b)
        XCTAssertNil(cache.read("a")); XCTAssertNotNil(cache.read("b"))
    }
    private func state(question: Int = 1, shared: Int = 1, finished: Bool = false,
                       feedback: Bool = false, progress: Int = 1, connected: Bool = true) throws -> BattleState {
        var object: [String: Any] = ["room_id": "r", "mode": "quick", "rule": "ranked",
            "question_index": question, "shared_question_index": shared, "total": 10, "finished": finished,
            "players": [["id": 1, "nickname": "test", "rating": 1000, "score": 0, "correct": 0,
                         "connected": connected, "progress": progress]]]
        if feedback { object["my_feedback"] = ["question_index": question, "picked": 0, "correct": true, "answer": 0] }
        return try JSONDecoder().decode(BattleState.self, from: JSONSerialization.data(withJSONObject: object))
    }
    func testBattleRejectsQuestionAndSharedProgressRollback() throws {
        XCTAssertFalse(try state(question: 1).canReplace(state(question: 2)))
        XCTAssertFalse(try state(shared: 1).canReplace(state(shared: 2)))
        XCTAssertFalse(try state(progress: 1).canReplace(state(progress: 2)))
    }
    func testBattleCannotLoseFeedbackOrReopenFinishedRoom() throws {
        XCTAssertFalse(try state().canReplace(state(feedback: true)))
        XCTAssertFalse(try state().canReplace(state(finished: true)))
        XCTAssertTrue(try state(finished: true).canReplace(state()))
    }
    func testSameQuestionUpdatesAndNextQuestionRemainAllowed() throws {
        XCTAssertTrue(try state(feedback: true).canReplace(state()))
        XCTAssertTrue(try state(connected: false).canReplace(state()))
        XCTAssertTrue(try state(question: 2, shared: 2).canReplace(state(feedback: true)))
    }
}

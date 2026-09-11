import XCTest
@testable import TijingLearningCore

@MainActor final class PracticeOutboxTests: XCTestCase {
    private let capability = Data(#"{"request_id_deduplication":true}"#.utf8)
    private let answer = Data(#"{"correct":true,"answer":1,"answers":[1],"favorite":false}"#.utf8)
    private func temporary() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    private func body(_ picked: Int = 1) -> PracticeAnswerBody {
        PracticeAnswerBody(questionID: 10, picked: .one(picked), elapsedMS: 500, mode: "random")
    }

    func testSaveBeforeSendAndRestoreAcknowledgedWithoutResending() async throws {
        let root = try temporary()
        var calls = 0
        let queue = PracticeOutbox(root: root, transport: { path, payload, _ in
            if payload == nil { return self.capability }
            calls += 1
            let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!.allObjects as! [URL]
            XCTAssertTrue(files.contains { $0.lastPathComponent == "attempt-q-10.json" })
            XCTAssertEqual((try JSONSerialization.jsonObject(with: payload!) as! [String: Any])["request_id"] as? String, "attempt-q-10")
            return self.answer
        })
        queue.activate(userID: 1, token: "a")
        let first: AnswerFeedback = try await queue.submit(id: "attempt-q-10", path: "/api/practice/answer", body: body(), userID: 1, token: "a")
        XCTAssertTrue(first.correct); XCTAssertEqual(calls, 1)
        let restored = PracticeOutbox(root: root, transport: { _, _, _ in XCTFail("Acknowledged record must not resend"); return self.answer })
        restored.activate(userID: 1, token: "a")
        let replay: AnswerFeedback = try await restored.submit(id: "attempt-q-10", path: "/api/practice/answer", body: body(0), userID: 1, token: "a")
        XCTAssertTrue(replay.correct)
        XCTAssertTrue(restored.pending.isEmpty)
    }

    func testLostResponseUsesFrozenPayloadAfterRestart() async throws {
        let root = try temporary()
        var sent: [Data] = []
        let queue = PracticeOutbox(root: root, transport: { _, payload, _ in
            guard let payload else { return self.capability }
            sent.append(payload); throw URLError(.networkConnectionLost)
        })
        queue.activate(userID: 1, token: "a")
        do {
            let _: AnswerFeedback = try await queue.submit(id: "lost", path: "/api/practice/answer", body: body(), userID: 1, token: "a")
            XCTFail("Expected network failure")
        } catch { }
        XCTAssertEqual(queue.pending.count, 1)
        let restored = PracticeOutbox(root: root, transport: { _, payload, _ in
            guard let payload else { return self.capability }
            sent.append(payload); return self.answer
        }, now: { Date().addingTimeInterval(600) })
        restored.activate(userID: 1, token: "a-new")
        let _: AnswerFeedback = try await restored.submit(id: "lost", path: "/api/practice/answer", body: body(0), userID: 1, token: "a-new")
        XCTAssertEqual(sent.count, 2); XCTAssertEqual(sent[0], sent[1])
    }

    func testAccountIsolationAndWrongTokenRejected() async throws {
        let root = try temporary()
        let queue = PracticeOutbox(root: root, transport: { _, payload, _ in
            guard payload != nil else { return self.capability }
            throw URLError(.notConnectedToInternet)
        })
        queue.activate(userID: 1, token: "a")
        do { let _: AnswerFeedback = try await queue.submit(id: "owner1", path: "/api/practice/answer", body: body(), userID: 1, token: "a") } catch { }
        queue.activate(userID: 2, token: "b")
        XCTAssertTrue(queue.pending.isEmpty)
        do {
            let _: AnswerFeedback = try await queue.submit(id: "wrong", path: "/api/practice/answer", body: body(), userID: 1, token: "a")
            XCTFail("Must reject stale owner")
        } catch { }
        queue.activate(userID: 1, token: "a-new")
        XCTAssertEqual(queue.pending.map(\.id), ["owner1"])
    }

    func testOldServerNeverReceivesWrite() async throws {
        var writes = 0
        let queue = PracticeOutbox(root: try temporary(), transport: { _, payload, _ in
            if payload != nil { writes += 1 }
            throw APIError(message: "old server", statusCode: 404, retryAfter: nil)
        })
        queue.activate(userID: 1, token: "a")
        do { let _: AnswerFeedback = try await queue.submit(id: "legacy", path: "/api/practice/answer", body: body(), userID: 1, token: "a") } catch { }
        XCTAssertEqual(writes, 0); XCTAssertFalse(queue.pending[0].blocked)
    }

    func testConflictBlocksAutomaticReplay() async throws {
        var writes = 0
        let queue = PracticeOutbox(root: try temporary(), transport: { _, payload, _ in
            guard payload != nil else { return self.capability }
            writes += 1; throw APIError(message: "conflict", statusCode: 409, retryAfter: nil)
        })
        queue.activate(userID: 1, token: "a")
        do { let _: AnswerFeedback = try await queue.submit(id: "conflict", path: "/api/practice/answer", body: body(), userID: 1, token: "a") } catch { }
        await queue.retryPending()
        XCTAssertEqual(writes, 1); XCTAssertTrue(queue.pending[0].blocked)
    }

    func testStorageFailurePreventsNetwork() async throws {
        let root = try temporary().appendingPathComponent("not-a-directory")
        try Data("blocked".utf8).write(to: root)
        let queue = PracticeOutbox(root: root, transport: { _, _, _ in XCTFail("No write before persistence"); return self.answer })
        queue.activate(userID: 1, token: "a")
        XCTAssertNotNil(queue.storageError)
        do { let _: AnswerFeedback = try await queue.submit(id: "disk", path: "/api/practice/answer", body: body(), userID: 1, token: "a"); XCTFail("Must fail") } catch { }
    }

    func testDecodeActualSharedBackendFixtures() throws {
        func fixture(_ name: String) throws -> Data {
            try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json")))
        }
        let batch = try JSONDecoder().decode(PracticeBatchResult.self, from: fixture("batch"))
        XCTAssertEqual(batch.total, 2); XCTAssertEqual(batch.correct, 2)
        let answer = try JSONDecoder().decode(AnswerFeedback.self, from: fixture("answer"))
        XCTAssertTrue(answer.correct)
    }

    func testConcurrentCallersShareOneFlight() async throws {
        var writes = 0
        let queue = PracticeOutbox(root: try temporary(), transport: { _, payload, _ in
            guard payload != nil else { return self.capability }
            writes += 1
            try await Task.sleep(for: .milliseconds(20))
            return self.answer
        })
        queue.activate(userID: 1, token: "a")
        let first = Task { () throws -> AnswerFeedback in
            try await queue.submit(id: "parallel", path: "/api/practice/answer", body: self.body(), userID: 1, token: "a")
        }
        let second = Task { () throws -> AnswerFeedback in
            try await queue.submit(id: "parallel", path: "/api/practice/answer", body: self.body(), userID: 1, token: "a")
        }
        _ = try await (first.value, second.value)
        XCTAssertEqual(writes, 1)
    }

    func testRateLimitRespectsRetryAfter() async throws {
        var clock = Date()
        var writes = 0
        let queue = PracticeOutbox(root: try temporary(), transport: { _, payload, _ in
            guard payload != nil else { return self.capability }
            writes += 1
            if writes == 1 { throw APIError(message: "rate limited", statusCode: 429, retryAfter: 120) }
            return self.answer
        }, now: { clock })
        queue.activate(userID: 1, token: "a")
        do { let _: AnswerFeedback = try await queue.submit(id: "rate", path: "/api/practice/answer", body: body(), userID: 1, token: "a") } catch { }
        clock.addTimeInterval(60)
        await queue.retryPending(); XCTAssertEqual(writes, 1)
        clock.addTimeInterval(61)
        await queue.retryPending(); XCTAssertEqual(writes, 2); XCTAssertTrue(queue.pending.isEmpty)
    }

    func testExplicitRetryCanRecoverBlockedReceiptWithoutChangingPayload() async throws {
        var clock = Date()
        var sent: [Data] = []
        let queue = PracticeOutbox(root: try temporary(), transport: { _, payload, _ in
            guard let payload else { return self.capability }
            sent.append(payload)
            if sent.count == 1 { throw APIError(message: "conflict", statusCode: 409, retryAfter: nil) }
            return self.answer
        }, now: { clock })
        queue.activate(userID: 1, token: "a")
        do { let _: AnswerFeedback = try await queue.submit(id: "recover", path: "/api/practice/answer", body: body(), userID: 1, token: "a") } catch { }
        clock.addTimeInterval(600)
        await queue.retryPending()
        XCTAssertEqual(sent.count, 1)
        let _: AnswerFeedback = try await queue.submit(id: "recover", path: "/api/practice/answer", body: body(0), userID: 1, token: "a")
        XCTAssertEqual(sent.count, 2); XCTAssertEqual(sent[0], sent[1])
        XCTAssertTrue(queue.pending.isEmpty)
    }

    func testAcknowledgedReceiptsAreLoadedLazilyAndPreserved() async throws {
        let root = try temporary()
        let queue = PracticeOutbox(root: root, transport: { _, payload, _ in payload == nil ? self.capability : self.answer })
        queue.activate(userID: 1, token: "a")
        for index in 0..<50 {
            let _: AnswerFeedback = try await queue.submit(id: "history-\(index)", path: "/api/practice/answer", body: body(), userID: 1, token: "a")
        }
        let restored = PracticeOutbox(root: root, transport: { _, _, _ in XCTFail("Must not resend archived answers"); return self.answer })
        restored.activate(userID: 1, token: "a")
        XCTAssertTrue(restored.entries.isEmpty)
        XCTAssertTrue(restored.contains("history-49"))
        XCTAssertEqual(restored.response("history-49", as: AnswerFeedback.self)?.correct, true)
        let _: AnswerFeedback = try await restored.submit(id: "history-49", path: "/api/practice/answer", body: body(0), userID: 1, token: "a")
        XCTAssertFalse(restored.contains("../history-49"))
    }
}

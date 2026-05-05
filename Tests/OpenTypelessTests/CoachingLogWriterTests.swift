import XCTest
@testable import OpenTypeless

final class CoachingLogWriterTests: XCTestCase {

    private func makeTempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    }

    private func makeEntry(original: String = "I want to discuss the timeline", ts: Date = Date()) -> CoachingEntry {
        CoachingEntry(
            ts: ts,
            original: original,
            issue: "discuss is not followed by about",
            suggestion: "I want to discuss the timeline",
            category: "collocation",
            sessionApp: "Slack"
        )
    }

    func testFirstWriteCreatesFileAndDirectory() async throws {
        let tmpDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let writer = CoachingLogWriter(directory: tmpDir)
        try await writer.append(makeEntry())

        let fileURL = tmpDir.appendingPathComponent("coaching.jsonl")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 1)

        let lineData = try XCTUnwrap(lines.first.map { String($0).data(using: .utf8)! })
        let obj = try JSONSerialization.jsonObject(with: lineData) as? [String: Any]
        XCTAssertNotNil(obj)
    }

    func testSubsequentWriteAppends() async throws {
        let tmpDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let writer = CoachingLogWriter(directory: tmpDir)
        try await writer.append(makeEntry(original: "First utterance"))
        try await writer.append(makeEntry(original: "Second utterance"))
        try await writer.append(makeEntry(original: "Third utterance"))

        let fileURL = tmpDir.appendingPathComponent("coaching.jsonl")
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 3)

        for line in lines {
            let data = try XCTUnwrap(String(line).data(using: .utf8))
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(obj)
        }
    }

    func testTimestampIsISO8601() async throws {
        let tmpDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 2026, month: 5, day: 2, hour: 11, minute: 42, second: 1)
        let knownDate = try XCTUnwrap(calendar.date(from: components))

        let writer = CoachingLogWriter(directory: tmpDir)
        try await writer.append(makeEntry(ts: knownDate))

        let fileURL = tmpDir.appendingPathComponent("coaching.jsonl")
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        let lineStr = try XCTUnwrap(contents.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init))
        let data = try XCTUnwrap(lineStr.data(using: .utf8))
        let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let ts = try XCTUnwrap(obj["ts"] as? String)

        XCTAssertTrue(ts.hasPrefix("2026-05-02T"), "Expected ISO 8601 string, got: \(ts)")
    }

    func testConcurrentWritesAreSafe() async throws {
        let tmpDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let writer = CoachingLogWriter(directory: tmpDir)
        let count = 5

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<count {
                group.addTask {
                    try await writer.append(self.makeEntry(original: "Utterance \(i)"))
                }
            }
            try await group.waitForAll()
        }

        let fileURL = tmpDir.appendingPathComponent("coaching.jsonl")
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, count)

        for line in lines {
            let data = try XCTUnwrap(String(line).data(using: .utf8))
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertNotNil(obj, "Line should be valid JSON: \(line)")
        }
    }
}

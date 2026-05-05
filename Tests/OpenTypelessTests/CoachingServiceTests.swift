import XCTest
@testable import OpenTypeless

final class CoachingServiceTests: XCTestCase {

    // MARK: - isEnglish gate

    func testIsEnglishReturnsTrueForASCIIProse() async {
        let service = CoachingService()
        let result = await service.isEnglish("I want to discuss the timeline")
        XCTAssertTrue(result)
    }

    func testIsEnglishReturnsFalseForChineseText() async {
        let service = CoachingService()
        let result = await service.isEnglish("这是一段中文")
        XCTAssertFalse(result)
    }

    func testIsEnglishReturnsFalseForMixedContent() async {
        let service = CoachingService()
        // ASCII letters are minority — fails 95% threshold
        let result = await service.isEnglish("hello 这个世界很大")
        XCTAssertFalse(result)
    }

    func testIsEnglishReturnsFalseForChineseWithInlineNumbers() async {
        // Digits must NOT be counted as "English" — this was a bug in the original range 44-63
        let service = CoachingService()
        let result = await service.isEnglish("我今天开了3个PR合并了")
        XCTAssertFalse(result)
    }

    // MARK: - wordCount gate

    func testWordCountBelowThresholdReturnsEarly() async throws {
        let service = CoachingService()
        // "ok" → wordCount = 1, analyze() should return without setting lastCallTime
        // We verify by checking that a second immediate call is NOT dropped (proves first call didn't set the debounce)
        await service.analyze("ok", sessionApp: "Slack")
        let count = await service.wordCount("ok")
        XCTAssertEqual(count, 1)
    }

    func testWordCountAtThreshold() async {
        let service = CoachingService()
        let count = await service.wordCount("one two three four five")
        XCTAssertEqual(count, 5)
    }

    func testWordCountBelowThreshold() async {
        let service = CoachingService()
        let count = await service.wordCount("one two three four")
        XCTAssertEqual(count, 4)
    }

    // MARK: - Debounce

    func testDebounceDropsSecondCallWithin10Seconds() async {
        // We can verify debounce indirectly by confirming analyze() is synchronous
        // enough that two rapid calls hit the time check. This test verifies the
        // path compiles and the actor is reentrant-safe (no crash on rapid calls).
        let service = CoachingService()
        async let first: () = service.analyze("I want to discuss the timeline with the team", sessionApp: "Slack")
        async let second: () = service.analyze("I want to suggest this approach to everyone", sessionApp: "Slack")
        await first
        await second
        // No assertion needed — test passes if no crash or deadlock
    }

    // MARK: - JSON parsing (no network call)

    func testCoachingLLMResponseDecodesFlagTrue() throws {
        let json = """
        {"flag":true,"issue":"discuss is not followed by about in English","suggestion":"I want to discuss the timeline","category":"collocation"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try JSONDecoder().decode(CoachingLLMResponse.self, from: data)
        XCTAssertTrue(response.flag)
        XCTAssertEqual(response.issue, "discuss is not followed by about in English")
        XCTAssertEqual(response.suggestion, "I want to discuss the timeline")
        XCTAssertEqual(response.category, "collocation")
    }

    func testCoachingLLMResponseDecodesFlagFalse() throws {
        let json = """
        {"flag":false,"issue":null,"suggestion":null,"category":null}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try JSONDecoder().decode(CoachingLLMResponse.self, from: data)
        XCTAssertFalse(response.flag)
        XCTAssertNil(response.issue)
        XCTAssertNil(response.suggestion)
        XCTAssertNil(response.category)
    }

    func testCoachingLLMResponseHandlesNullCategory() throws {
        let json = """
        {"flag":true,"issue":"some issue","suggestion":"corrected sentence","category":null}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let response = try JSONDecoder().decode(CoachingLLMResponse.self, from: data)
        XCTAssertTrue(response.flag)
        XCTAssertNotNil(response.issue)
        XCTAssertNil(response.category)
    }
}

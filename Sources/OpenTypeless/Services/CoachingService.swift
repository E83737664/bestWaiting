import Foundation
import os

struct CoachingLLMResponse: Decodable {
    let flag: Bool
    let issue: String?
    let suggestion: String?
    let category: String?
}

struct CoachingEntry: Encodable {
    let v: Int = 1
    let ts: Date
    let original: String
    let issue: String
    let suggestion: String
    let category: String?
    let sessionApp: String

    enum CodingKeys: String, CodingKey {
        case v, ts, original, issue, suggestion, category
        case sessionApp = "session_app"
    }
}

private struct KimiCredentials: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Double

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }
}

private struct KimiTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Double

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

// Pipeline: analyze() → isEnglish/wordCount/debounce gates → callLLM() → CoachingLogWriter.append()
// Uses Kimi coding API with JWT token management (auto-refresh via ~/.kimi/credentials/kimi-code.json).

actor CoachingService {
    private var lastCallTime: Date?
    private let logWriter = CoachingLogWriter()

    private static let credPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".kimi/credentials/kimi-code.json")
    private static let clientID = "17e5f671-d194-4dfb-9706-5516cb48c098"
    private static let apiURL = URL(string: "https://api.kimi.com/coding/v1/chat/completions")!
    private static let refreshURL = URL(string: "https://auth.kimi.com/api/oauth/token")!
    private static let deviceID: String = {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kimi/device_id")
        return (try? String(contentsOf: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
    }()
    private static let mshHeaders: [String: String] = [
        "User-Agent": "KimiCLI/1.40.0",
        "X-Msh-Platform": "kimi_cli",
        "X-Msh-Version": "1.40.0",
        "X-Msh-Device-Name": Host.current().localizedName ?? "",
        "X-Msh-Device-Model": "macOS",
        "X-Msh-Os-Version": ProcessInfo.processInfo.operatingSystemVersionString,
        "X-Msh-Device-Id": deviceID
    ]

    func analyze(_ text: String, sessionApp: String) async {
        let now = Date()
        if let last = lastCallTime, now.timeIntervalSince(last) < 10 { return }
        guard isEnglish(text), wordCount(text) >= 5 else { return }
        lastCallTime = now
        guard let entry = try? await callLLM(text, sessionApp: sessionApp) else { return }
        try? await logWriter.append(entry)
    }

    func isEnglish(_ text: String) -> Bool {
        let nonWhitespace = text.unicodeScalars.filter { $0.value > 32 }
        guard !nonWhitespace.isEmpty else { return false }
        let englishChars = nonWhitespace.filter {
            ($0.value >= 65 && $0.value <= 90) ||   // A-Z
            ($0.value >= 97 && $0.value <= 122) ||  // a-z
            ($0.value >= 32 && $0.value <= 47) ||   // space .,-!?
            ($0.value >= 58 && $0.value <= 64)      // :;<=>?@
        }
        return Double(englishChars.count) / Double(nonWhitespace.count) >= 0.95
    }

    func wordCount(_ text: String) -> Int {
        text.split(separator: " ").count
    }

    private func loadOrRefreshKimiToken() async throws -> String {
        let data = try Data(contentsOf: Self.credPath)
        var creds = try JSONDecoder().decode(KimiCredentials.self, from: data)

        let now = Date().timeIntervalSince1970
        if creds.expiresAt > now + 300 {
            return creds.accessToken
        }

        var req = URLRequest(url: Self.refreshURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        Self.mshHeaders.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        var comps = URLComponents()
        comps.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: creds.refreshToken)
        ]
        req.httpBody = comps.query?.data(using: .utf8)

        let (respData, _) = try await URLSession.shared.data(for: req)
        let tokenResp = try JSONDecoder().decode(KimiTokenResponse.self, from: respData)

        creds = KimiCredentials(
            accessToken: tokenResp.accessToken,
            refreshToken: tokenResp.refreshToken,
            expiresAt: now + tokenResp.expiresIn
        )
        let savedData = try JSONEncoder().encode(creds)
        try savedData.write(to: Self.credPath)

        return tokenResp.accessToken
    }

    private func callLLM(_ text: String, sessionApp: String) async throws -> CoachingEntry? {
        let accessToken = try await loadOrRefreshKimiToken()

        let systemPrompt = """
        You are a fluency coach for non-native English speakers with a Chinese background.
        Analyze this spoken English utterance for unnatural phrasing, Chinglish patterns, or awkward collocations.

        What to flag:
        - Chinglish: calques or collocations directly translated from Chinese (e.g., "discuss about", "give a suggestion to")
        - Collocation errors: wrong preposition or verb-noun pairing (e.g., "make a research" → "do research")
        - Hedge overuse: excessive filler in professional English (e.g., "I think maybe perhaps we could possibly consider...")
        - Word choice: a more natural or idiomatic word exists for the context

        What NOT to flag:
        - Minor grammar mistakes that don't affect naturalness (missing article, minor tense issue)
        - Informal or casual speech that is intentional
        - Short utterances that are complete and natural as-is

        Respond in JSON only: {"flag": true or false, "issue": "one sentence or null", "suggestion": "corrected utterance or null", "category": "chinglish" or "collocation" or "hedge" or "word_choice" or null}

        Be conservative. Only flag issues you are highly confident about. If in doubt, return flag: false.
        """

        let requestBody: [String: Any] = [
            "model": "kimi-for-coding",
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "max_tokens": 8000
        ]

        var req = URLRequest(url: Self.apiURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        Self.mshHeaders.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        req.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        req.timeoutInterval = 120

        let (respData, httpResponse) = try await URLSession.shared.data(for: req)
        guard (httpResponse as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        guard let result = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
              let choices = result["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              !content.isEmpty,
              let contentData = content.data(using: .utf8) else { return nil }

        let response = try JSONDecoder().decode(CoachingLLMResponse.self, from: contentData)
        guard response.flag,
              let issue = response.issue,
              let suggestion = response.suggestion else { return nil }

        return CoachingEntry(
            ts: Date(),
            original: text,
            issue: issue,
            suggestion: suggestion,
            category: response.category,
            sessionApp: sessionApp
        )
    }
}

actor CoachingLogWriter {
    private let fileURL: URL
    private static let logger = Logger(subsystem: "com.scinttt.open-typeless", category: "coaching")

    // directory: override for testing; nil uses ~/Library/Application Support/OpenTypeless/
    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenTypeless")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("CoachingLogWriter: failed to create log directory: \(error.localizedDescription)")
        }
        fileURL = dir.appendingPathComponent("coaching.jsonl")
    }

    func append(_ entry: CoachingEntry) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        var line = data
        line.append(0x0A)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }

        do {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { handle.closeFile() }
            handle.seekToEndOfFile()
            handle.write(line)
        } catch {
            Self.logger.error("CoachingLogWriter: write failed: \(error.localizedDescription)")
            throw error
        }
    }
}

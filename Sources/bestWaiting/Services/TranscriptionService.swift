import Foundation
import OpenAI

enum TranscriptionError: Error, LocalizedError {
    case noAPIKey
    case noResult
    case failed(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "API key not configured"
        case .noResult: return "No transcription result"
        case .failed(let error): return "Transcription failed: \(error.localizedDescription)"
        }
    }
}

enum APIProvider: String, CaseIterable, Identifiable {
    case openAI = "openai"
    case custom = "custom"
    case local = "local"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .custom: return "Custom (OpenAI-compatible)"
        case .local: return "Local (Whisper)"
        }
    }
}

final class TranscriptionService {
    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: "apiKey")
            ?? ProcessInfo.processInfo.environment["AI_BUILDER_TOKEN"]
            ?? ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "apiKey") }
    }

    static var provider: APIProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: "apiProvider") ?? "openai"
            return APIProvider(rawValue: raw) ?? .openAI
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "apiProvider") }
    }

    static var customHost: String {
        get { UserDefaults.standard.string(forKey: "customHost") ?? "space.ai-builders.com" }
        set { UserDefaults.standard.set(newValue, forKey: "customHost") }
    }

    static var customBasePath: String {
        get { UserDefaults.standard.string(forKey: "customBasePath") ?? "/backend/v1" }
        set { UserDefaults.standard.set(newValue, forKey: "customBasePath") }
    }

    static var model: String {
        get { UserDefaults.standard.string(forKey: "transcriptionModel") ?? "gpt-4o-mini-transcribe" }
        set { UserDefaults.standard.set(newValue, forKey: "transcriptionModel") }
    }

    static var localModel: String {
        get { UserDefaults.standard.string(forKey: "localWhisperModel") ?? "base" }
        set { UserDefaults.standard.set(newValue, forKey: "localWhisperModel") }
    }

    func preload() {}

    func transcribe(audioURL: URL) async throws -> String {
        if Self.provider == .local {
            return try await transcribeLocally(audioURL: audioURL)
        }

        let key = Self.apiKey
        guard !key.isEmpty else { throw TranscriptionError.noAPIKey }

        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioURL)
        } catch {
            throw TranscriptionError.failed(error)
        }

        let fileName = audioURL.lastPathComponent
        let client = buildClient(apiKey: key)

        let query = AudioTranscriptionQuery(
            file: audioData,
            fileType: fileName.hasSuffix(".m4a") ? .m4a : .wav,
            model: .init(Self.model)
        )

        let text: String
        do {
            let result = try await client.audioTranscriptions(query: query)
            text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            let message: String
            if let urlError = error as? URLError {
                message = "Network error: \(urlError.localizedDescription)"
            } else {
                message = "\(error)"
            }
            throw TranscriptionError.failed(
                NSError(domain: "TranscriptionService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: message])
            )
        }

        guard !text.isEmpty else { throw TranscriptionError.noResult }
        return text
    }

    // MARK: - Local Whisper via subprocess

    private func transcribeLocally(audioURL: URL) async throws -> String {
        let modelName = Self.localModel
        let audioPath = audioURL.path

        let outputFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".whisper_out")

        return try await Task.detached(priority: .userInitiated) {
            let python = Self.findPython()
            let outPath = outputFile.path

            // Write result to a file directly — avoids all stdout buffering issues
            let script = """
import whisper, sys, os, shutil
# Save a debug copy of the audio file
shutil.copy(sys.argv[1], '/tmp/last_recording_debug.m4a')
model = whisper.load_model('\(modelName)')
result = model.transcribe(sys.argv[1])
text = result['text'].strip()
sys.stderr.write('whisper_text_repr: ' + repr(text) + '\\n')
sys.stderr.flush()
with open(sys.argv[2], 'w', encoding='utf-8') as f:
    f.write(text)
"""
            defer { try? FileManager.default.removeItem(at: outputFile) }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: python)
            process.arguments = ["-c", script, audioPath, outPath]

            // Inject PATH so whisper can find ffmpeg (typically in /opt/homebrew/bin)
            var env = ProcessInfo.processInfo.environment
            let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
            let currentPath = env["PATH"] ?? ""
            env["PATH"] = (extraPaths + [currentPath])
                .filter { !$0.isEmpty }
                .joined(separator: ":")
            process.environment = env

            // Capture stderr to a debug file so we can see whisper's diagnostic output
            let debugFile = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".whisper_debug")
            FileManager.default.createFile(atPath: debugFile.path, contents: nil)
            process.standardOutput = FileHandle.nullDevice
            process.standardError = (try? FileHandle(forWritingTo: debugFile)) ?? FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                throw TranscriptionError.failed(error)
            }
            process.waitUntilExit()

            (process.standardError as? FileHandle)?.closeFile()
            let debugLog = (try? String(contentsOf: debugFile, encoding: .utf8)) ?? ""
            try? FileManager.default.removeItem(at: debugFile)
            print("[LocalWhisper] stderr: \(debugLog)")

            if process.terminationStatus != 0 {
                throw TranscriptionError.failed(
                    NSError(domain: "LocalWhisper", code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: debugLog.isEmpty ? "Whisper exited with code \(process.terminationStatus)" : debugLog])
                )
            }

            let text = (try? String(contentsOf: outputFile, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            print("[LocalWhisper] result text repr: \(text.debugDescription)")
            guard !text.isEmpty else { throw TranscriptionError.noResult }
            return text
        }.value
    }

    private static func findPython() -> String {
        let candidates = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "/usr/bin/python3"
    }

    // MARK: - Remote client builder

    private func buildClient(apiKey: String) -> OpenAI {
        switch Self.provider {
        case .openAI, .local:
            return OpenAI(apiToken: apiKey)
        case .custom:
            // Parse full URL like "http://localhost:8080" from the host field
            let raw = Self.customHost
            let urlString = raw.hasPrefix("http") ? raw : "https://\(raw)"
            let url = URL(string: urlString)
            let scheme = url?.scheme ?? "https"
            let host = url?.host ?? raw
            let port = url?.port ?? (scheme == "https" ? 443 : 80)
            let basePath = Self.customBasePath.isEmpty ? "/v1" : Self.customBasePath

            let config = OpenAI.Configuration(
                token: apiKey,
                host: host,
                port: port,
                scheme: scheme,
                basePath: basePath
            )
            return OpenAI(configuration: config)
        }
    }
}

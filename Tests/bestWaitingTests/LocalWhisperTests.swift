import XCTest
@testable import bestWaiting

final class LocalWhisperTests: XCTestCase {

    func testLocalWhisperTranscribesAudio() async throws {
        // Set up local mode
        let originalProvider = TranscriptionService.provider
        let originalModel = TranscriptionService.localModel
        defer {
            TranscriptionService.provider = originalProvider
            TranscriptionService.localModel = originalModel
        }
        TranscriptionService.provider = .local
        TranscriptionService.localModel = "base"

        // Generate a test audio file via macOS `say`
        let tmpAiff = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".aiff")
        let tmpM4a = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        defer {
            try? FileManager.default.removeItem(at: tmpAiff)
            try? FileManager.default.removeItem(at: tmpM4a)
        }

        let sayProc = Process()
        sayProc.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        sayProc.arguments = ["-o", tmpAiff.path, "hello whisper test"]
        try sayProc.run()
        sayProc.waitUntilExit()

        let ffmpegProc = Process()
        ffmpegProc.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
            .existsOnDisk ? URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
            : URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        ffmpegProc.arguments = ["-y", "-i", tmpAiff.path, tmpM4a.path]
        ffmpegProc.standardOutput = Pipe()
        ffmpegProc.standardError = Pipe()
        try ffmpegProc.run()
        ffmpegProc.waitUntilExit()

        XCTAssertTrue(FileManager.default.fileExists(atPath: tmpM4a.path), "m4a not created")

        let service = TranscriptionService()
        let result = try await service.transcribe(audioURL: tmpM4a)

        XCTAssertFalse(result.isEmpty, "Transcription should not be empty")
        print("[LocalWhisperTest] Transcription result: \(result)")
    }
}

private extension URL {
    var existsOnDisk: Bool { FileManager.default.fileExists(atPath: path) }
}

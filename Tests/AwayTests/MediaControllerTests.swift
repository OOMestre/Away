import XCTest
@testable import AwayCore

private actor RecordingScriptExecutor: AppleScriptExecuting {
    var sources: [String] = []
    var response = ""

    func execute(_ source: String) async throws -> String {
        sources.append(source)
        return response
    }

    func setResponse(_ value: String) { response = value }
    func recordedSources() -> [String] { sources }
}

final class MediaControllerTests: XCTestCase {
    func testCommandsTargetOnlySelectedPlayer() async throws {
        let executor = RecordingScriptExecutor()
        let controller = AppleScriptMediaController(executor: executor)

        try await controller.perform(.playPause, in: .music)
        try await controller.perform(.previous, in: .spotify)
        try await controller.perform(.next, in: .spotify)

        let sources = await executor.recordedSources()
        XCTAssertEqual(sources, [
            "tell application id \"com.apple.Music\" to playpause\nreturn \"\"",
            "tell application id \"com.spotify.client\" to previous track\nreturn \"\"",
            "tell application id \"com.spotify.client\" to next track\nreturn \"\"",
        ])
    }

    func testCurrentTrackAndUnavailableTrack() async throws {
        let executor = RecordingScriptExecutor()
        let controller = AppleScriptMediaController(executor: executor)
        await executor.setResponse("Song title\u{1F}Artist name")
        let track = try await controller.nowPlaying(in: .music)
        XCTAssertEqual(track, MediaTrack(title: "Song title", artist: "Artist name"))

        await executor.setResponse("")
        let unavailable = try await controller.nowPlaying(in: .spotify)
        XCTAssertNil(unavailable)
        let sources = await executor.recordedSources()
        XCTAssertTrue(sources[0].contains("tell application id \"com.apple.Music\""))
        XCTAssertTrue(sources[1].contains("tell application id \"com.spotify.client\""))
    }
}

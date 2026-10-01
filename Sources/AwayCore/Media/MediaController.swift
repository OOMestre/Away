import Foundation

public enum MediaApp: String, CaseIterable, Sendable {
    case music = "com.apple.Music"
    case spotify = "com.spotify.client"

    public var name: String {
        switch self {
        case .music: "Music"
        case .spotify: "Spotify"
        }
    }
}

public enum MediaAction: Sendable {
    case playPause
    case previous
    case next
}

public struct MediaTrack: Equatable, Sendable {
    public let title: String
    public let artist: String

    public init(title: String, artist: String) {
        self.title = title
        self.artist = artist
    }
}

public protocol MediaControlling: Sendable {
    func perform(_ action: MediaAction, in app: MediaApp) async throws
    func nowPlaying(in app: MediaApp) async throws -> MediaTrack?
}

public protocol AppleScriptExecuting: Sendable {
    func execute(_ source: String) async throws -> String
}

/// Runs AppleScript on the main thread, where `NSAppleScript` must be used.
/// Scripts from `AppleScriptMediaController` carry their own short timeout,
/// so a stuck player cannot freeze Away.
public struct SystemAppleScriptExecutor: AppleScriptExecuting {
    public init() {}

    public func execute(_ source: String) async throws -> String {
        try await MainActor.run {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source),
                  let result = script.executeAndReturnError(&error).stringValue else {
                throw MediaControlError.script(error?[NSAppleScript.errorMessage] as? String ?? "AppleScript failed")
            }
            return result
        }
    }
}

public enum MediaControlError: Error, LocalizedError {
    case script(String)

    public var errorDescription: String? {
        switch self {
        case let .script(message): message
        }
    }
}

public struct AppleScriptMediaController: MediaControlling {
    private let executor: any AppleScriptExecuting

    public init(executor: any AppleScriptExecuting = SystemAppleScriptExecutor()) {
        self.executor = executor
    }

    public func perform(_ action: MediaAction, in app: MediaApp) async throws {
        let command: String
        switch action {
        case .playPause: command = "playpause"
        case .previous: command = "previous track"
        case .next: command = "next track"
        }
        _ = try await executor.execute(Self.withTimeout("tell application id \"\(app.rawValue)\" to \(command)\nreturn \"\""))
    }

    public func nowPlaying(in app: MediaApp) async throws -> MediaTrack? {
        let source = """
        tell application id "\(app.rawValue)"
            if player state is stopped then return ""
            return (name of current track as text) & (ASCII character 31) & (artist of current track as text)
        end tell
        """
        let value = try await executor.execute(Self.withTimeout(source))
        let parts = value.split(separator: "\u{1F}", maxSplits: 1, omittingEmptySubsequences: false)
        guard let title = parts.first.map(String.init), !title.isEmpty else { return nil }
        return MediaTrack(title: title, artist: parts.count > 1 ? String(parts[1]) : "")
    }

    /// Seconds an Apple Event may wait for the player before failing.
    public static let timeoutSeconds = 3

    static func withTimeout(_ source: String) -> String {
        "with timeout of \(timeoutSeconds) seconds\n\(source)\nend timeout"
    }
}

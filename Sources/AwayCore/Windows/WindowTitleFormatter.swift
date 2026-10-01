import Foundation

/// Formats and sanitizes window titles for preview cards.
public enum WindowTitleFormatter {
    /// Cleans internal line breaks, control characters, tabs, and leading/trailing whitespace.
    public static func clean(_ title: String) -> String {
        title
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns the sanitized display title for a window, using an optional fallback
    /// (such as the app name or "Untitled") if the window title is empty.
    public static func displayTitle(for title: String, fallbackAppName: String? = nil) -> String {
        let cleaned = clean(title)
        if !cleaned.isEmpty {
            return cleaned
        }
        if let fallback = fallbackAppName.map(clean), !fallback.isEmpty {
            return fallback
        }
        return "Untitled"
    }

    /// Truncates a string to a maximum character length, appending an ellipsis if truncated.
    ///
    /// Respects Unicode extended grapheme clusters to avoid breaking complex glyphs or emoji.
    ///
    /// - Parameters:
    ///   - text: The original string.
    ///   - maxLength: The maximum allowed length including ellipsis. Must be at least 1.
    ///   - ellipsis: The truncation indicator (defaults to `"…"`).
    /// - Returns: The original string if within `maxLength`, otherwise truncated with ellipsis.
    public static func truncate(_ text: String, maxLength: Int, ellipsis: String = "…") -> String {
        guard maxLength > 0 else { return "" }
        let cleaned = clean(text)
        guard cleaned.count > maxLength else { return cleaned }

        let ellipsisCount = ellipsis.count
        guard maxLength > ellipsisCount else {
            return String(ellipsis.prefix(maxLength))
        }

        let prefixLength = maxLength - ellipsisCount
        let prefix = cleaned.prefix(prefixLength).trimmingCharacters(in: .whitespaces)
        return prefix + ellipsis
    }

    /// Returns `true` if the given title would be truncated under `maxLength`.
    public static func isTruncated(_ text: String, maxLength: Int) -> Bool {
        guard maxLength > 0 else { return false }
        return clean(text).count > maxLength
    }
}

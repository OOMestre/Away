import os

/// Unified logging. Read with:
/// `log stream --predicate 'subsystem == "com.oomestre.away"' --level debug`
public enum AwayLog {
    public static let subsystem = "com.oomestre.away"
    public static let hover = Logger(subsystem: subsystem, category: "hover")
    public static let previews = Logger(subsystem: subsystem, category: "previews")
}

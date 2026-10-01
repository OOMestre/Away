#!/usr/bin/env swift
// Away release notes generator.
// Groups conventional commits between two git refs into clean markdown notes.

import Foundation

// MARK: - Arguments

struct Options {
    var fromRef: String?
    var toRef = "HEAD"
    var version: String?
    var releaseType: String?
    var outputFile: String?
    var includeRawLog = false
}

func printUsage() {
    print("""
    Usage: generate-release-notes.swift [options]

    Extracts clean change summaries from git commits for release notes.

    Options:
      --from <ref>                 Start git commit/tag range (exclusive)
      --to <ref>                   End git commit/tag range (inclusive, default: HEAD)
      --version <version>          Release version title (e.g. v0.1.0 or v0.1.0-beta.1)
      --release-type <type>        staging, production or beta
      -o, --output <path>          Output file path (default: stdout)
      --include-raw-log            Include raw git commit log in notes
      -h, --help                   Show this help message
    """)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
    exit(1)
}

func parseOptions() -> Options {
    var options = Options()
    var arguments = CommandLine.arguments.dropFirst()

    func value(for flag: String) -> String {
        guard let next = arguments.popFirst() else { fail("Missing value for \(flag)") }
        return next
    }

    while let argument = arguments.popFirst() {
        switch argument {
        case "--from": options.fromRef = value(for: argument)
        case "--to": options.toRef = value(for: argument)
        case "--version": options.version = value(for: argument)
        case "--release-type":
            let type = value(for: argument)
            guard ["staging", "production", "beta"].contains(type) else {
                fail("--release-type must be staging, production or beta")
            }
            options.releaseType = type
        case "-o", "--output": options.outputFile = value(for: argument)
        case "--include-raw-log": options.includeRawLog = true
        case "-h", "--help":
            printUsage()
            exit(0)
        default: fail("Unknown option: \(argument). Run with --help for usage.")
        }
    }
    return options
}

// MARK: - Git

let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

func runGit(_ arguments: [String]) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git"] + arguments
    process.currentDirectoryURL = repositoryRoot

    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
    } catch {
        return ""
    }
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return "" }
    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}

func lines(_ text: String) -> [String] {
    text.split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
}

func currentVersion() -> String {
    let file = repositoryRoot.appendingPathComponent("VERSION")
    guard let contents = try? String(contentsOf: file, encoding: .utf8) else { return "0.1.0" }
    return contents.trimmingCharacters(in: .whitespacesAndNewlines)
}

struct Commit {
    let hash: String
    let subject: String
    let author: String
    let date: String
}

func commits(from fromRef: String?, to toRef: String) -> [Commit] {
    let range = fromRef.map { "\($0)..\(toRef)" } ?? toRef
    let log = runGit(["log", "--pretty=format:%h|%s|%an|%ad", "--date=short", range])
    return lines(log).compactMap { line in
        let parts = line.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4 else { return nil }
        return Commit(hash: parts[0], subject: parts[1], author: parts[2], date: parts[3])
    }
}

// MARK: - Categorization

struct Category {
    let id: String
    let title: String
    let prefixes: [String]
}

let categories = [
    Category(id: "features", title: "Enhancements & Features", prefixes: ["feat", "feature", "add"]),
    Category(id: "fixes", title: "Bug Fixes & Stability", prefixes: ["fix", "bugfix", "patch"]),
    Category(id: "architecture", title: "Architectural & UI Refinements",
             prefixes: ["refactor", "architecture", "ui", "ux", "style", "perf", "performance"]),
    Category(id: "docs", title: "Documentation & Guides", prefixes: ["docs", "doc"]),
    Category(id: "ci", title: "Build & Infrastructure", prefixes: ["ci", "chore", "build", "tooling"]),
    Category(id: "tests", title: "Testing & Verification", prefixes: ["test", "tests"]),
]

/// Matches `type(scope): description` and captures the type and description.
let conventionalPattern = try! NSRegularExpression(pattern: #"^([A-Za-z0-9_\-]+)(?:\([^)]+\))?:\s*(.*)$"#)

/// Strips leading emoji, symbols and formatting noise from commit text.
func cleanSymbols(_ text: String) -> String {
    let leadingNoise = text.prefix { character in
        !(character.isLetter || character.isNumber || character.isWhitespace || "_()[]-".contains(character))
    }
    return String(text.dropFirst(leadingNoise.count)).trimmingCharacters(in: .whitespaces)
}

func capitalizedFirst(_ text: String) -> String {
    text.prefix(1).uppercased() + text.dropFirst()
}

func categorize(_ subject: String) -> (category: String, text: String) {
    let cleaned = cleanSymbols(subject)
    let range = NSRange(cleaned.startIndex..., in: cleaned)

    if let match = conventionalPattern.firstMatch(in: cleaned, range: range),
       let typeRange = Range(match.range(at: 1), in: cleaned),
       let descriptionRange = Range(match.range(at: 2), in: cleaned) {
        let type = cleaned[typeRange].lowercased()
        let description = cleanSymbols(String(cleaned[descriptionRange]))
        if !description.isEmpty {
            let category = categories.first { $0.prefixes.contains(type) }?.id ?? "other"
            return (category, capitalizedFirst(description))
        }
    }
    return ("other", capitalizedFirst(cleaned))
}

// MARK: - Notes

func generateNotes(_ options: Options) -> String {
    let tags = lines(runGit(["tag", "--sort=-creatordate"]))
    let toRef = options.toRef
    var fromRef = options.fromRef

    if fromRef == nil, !tags.isEmpty {
        if tags.contains(toRef) {
            fromRef = tags.count > 1 ? tags[1] : nil
        } else {
            fromRef = tags[0]
        }
    }

    let commitList = commits(from: fromRef, to: toRef)

    var version = options.version ?? (toRef != "HEAD" && tags.contains(toRef) ? toRef : "v\(currentVersion())")
    if !version.lowercased().hasPrefix("v") {
        version = "v\(version)"
    }

    let lowercasedVersion = version.lowercased()
    let isPrerelease = ["beta", "rc", "alpha"].contains { lowercasedVersion.contains($0) }
    let releaseType = options.releaseType.map { capitalizedFirst($0) }
        ?? (isPrerelease ? "Staging Beta" : "Production Release")

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"

    var grouped: [String: [(text: String, hash: String)]] = [:]
    for commit in commitList {
        let (category, text) = categorize(commit.subject)
        grouped[category, default: []].append((text, commit.hash))
    }

    var output = [
        "# Away \(version) Release Notes",
        "",
        "- **Release Date:** `\(formatter.string(from: Date()))`",
        "- **Release Stage:** `\(releaseType)`",
    ]
    if let fromRef {
        output.append("- **Commit Range:** `\(fromRef)...\(toRef)` (\(commitList.count) commits)")
    } else {
        output.append("- **Total Commits Included:** \(commitList.count)")
    }
    output += ["- **Target OS:** macOS 14.0+ (Sonoma or later)", "", "---", "", "## What's Changed", ""]

    let sections = categories.map { ($0.id, $0.title) } + [("other", "Additional Improvements & Tooling")]
    var hasItems = false
    for (id, title) in sections {
        guard let items = grouped[id], !items.isEmpty else { continue }
        hasItems = true
        output.append("### \(title)")
        output += items.map { "- \($0.text) (`\($0.hash)`)" }
        output.append("")
    }
    if !hasItems {
        output += [
            "### General Improvements",
            "- Routine maintenance, performance optimizations, and stability enhancements.",
            "",
        ]
    }

    output += ["---", "", "### Installation & Verification"]
    if lowercasedVersion.contains("beta") {
        output += [
            "1. Download `Away-macOS.dmg` from the release assets.",
            "2. Open the `.dmg` and drag `Away Staging.app` to your `/Applications` folder.",
            "3. Verify all test suites pass locally using `make test`.",
        ]
    } else {
        output += [
            "1. Download `Away-macOS.dmg` from the release assets.",
            "2. Open the `.dmg` and drag `Away.app` to your `/Applications` directory.",
            "3. Launch Away and make your Mac yours.",
        ]
    }
    output += ["", "### Full Changelog: `\(fromRef.map { "\($0)...\(toRef)" } ?? toRef)`", ""]

    if options.includeRawLog, !commitList.isEmpty {
        output += ["### Commit Log", "```text"]
        output += commitList.map { "\($0.hash) - \($0.subject) (\($0.author), \($0.date))" }
        output += ["```", ""]
    }

    return output.joined(separator: "\n")
}

// MARK: - Main

let options = parseOptions()
let notes = generateNotes(options)

if let outputFile = options.outputFile {
    let url = URL(fileURLWithPath: outputFile)
    do {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (notes + "\n").write(to: url, atomically: true, encoding: .utf8)
    } catch {
        fail("Could not write \(outputFile): \(error.localizedDescription)")
    }
    print("Release notes written to \(outputFile)")
} else {
    print(notes)
}

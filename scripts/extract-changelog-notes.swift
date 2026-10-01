#!/usr/bin/env swift
// Prints the CHANGELOG.md section for a release tag, used as the GitHub Release body.
// Usage: extract-changelog-notes.swift <tag> [changelog-path]

import Foundation

let arguments = CommandLine.arguments.dropFirst()
guard let tag = arguments.first else {
    FileHandle.standardError.write(Data("Usage: extract-changelog-notes.swift <tag> [changelog-path]\n".utf8))
    exit(1)
}

let changelogPath = arguments.dropFirst().first ?? "CHANGELOG.md"
let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
let changelog = (try? String(contentsOfFile: changelogPath, encoding: .utf8)) ?? ""

var section: [Substring] = []
var isInSection = false
for line in changelog.split(separator: "\n", omittingEmptySubsequences: false) {
    if line.hasPrefix("## [") {
        if isInSection { break }
        isInSection = line.hasPrefix("## [\(version)]")
        continue
    }
    if isInSection { section.append(line) }
}

let notes = section.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
print(notes.isEmpty ? "Release \(tag)" : notes)

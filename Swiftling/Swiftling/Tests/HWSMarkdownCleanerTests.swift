//
//  HWSMarkdownCleanerTests.swift
//  Swiftling
//
//  Created by Claude Code on 10.11.25.
//

import XCTest
@testable import Swiftling

/// Tests for HWSMarkdownCleaner using real test data from TestData directory
final class HWSMarkdownCleanerTests: XCTestCase {

    private let cleaner = HWSMarkdownCleaner()

    /// Test that cleaning scraped content matches expected cleaned output
    func testCleaningWithRealData() throws {
        // Get test data directory
        let testDataURL = try getTestDataDirectory()
        let scrapesDir = testDataURL.appendingPathComponent("hackingwithswift/scrapes")
        let cleanedDir = testDataURL.appendingPathComponent("hackingwithswift/cleaned")

        // Get all scraped files
        let scrapedFiles = try FileManager.default.contentsOfDirectory(
            at: scrapesDir,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "md" }

        XCTAssertFalse(scrapedFiles.isEmpty, "No test files found in scrapes directory")

        var successes = 0
        var failures: [(String, String)] = []

        // Test each scraped file
        for scrapedFile in scrapedFiles {
            let filename = scrapedFile.lastPathComponent
            let cleanedFile = cleanedDir.appendingPathComponent(filename)

            // Skip if cleaned version doesn't exist
            guard FileManager.default.fileExists(atPath: cleanedFile.path) else {
                continue
            }

            do {
                // Read scraped content
                let scrapedContent = try String(contentsOf: scrapedFile, encoding: .utf8)

                // Read expected cleaned content
                let expectedCleaned = try String(contentsOf: cleanedFile, encoding: .utf8)

                // Separate frontmatter from body
                let (frontmatter, body) = extractFrontmatter(scrapedContent)

                // Clean the body
                let cleanedBody = cleaner.clean(body)

                // Reassemble with frontmatter
                let actualCleaned = frontmatter + cleanedBody

                // Compare with line-by-line trimming (ignore indentation differences)
                if trimAllLines(actualCleaned) == trimAllLines(expectedCleaned) {
                    successes += 1
                } else {
                    failures.append((filename, "Content mismatch"))

                    // Print diff for first failure
                    if failures.count == 1 {
                        print("\n=== FIRST FAILURE: \(filename) ===")
                        print("Expected length: \(expectedCleaned.count)")
                        print("Actual length: \(actualCleaned.count)")
                        print("\nExpected (first 500 chars):")
                        print(String(expectedCleaned.prefix(500)))
                        print("\nActual (first 500 chars):")
                        print(String(actualCleaned.prefix(500)))
                        print("===\n")
                    }
                }
            } catch {
                failures.append((filename, "Error: \(error.localizedDescription)"))
            }
        }

        // Report results
        let totalTested = successes + failures.count
        let successRate = totalTested > 0 ? (Double(successes) / Double(totalTested)) * 100 : 0

        print("\n=== Test Results ===")
        print("Total files tested: \(totalTested)")
        print("Successes: \(successes)")
        print("Failures: \(failures.count)")
        print("Success rate: \(String(format: "%.1f", successRate))%")

        if !failures.isEmpty {
            print("\nFailed files:")
            for (filename, reason) in failures.prefix(10) {
                print("  - \(filename): \(reason)")
            }
            if failures.count > 10 {
                print("  ... and \(failures.count - 10) more")
            }
        }

        // Assert at least 80% success rate
        XCTAssertGreaterThanOrEqual(
            successRate,
            80.0,
            "Success rate (\(String(format: "%.1f", successRate))%) is below 80%. \(failures.count) files failed."
        )
    }

    /// Test a specific file for debugging
    func testSpecificFile() throws {
        let testDataURL = try getTestDataDirectory()
        let filename = "hackingwithswift.com_swift_5.0_handling-future-enum-cases.md"

        let scrapedFile = testDataURL.appendingPathComponent("hackingwithswift/scrapes/\(filename)")
        let cleanedFile = testDataURL.appendingPathComponent("hackingwithswift/cleaned/\(filename)")

        // Read files
        let scrapedContent = try String(contentsOf: scrapedFile, encoding: .utf8)
        let expectedCleaned = try String(contentsOf: cleanedFile, encoding: .utf8)

        // Separate frontmatter from body
        let (frontmatter, body) = extractFrontmatter(scrapedContent)

        // Clean the body
        let cleanedBody = cleaner.clean(body)

        // Reassemble
        let actualCleaned = frontmatter + cleanedBody

        // Trim and split into lines for comparison
        let actualTrimmed = trimAllLines(actualCleaned)
        let expectedTrimmed = trimAllLines(expectedCleaned)

        let actualLines = actualTrimmed.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        let expectedLines = expectedTrimmed.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }

        // Find first difference
        var firstDiff = -1
        for i in 0..<min(actualLines.count, expectedLines.count) {
            if actualLines[i] != expectedLines[i] {
                firstDiff = i
                break
            }
        }

        // Write debug info to file if they don't match
        if actualTrimmed != expectedTrimmed {
            var debugOutput = """
            ========================================
            TEST FAILURE: \(filename)
            ========================================
            Actual lines: \(actualLines.count)
            Expected lines: \(expectedLines.count)

            """

            if firstDiff >= 0 {
                debugOutput += "\n>>> First difference at line \(firstDiff + 1)\n"
                let start = max(0, firstDiff - 2)
                let end = min(actualLines.count, firstDiff + 3)

                debugOutput += "\nContext (actual):\n"
                for i in start..<end {
                    let marker = i == firstDiff ? ">>> " : "    "
                    debugOutput += "\(marker)\(i + 1): |\(actualLines[i])|\n"
                }

                debugOutput += "\nContext (expected):\n"
                let endExpected = min(expectedLines.count, firstDiff + 3)
                for i in start..<endExpected {
                    let marker = i == firstDiff ? ">>> " : "    "
                    if i < expectedLines.count {
                        debugOutput += "\(marker)\(i + 1): |\(expectedLines[i])|\n"
                    }
                }
            } else {
                debugOutput += "\nAll lines match up to line \(min(actualLines.count, expectedLines.count))\n"
                debugOutput += "Difference is in line count only\n"
            }

            debugOutput += "\n>>> Actual (last 5 lines):\n"
            for (i, line) in actualLines.suffix(5).enumerated() {
                let lineNum = actualLines.count - 5 + i + 1
                debugOutput += "    \(lineNum): |\(line)|\n"
            }

            debugOutput += "\n>>> Expected (last 5 lines):\n"
            for (i, line) in expectedLines.suffix(5).enumerated() {
                let lineNum = expectedLines.count - 5 + i + 1
                debugOutput += "    \(lineNum): |\(line)|\n"
            }
            debugOutput += "========================================\n"

            // Write to /tmp
            try? debugOutput.write(toFile: "/tmp/test_failure.txt", atomically: true, encoding: .utf8)
        }

        // Compare with line-by-line trimming (ignore indentation differences)
        XCTAssertEqual(
            actualTrimmed,
            expectedTrimmed,
            "Cleaned content doesn't match expected output for \(filename)"
        )
    }

    // MARK: - Helper Methods

    /// Trim all leading and trailing whitespace from each line, then join
    /// This allows comparison that ignores indentation differences
    private func trimAllLines(_ content: String) -> String {
        return content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get the TestData directory URL
    private func getTestDataDirectory() throws -> URL {
        // Try to find TestData relative to the source file
        let sourceFile = URL(fileURLWithPath: #file)
        var currentDir = sourceFile.deletingLastPathComponent()

        // Go up directories until we find TestData or reach root
        for _ in 0..<10 {
            let testDataURL = currentDir.appendingPathComponent("TestData")
            if FileManager.default.fileExists(atPath: testDataURL.path) {
                return testDataURL
            }
            currentDir = currentDir.deletingLastPathComponent()
        }

        throw NSError(
            domain: "HWSMarkdownCleanerTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not find TestData directory"]
        )
    }

    /// Extract frontmatter from markdown content
    /// Returns (frontmatter, body) where frontmatter includes the --- delimiters
    private func extractFrontmatter(_ markdown: String) -> (String, String) {
        // Check if starts with ---
        guard markdown.hasPrefix("---\n") else {
            return ("", markdown)
        }

        // Find the closing ---
        let afterFirstDelimiter = markdown.dropFirst(4) // Skip "---\n"
        if let endRange = afterFirstDelimiter.range(of: "\n---\n") {
            let frontmatterEnd = markdown.distance(from: markdown.startIndex, to: endRange.upperBound)
            let frontmatterEndIndex = markdown.index(markdown.startIndex, offsetBy: frontmatterEnd)

            let frontmatter = String(markdown[..<frontmatterEndIndex])
            let body = String(markdown[frontmatterEndIndex...])

            return (frontmatter, body)
        }

        // If no closing ---, treat as no frontmatter
        return ("", markdown)
    }
}

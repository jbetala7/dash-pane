import Foundation
import AppKit

// MARK: - Search Result

struct SearchResult: Identifiable {
    let window: WindowInfo
    let score: Double
    let matchedRanges: [Range<String.Index>]

    var id: CGWindowID { window.id }
}

// MARK: - FuzzySearchEngine

class FuzzySearchEngine {

    // MARK: - Configuration

    var acronymBonus: Double = 2.0
    var consecutiveBonus: Double = 0.5
    var wordBoundaryBonus: Double = 0.75
    var startOfStringBonus: Double = 1.0

    // MARK: - Search

    /// Search windows with fuzzy matching
    func search(query: String, in windows: [WindowInfo]) -> [SearchResult] {
        // Empty query returns all windows
        guard !query.isEmpty else {
            return windows.map { SearchResult(window: $0, score: 1.0, matchedRanges: []) }
        }

        let lowercaseQuery = query.lowercased()

        return windows.compactMap { window -> SearchResult? in
            // Try matching against app name and window title
            let appNameResult = fuzzyMatch(query: lowercaseQuery, in: window.ownerName)
            let titleResult = fuzzyMatch(query: lowercaseQuery, in: window.windowTitle)

            // Also try acronym matching
            let acronymScore = acronymMatch(query: lowercaseQuery, appName: window.ownerName, title: window.windowTitle)

            // Get best score
            let scores: [Double] = [appNameResult?.score ?? 0, titleResult?.score ?? 0, acronymScore]
            let bestScore = scores.max() ?? 0

            guard bestScore > 0 else { return nil }

            // Get matched ranges from best match
            let matchedRanges: [Range<String.Index>]
            if let appResult = appNameResult, appResult.score == bestScore {
                matchedRanges = appResult.ranges
            } else if let titleResult = titleResult, titleResult.score == bestScore {
                matchedRanges = titleResult.ranges
            } else {
                matchedRanges = []
            }

            return SearchResult(
                window: window,
                score: bestScore,
                matchedRanges: matchedRanges
            )
        }
        .sorted { $0.score > $1.score }
    }

    // MARK: - Fuzzy Matching

    /// Core fuzzy matching algorithm with scoring
    private func fuzzyMatch(query: String, in text: String) -> (score: Double, ranges: [Range<String.Index>])? {
        guard !text.isEmpty else { return nil }

        let lowercaseQuery = query.lowercased()
        let lowercaseText = text.lowercased()

        var queryIndex = lowercaseQuery.startIndex
        var textIndex = lowercaseText.startIndex
        var matchedRanges: [Range<String.Index>] = []
        var score: Double = 0
        var lastMatchIndex: String.Index?

        while queryIndex < lowercaseQuery.endIndex && textIndex < lowercaseText.endIndex {
            if lowercaseQuery[queryIndex] == lowercaseText[textIndex] {
                // Match found
                let rangeStart = textIndex
                let rangeEnd = lowercaseText.index(after: textIndex)
                matchedRanges.append(rangeStart..<rangeEnd)

                // Base score for match
                score += 1.0

                // Start of string bonus
                if textIndex == lowercaseText.startIndex {
                    score += startOfStringBonus
                }

                // Consecutive match bonus
                if let last = lastMatchIndex, lowercaseText.index(after: last) == textIndex {
                    score += consecutiveBonus
                }

                // Word boundary bonus (matching start of word)
                if textIndex == lowercaseText.startIndex ||
                   isWordBoundary(lowercaseText[lowercaseText.index(before: textIndex)]) {
                    score += wordBoundaryBonus
                }

                // Case match bonus (original case matches)
                let originalTextIndex = text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: textIndex))
                let originalQueryIndex = query.index(query.startIndex, offsetBy: lowercaseQuery.distance(from: lowercaseQuery.startIndex, to: queryIndex))
                if text[originalTextIndex] == query[originalQueryIndex] {
                    score += 0.1
                }

                lastMatchIndex = textIndex
                queryIndex = lowercaseQuery.index(after: queryIndex)
            }

            textIndex = lowercaseText.index(after: textIndex)
        }

        // Did we match all query characters?
        guard queryIndex == lowercaseQuery.endIndex else { return nil }

        // Normalize score
        let normalizedScore = score / Double(max(text.count, 1))

        return (normalizedScore, matchedRanges)
    }

    /// Acronym matching (e.g., "gc" matches "Google Chrome")
    private func acronymMatch(query: String, appName: String, title: String) -> Double {
        let combined = "\(appName) \(title)"
        let words = combined.split { $0.isWhitespace || $0 == "-" || $0 == "_" }

        // Build acronym from first letters of words
        let acronym = String(words.compactMap { $0.first }).lowercased()
        let lowercaseQuery = query.lowercased()

        // Exact acronym match
        if acronym == lowercaseQuery {
            return acronymBonus * 1.5
        }

        // Acronym starts with query
        if acronym.hasPrefix(lowercaseQuery) {
            return acronymBonus
        }

        // Query is contained in acronym
        if acronym.contains(lowercaseQuery) {
            return acronymBonus * 0.75
        }

        return 0
    }

    // MARK: - Helpers

    private func isWordBoundary(_ char: Character) -> Bool {
        return char.isWhitespace || char.isPunctuation || char == "-" || char == "_"
    }

    /// Check if query is a potential acronym (all lowercase, short)
    func isPotentialAcronym(_ query: String) -> Bool {
        return query.count <= 5 && query == query.lowercased() && !query.contains(" ")
    }
}

// MARK: - String Extension for Highlighting

extension String {
    /// Create attributed string with highlighted ranges
    func attributedString(highlighting ranges: [Range<String.Index>], highlightColor: NSColor = .systemYellow) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: self)

        for range in ranges {
            let nsRange = NSRange(range, in: self)
            attributedString.addAttribute(.backgroundColor, value: highlightColor.withAlphaComponent(0.3), range: nsRange)
            attributedString.addAttribute(.foregroundColor, value: highlightColor, range: nsRange)
        }

        return attributedString
    }
}

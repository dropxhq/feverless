import Foundation

// MARK: - MedicationKeywordMatcher

struct MedicationKeywordMatcher {

    // MARK: - 3.1 Built-in keyword dictionary (sorted by keyword length descending)

    private let builtinKeywords: [(keyword: String, type: MedicationType)] = {
        let pairs: [(String, MedicationType)] = [
            // Longer keywords first to prevent partial matches
            ("对乙酰氨基酚", .acetaminophen),
            ("对乙", .acetaminophen),
            ("acetaminophen", .acetaminophen),
            ("ibuprofen", .ibuprofen),
            ("扑热息痛", .acetaminophen),
            ("退热净", .acetaminophen),
            ("芬必得", .ibuprofen),
            ("布洛芬", .ibuprofen),
            ("Advil", .ibuprofen),
            ("泰诺", .acetaminophen),
            ("美林", .ibuprofen),
        ]
        return pairs.sorted { $0.0.count > $1.0.count }
    }()

    // MARK: - 3.2 Extract medication types from text (multi-hit, de-duplicated by type)

    /// Extracts medication types from free text using keyword matching.
    /// Built-in dictionary + user extensions are sorted by keyword length (descending) to
    /// prefer longer matches. Multiple medication types may be returned for a single text.
    func extract(from text: String, userExtensions: [String: String]) -> [MedicationType] {
        guard !text.isEmpty else { return [] }

        // 3.3 Merge built-in keywords with user extensions, sorted by length descending
        let userPairs: [(keyword: String, type: MedicationType)] = userExtensions
            .compactMap { keyword, rawValue -> (String, MedicationType)? in
                guard let type = MedicationType(rawValue: rawValue) else { return nil }
                return (keyword, type)
            }
            .sorted { $0.0.count > $1.0.count }

        var allKeywords = builtinKeywords
        allKeywords.append(contentsOf: userPairs)

        var found: [MedicationType] = []
        var seenTypes = Set<String>()

        for (keyword, type) in allKeywords {
            guard text.localizedCaseInsensitiveContains(keyword) else { continue }
            guard !seenTypes.contains(type.rawValue) else { continue }
            found.append(type)
            seenTypes.insert(type.rawValue)
        }

        return found
    }
}

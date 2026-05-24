import Foundation

// MARK: - MedicationKeywordMatcher

struct MedicationKeywordMatcher {

    // MARK: - Extract canonical medication names from text

    /// Extracts canonical medication names from free text using keyword matching.
    /// Keywords are sourced from MedicationCatalog (built-in + user-defined).
    /// Sorted by keyword length descending to prefer longer matches.
    /// Multiple medication names may be returned for a single text.
    func extract(from text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        // Build (keyword, canonicalName) pairs from catalog, sorted by length descending
        let allPairs: [(keyword: String, canonicalName: String)] = MedicationCatalog.shared.all
            .flatMap { def -> [(String, String)] in
                let allTerms = def.keywords + [def.canonicalName]
                return allTerms.map { ($0, def.canonicalName) }
            }
            .sorted { $0.0.count > $1.0.count }

        var found: [String] = []
        var seenNames = Set<String>()

        for (keyword, canonicalName) in allPairs {
            guard !keyword.isEmpty else { continue }
            guard text.localizedCaseInsensitiveContains(keyword) else { continue }
            guard !seenNames.contains(canonicalName) else { continue }
            found.append(canonicalName)
            seenNames.insert(canonicalName)
        }

        return found
    }
}

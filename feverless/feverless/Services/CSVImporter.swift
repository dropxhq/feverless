import Foundation

// MARK: - Import errors

enum CSVImportError: LocalizedError {
    case missingColumn(String)
    case invalidTimestamp(line: Int, value: String)
    case invalidValue(line: Int, value: String)

    var errorDescription: String? {
        switch self {
        case .missingColumn(let col):
            return "格式有误：缺少必需列「\(col)」。请在列名映射中完成配置。"
        case .invalidTimestamp(let line, let value):
            return "格式有误：第 \(line) 行时间无法解析（\"\(value)\"）。"
        case .invalidValue(let line, let value):
            return "格式有误：第 \(line) 行数值不是有效数字（\"\(value)\"）。"
        }
    }
}

// MARK: - 1.5 Parse result (extended with mappingReport)

struct CSVParseResult {
    let records: [DataRecord]
    let skippedCount: Int
    var mappingReport: ImportMappingReport

    init(
        records: [DataRecord],
        skippedCount: Int,
        mappingReport: ImportMappingReport = ImportMappingReport()
    ) {
        self.records = records
        self.skippedCount = skippedCount
        self.mappingReport = mappingReport
    }
}

// MARK: - Date format detector

struct DateFormatDetector {

    private let formatters: [DateFormatter] = {
        func make(_ format: String, tz: TimeZone? = nil) -> DateFormatter {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = format
            if let tz { f.timeZone = tz }
            return f
        }
        return [
            make("yyyy-MM-dd'T'HH:mm:ssXXXXX"),
            make("yyyy-MM-dd'T'HH:mm:ss'Z'", tz: TimeZone(identifier: "UTC")),
            make("yyyy-MM-dd'T'HH:mm:ss",    tz: .current),
            make("yyyy/MM/dd HH:mm:ss",        tz: .current),
            make("yyyy/MM/dd HH:mm",          tz: .current),
            make("yyyy-MM-dd",                tz: .current),
        ]
    }()

    func parse(_ string: String) -> Date? {
        formatters.lazy.compactMap { $0.date(from: string) }.first
    }
}

// MARK: - CSVImporter

struct CSVImporter {

    private let dateDetector = DateFormatDetector()
    private let aliasTable = ImportAliasTable()
    private let keywordMatcher = MedicationKeywordMatcher()

    // MARK: - Read raw CSV rows (header + data rows)

    func readRawRows(url: URL) throws -> [[String]] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseRFC4180(content)
    }

    // MARK: - 4.1 Detect unresolved column headers

    func detectUnresolvedColumns(headers: [String], config: ImportMappingConfig) -> [String] {
        headers.filter { header in
            // Already has a rule in config → resolved
            if config.columnMappings[header] != nil { return false }
            // Auto-resolvable → resolved
            return aliasTable.resolveColumnName(header, config: config) == nil
        }
    }

    // MARK: - 4.2 Detect unresolved values for a specific enum column

    func detectUnresolvedValues(
        rows: [[String]],
        columnIndex: Int,
        field: String,
        config: ImportMappingConfig
    ) -> [(value: String, count: Int)] {
        var counts: [String: Int] = [:]
        for row in rows {
            guard columnIndex < row.count else { continue }
            let rawVal = row[columnIndex].trimmingCharacters(in: .whitespaces)
            guard !rawVal.isEmpty else { continue }
            if aliasTable.resolveValue(rawVal, forField: field, config: config) == nil {
                counts[rawVal, default: 0] += 1
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }

    // MARK: - 4.3 Parse with mapping config

    func parse(url: URL, childId: UUID, config: ImportMappingConfig = ImportMappingConfig()) throws -> CSVParseResult {
        let rows = try readRawRows(url: url)
        return try parseRows(rows, childId: childId, config: config)
    }

    // MARK: - Internal: parse from pre-loaded rows

    func parseRows(_ rows: [[String]], childId: UUID, config: ImportMappingConfig) throws -> CSVParseResult {
        guard let headerRow = rows.first else {
            return CSVParseResult(records: [], skippedCount: 0)
        }

        let headers = headerRow.map { $0.trimmingCharacters(in: .whitespaces) }
        var report = ImportMappingReport()

        // Build resolved column list
        struct ColumnInfo {
            let index: Int
            let header: String
            let rule: ColumnMappingRule
        }

        var columnInfos: [ColumnInfo] = []
        for (i, header) in headers.enumerated() {
            // User config takes priority (any rule type)
            if let userRule = config.columnMappings[header] {
                switch userRule {
                case .simple(let f):   report.appliedColumnMappings[header] = f
                case .compound(let f, _): report.appliedColumnMappings[header] = f
                default: break
                }
                columnInfos.append(ColumnInfo(index: i, header: header, rule: userRule))
                continue
            }
            // Auto-resolve via alias table
            if let resolved = aliasTable.resolveColumnName(header, config: config) {
                if resolved != header { report.appliedColumnMappings[header] = resolved }
                columnInfos.append(ColumnInfo(index: i, header: header, rule: .simple(field: resolved)))
                continue
            }
            // Unresolved → ignore
            columnInfos.append(ColumnInfo(index: i, header: header, rule: .ignore))
        }

        // Validate required field: timestamp
        let hasTimestamp = columnInfos.contains { info in
            if case .simple(let f) = info.rule { return f == "timestamp" }
            return false
        }
        guard hasTimestamp else { throw CSVImportError.missingColumn("时间") }

        var outputRecords: [DataRecord] = []

        for (offset, fields) in rows.dropFirst().enumerated() {
            let lineNum = offset + 2
            guard !fields.isEmpty, !(fields.count == 1 && fields[0].isEmpty) else { continue }

            var tsString = ""
            var notesValue = ""
            var simpleRecordType = ""
            var simpleValue = ""
            var simpleMethod = ""
            var simpleMedType = ""

            // Compound temperature columns: (value, positionCanonicalName)
            var compoundTemps: [(value: Double, positionName: String)] = []
            // Compound medication columns: canonical name
            var compoundMeds: [String] = []
            // Keyword-extracted canonical medication names
            var keywordMedNames: [String] = []

            for colInfo in columnInfos {
                let rawVal = colInfo.index < fields.count
                    ? fields[colInfo.index].trimmingCharacters(in: .whitespaces)
                    : ""

                switch colInfo.rule {
                case .ignore:
                    break

                case .simple(let field):
                    switch field {
                    case "timestamp":   tsString = rawVal
                    case "notes":       notesValue = rawVal
                    case "record_type":
                        let resolved = aliasTable.resolveValue(rawVal, forField: "record_type", config: config) ?? rawVal
                        if resolved != rawVal && !rawVal.isEmpty {
                            report.recordValueMapping(field: "record_type", originalValue: rawVal)
                        }
                        simpleRecordType = resolved
                    case "value":       simpleValue = rawVal
                    case "method":      simpleMethod = rawVal
                    case "medication_type": simpleMedType = rawVal
                    default: break
                    }

                // Compound: column value is a temperature measurement; implied values set position
                case .compound(_, let impliedValues):
                    guard !rawVal.isEmpty else { continue }
                    let rt = impliedValues["record_type"] ?? "temperature"
                    if rt == "temperature" {
                        guard let dbl = Double(rawVal) else { continue }
                        // Resolve the implied method to a position canonical name
                        let methodRaw = impliedValues["method"] ?? "腋下"
                        let positionName = aliasTable.resolveValue(methodRaw, forField: "method", config: config)
                            ?? TemperaturePositionCatalog.shared.all.first?.canonicalName
                            ?? "腋下"
                        compoundTemps.append((value: dbl, positionName: positionName))
                    } else if rt == "medication" {
                        let medRaw = impliedValues["medication_type"] ?? "其他"
                        let canonicalName = aliasTable.resolveValue(medRaw, forField: "medication_type", config: config) ?? medRaw
                        compoundMeds.append(canonicalName)
                    }

                case .keywordExtract(let field, let extractsMedications):
                    if let f = field {
                        if f == "notes" { notesValue = rawVal }
                        else if f == "timestamp" { tsString = rawVal }
                    }
                    if extractsMedications && !rawVal.isEmpty {
                        let matched = keywordMatcher.extract(from: rawVal)
                        keywordMedNames.append(contentsOf: matched)
                        report.keywordExtractionCount += matched.count
                    }
                }
            }

            guard !tsString.isEmpty else { continue }
            guard let date = dateDetector.parse(tsString) else {
                throw CSVImportError.invalidTimestamp(line: lineNum, value: tsString)
            }

            var temperatures: [TemperatureReading] = []
            var medications: [MedicationUsage] = []

            // Process compound temperature columns (multi-position per row)
            for entry in compoundTemps {
                temperatures.append(TemperatureReading(positionRaw: entry.positionName, value: entry.value))
            }

            // Process compound medication columns
            for name in compoundMeds {
                medications.append(MedicationUsage(medicationNameRaw: name))
            }

            // Process simple columns when no compound columns present
            if compoundTemps.isEmpty && compoundMeds.isEmpty {
                let effectiveRT: String
                if !simpleRecordType.isEmpty {
                    effectiveRT = simpleRecordType
                } else if !simpleValue.isEmpty {
                    effectiveRT = "temperature"
                } else if !simpleMedType.isEmpty {
                    effectiveRT = "medication"
                } else {
                    effectiveRT = ""
                }

                switch effectiveRT {
                case "temperature":
                    guard !simpleValue.isEmpty, let dbl = Double(simpleValue) else {
                        if !simpleValue.isEmpty {
                            throw CSVImportError.invalidValue(line: lineNum, value: simpleValue)
                        }
                        break
                    }
                    let resolvedPosition = aliasTable.resolveValue(simpleMethod, forField: "method", config: config)
                        ?? TemperaturePositionCatalog.shared.all.first?.canonicalName
                        ?? "腋下"
                    if resolvedPosition != simpleMethod && !simpleMethod.isEmpty {
                        report.recordValueMapping(field: "method", originalValue: simpleMethod)
                    }
                    temperatures.append(TemperatureReading(positionRaw: resolvedPosition, value: dbl))

                case "medication":
                    let resolvedMed = aliasTable.resolveValue(simpleMedType, forField: "medication_type", config: config) ?? "其他"
                    if resolvedMed != simpleMedType && !simpleMedType.isEmpty {
                        report.recordValueMapping(field: "medication_type", originalValue: simpleMedType)
                    }
                    medications.append(MedicationUsage(medicationNameRaw: resolvedMed))

                default:
                    break
                }
            }

            // Add keyword-extracted medication records
            for canonicalName in keywordMedNames {
                medications.append(MedicationUsage(medicationNameRaw: canonicalName))
            }

            // Task 7.4: Discard empty records
            guard !temperatures.isEmpty || !medications.isEmpty || !notesValue.isEmpty else { continue }

            outputRecords.append(DataRecord(
                childId: childId,
                timestamp: date,
                notes: notesValue,
                temperatures: temperatures,
                medications: medications
            ))
        }

        return CSVParseResult(
            records: outputRecords,
            skippedCount: 0,
            mappingReport: report
        )
    }

    // MARK: - Deduplication

    func deduplicated(
        parseResult: CSVParseResult,
        existingRecords: [DataRecord]
    ) -> CSVParseResult {
        let existingKeys = Set(existingRecords.map { Int($0.timestamp.timeIntervalSince1970) })
        let newRecords = parseResult.records.filter { !existingKeys.contains(Int($0.timestamp.timeIntervalSince1970)) }
        let skipped = parseResult.records.count - newRecords.count

        return CSVParseResult(
            records: newRecords,
            skippedCount: skipped,
            mappingReport: parseResult.mappingReport
        )
    }

    // MARK: - RFC 4180 parser

    private func field(_ fields: [String], at index: Int) -> String {
        index < fields.count ? fields[index] : ""
    }

    private func parseRFC4180(_ content: String) -> [[String]] {
        // Normalize all line endings to \n before parsing.
        // Swift's Character type treats \r\n as a single extended grapheme cluster,
        // so it would never match "\r" or "\n" individually, causing the entire
        // file to be parsed as one row when CRLF line endings are present.
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = normalized.startIndex

        while i < normalized.endIndex {
            let c = normalized[i]
            if inQuotes {
                if c == "\"" {
                    let next = normalized.index(after: i)
                    if next < normalized.endIndex && normalized[next] == "\"" {
                        currentField.append("\"")
                        i = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(c)
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                case "\n":
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                default:
                    currentField.append(c)
                }
            }
            i = normalized.index(after: i)
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }
}

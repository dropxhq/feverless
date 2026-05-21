import Foundation

// MARK: - 2.4 Import errors

enum CSVImportError: LocalizedError {
    case missingColumn(String)
    case invalidRecordType(line: Int, value: String)
    case invalidTimestamp(line: Int, value: String)
    case invalidValue(line: Int, value: String)

    var errorDescription: String? {
        switch self {
        case .missingColumn(let col):
            return "格式有误：缺少必需列 \(col)。请参考导出文件的格式。"
        case .invalidRecordType(let line, let value):
            return "格式有误：第 \(line) 行 record_type 值不合法（\"\(value)\"）。请参考导出文件的格式。"
        case .invalidTimestamp(let line, let value):
            return "格式有误：第 \(line) 行 timestamp 无法解析（\"\(value)\"）。请参考导出文件的格式。"
        case .invalidValue(let line, let value):
            return "格式有误：第 \(line) 行 value 不是有效数字（\"\(value)\"）。请参考导出文件的格式。"
        }
    }
}

// MARK: - 2.5 Parse result

struct CSVParseResult {
    let temperatureRows: [TemperatureRecord]
    let medicationRows: [MedicationRecord]
    let skippedCount: Int
}

// MARK: - 2.2 Date format detector

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
            make("yyyy-MM-dd'T'HH:mm:ssXXXXX"),                              // 1. ISO 8601 with tz
            make("yyyy-MM-dd'T'HH:mm:ss'Z'", tz: TimeZone(identifier: "UTC")), // 2. ISO 8601 UTC
            make("yyyy-MM-dd'T'HH:mm:ss",    tz: .current),                   // 3. ISO 8601 no tz
            make("yyyy/MM/dd HH:mm",          tz: .current),                   // 4. Chinese common
            make("yyyy-MM-dd",                tz: .current),                   // 5. Date only
        ]
    }()

    func parse(_ string: String) -> Date? {
        formatters.lazy.compactMap { $0.date(from: string) }.first
    }
}

// MARK: - 2.1 / 2.3 Importer

struct CSVImporter {

    private let dateDetector = DateFormatDetector()

    // MARK: - 2.3 Parse

    func parse(url: URL, childId: UUID) throws -> CSVParseResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = parseRFC4180(content)

        guard let headerRow = rows.first else {
            return CSVParseResult(temperatureRows: [], medicationRows: [], skippedCount: 0)
        }

        let col = Dictionary(
            uniqueKeysWithValues: headerRow.enumerated().map { ($1.trimmingCharacters(in: .whitespaces), $0) }
        )

        guard col["record_type"] != nil else { throw CSVImportError.missingColumn("record_type") }
        guard col["timestamp"]   != nil else { throw CSVImportError.missingColumn("timestamp") }

        let rtIdx    = col["record_type"]!
        let tsIdx    = col["timestamp"]!
        let valIdx   = col["value"]
        let methIdx  = col["method"]
        let medIdx   = col["medication_type"]
        let ctIdx    = col["concurrent_temperature"]
        let notesIdx = col["notes"]

        var temps: [TemperatureRecord] = []
        var meds:  [MedicationRecord]  = []

        for (offset, fields) in rows.dropFirst().enumerated() {
            let lineNum = offset + 2
            guard !fields.isEmpty, !(fields.count == 1 && fields[0].isEmpty) else { continue }

            let recordType = field(fields, at: rtIdx)
            let tsString   = field(fields, at: tsIdx)
            guard let date = dateDetector.parse(tsString) else {
                throw CSVImportError.invalidTimestamp(line: lineNum, value: tsString)
            }

            let notes = notesIdx.map { field(fields, at: $0) } ?? ""

            switch recordType {
            case "temperature":
                let rawVal = valIdx.map { field(fields, at: $0) } ?? ""
                guard !rawVal.isEmpty, let dbl = Double(rawVal) else {
                    throw CSVImportError.invalidValue(line: lineNum, value: rawVal)
                }
                let method = methIdx.flatMap { MeasurementMethod(rawValue: field(fields, at: $0)) } ?? .axillary
                temps.append(TemperatureRecord(childId: childId, value: dbl, method: method, timestamp: date, notes: notes))

            case "medication":
                let rawMed  = medIdx.map  { field(fields, at: $0) } ?? ""
                let medType = MedicationType(rawValue: rawMed) ?? .other
                let ctStr   = ctIdx.map   { field(fields, at: $0) } ?? ""
                let ct      = ctStr.isEmpty ? nil : Double(ctStr)
                meds.append(MedicationRecord(childId: childId, type: medType, timestamp: date, concurrentTemperature: ct, notes: notes))

            default:
                throw CSVImportError.invalidRecordType(line: lineNum, value: recordType)
            }
        }

        return CSVParseResult(temperatureRows: temps, medicationRows: meds, skippedCount: 0)
    }

    // MARK: - 2.6 Deduplication

    func deduplicated(
        parseResult: CSVParseResult,
        existingTemperatureRecords: [TemperatureRecord],
        existingMedicationRecords: [MedicationRecord]
    ) -> CSVParseResult {
        let existingTempKeys = Set(existingTemperatureRecords.map { Int($0.timestamp.timeIntervalSince1970) })
        let existingMedKeys  = Set(existingMedicationRecords.map  { Int($0.timestamp.timeIntervalSince1970) })

        let newTemps = parseResult.temperatureRows.filter { !existingTempKeys.contains(Int($0.timestamp.timeIntervalSince1970)) }
        let newMeds  = parseResult.medicationRows.filter  { !existingMedKeys.contains(Int($0.timestamp.timeIntervalSince1970))  }

        let skipped = (parseResult.temperatureRows.count - newTemps.count)
                    + (parseResult.medicationRows.count  - newMeds.count)

        return CSVParseResult(temperatureRows: newTemps, medicationRows: newMeds, skippedCount: skipped)
    }

    // MARK: - RFC 4180 parser

    private func field(_ fields: [String], at index: Int) -> String {
        index < fields.count ? fields[index] : ""
    }

    private func parseRFC4180(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = content.startIndex

        while i < content.endIndex {
            let c = content[i]
            if inQuotes {
                if c == "\"" {
                    let next = content.index(after: i)
                    if next < content.endIndex && content[next] == "\"" {
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
                case "\r":
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                    let next = content.index(after: i)
                    if next < content.endIndex && content[next] == "\n" {
                        i = next
                    }
                case "\n":
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                default:
                    currentField.append(c)
                }
            }
            i = content.index(after: i)
        }

        currentRow.append(currentField)
        if !(currentRow.count == 1 && currentRow[0].isEmpty) {
            rows.append(currentRow)
        }
        return rows
    }
}

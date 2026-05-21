import Foundation

struct CSVExporter {

    private static let header = "record_type,timestamp,value,method,medication_type,concurrent_temperature,notes"

    // MARK: - 1.2 Export

    func export(temperatureRecords: [TemperatureRecord], medicationRecords: [MedicationRecord]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withTimeZone]

        var lines = [Self.header]

        let tempRows = temperatureRecords.sorted { $0.timestamp < $1.timestamp }.map { r in
            csvRow("temperature",
                   formatter.string(from: r.timestamp),
                   String(r.value),
                   r.methodRaw,
                   "",
                   "",
                   r.notes)
        }

        let medRows = medicationRecords.sorted { $0.timestamp < $1.timestamp }.map { r in
            csvRow("medication",
                   formatter.string(from: r.timestamp),
                   "",
                   "",
                   r.typeRaw,
                   r.concurrentTemperature.map { String($0) } ?? "",
                   r.notes)
        }

        lines.append(contentsOf: tempRows)
        lines.append(contentsOf: medRows)
        return lines.joined(separator: "\r\n")
    }

    // MARK: - 1.3 Write to temporary file

    func writeToTemporaryFile(csvString: String, fileName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try csvString.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - 1.4 File name generation

    func generateFileName(childName: String, startDate: Date, endDate: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let safeName = childName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return "feverless_\(safeName)_\(fmt.string(from: startDate))_\(fmt.string(from: endDate)).csv"
    }

    // MARK: - RFC 4180 helpers

    private func quoteField(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func csvRow(_ fields: String...) -> String {
        fields.map { quoteField($0) }.joined(separator: ",")
    }
}

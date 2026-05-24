import Foundation

struct CSVExporter {

    // Updated header for DataRecord model
    private static let header = "时间,记录类型,数值,测量方式,药物类型,备注"

    // MARK: - Export from DataRecords

    func export(records: [DataRecord]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withTimeZone]

        var lines = [Self.header]

        for record in records.sorted(by: { $0.timestamp < $1.timestamp }) {
            let ts = formatter.string(from: record.timestamp)

            for reading in record.temperatures {
                lines.append(csvRow(
                    ts,
                    "体温",
                    String(reading.value),
                    reading.positionRaw,
                    "",
                    record.notes
                ))
            }

            for usage in record.medications {
                lines.append(csvRow(
                    ts,
                    "用药",
                    "",
                    "",
                    usage.medicationNameRaw,
                    record.notes
                ))
            }
        }

        return lines.joined(separator: "\r\n")
    }

    // MARK: - Write to temporary file

    func writeToTemporaryFile(csvString: String, fileName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try csvString.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - File name generation

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

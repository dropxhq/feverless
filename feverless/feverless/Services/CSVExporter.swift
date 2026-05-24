import Foundation

struct CSVExporter {

    // 5.1 New Chinese header; 5.2 time column first
    private static let header = "时间,记录类型,数值,测量方式,药物类型,同步体温,备注"

    // MARK: - Export

    func export(temperatureRecords: [TemperatureRecord], medicationRecords: [MedicationRecord]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withTimeZone]

        var lines = [Self.header]

        // 5.2 Sort by timestamp ascending; time column first
        let tempRows = temperatureRecords.sorted { $0.timestamp < $1.timestamp }.map { r in
            csvRow(
                formatter.string(from: r.timestamp),  // 时间
                "体温",                                 // 5.3 record_type → displayName
                String(r.value),                       // 数值
                r.method.displayName,                  // 5.4 method → displayName
                "",                                    // 药物类型
                "",                                    // 同步体温
                r.notes                                // 备注
            )
        }

        let medRows = medicationRecords.sorted { $0.timestamp < $1.timestamp }.map { r in
            csvRow(
                formatter.string(from: r.timestamp),                     // 时间
                "用药",                                                    // 5.3 record_type → displayName
                "",                                                       // 数值
                "",                                                       // 测量方式
                r.type.displayName,                                       // 5.5 medication_type → displayName
                r.concurrentTemperature.map { String($0) } ?? "",         // 同步体温
                r.notes                                                   // 备注
            )
        }

        lines.append(contentsOf: tempRows)
        lines.append(contentsOf: medRows)
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

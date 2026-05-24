import Foundation

struct CSVExporter {

    // MARK: - Export from DataRecords

    /// 宽表格式：每条 DataRecord 一行
    /// 列：时间 | [各测量位置体温列] | 药品 | 备注
    func export(records: [DataRecord]) -> String {
        let sorted = records.sorted { $0.timestamp < $1.timestamp }

        // 按首次出现顺序收集所有测量位置
        var positionOrder: [String] = []
        var seenPositions = Set<String>()
        for record in sorted {
            for reading in record.temperatures {
                if seenPositions.insert(reading.positionRaw).inserted {
                    positionOrder.append(reading.positionRaw)
                }
            }
        }

        // 表头
        let header = (["时间"] + positionOrder + ["药品", "备注"])
            .map { quoteField($0) }.joined(separator: ",")

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var lines = [header]

        for record in sorted {
            var row: [String] = [fmt.string(from: record.timestamp)]

            // 每个位置列
            for posRaw in positionOrder {
                let temps = record.temperatures.filter { $0.positionRaw == posRaw }
                row.append(temps.isEmpty
                    ? ""
                    : temps.map { String(format: "%.1f", $0.value) }.joined(separator: "/"))
            }

            // 药品（多个用 / 分隔）
            let medString = record.medications.map { $0.medicationNameRaw }.joined(separator: "/")
            row.append(medString)

            // 备注：若与药品列完全相同（导入时 keywordExtract 产生的冗余），则不重复输出
            row.append(record.notes == medString ? "" : record.notes)

            lines.append(row.map { quoteField($0) }.joined(separator: ","))
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

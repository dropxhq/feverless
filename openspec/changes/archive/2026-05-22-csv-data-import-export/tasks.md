## 1. CSVExporter 服务层

- [x] 1.1 新建 `feverless/Services/CSVExporter.swift`，定义 `CSVExporter` struct
- [x] 1.2 实现 `export(temperatureRecords:medicationRecords:) -> String` 方法，按 RFC 4180 生成 CSV 字符串（表头 + 数据行，特殊字符加引号）
- [x] 1.3 实现 `writeToTemporaryFile(csvString:fileName:) -> URL` 方法，将 CSV 写入临时目录并返回文件 URL
- [x] 1.4 实现文件名生成逻辑：`feverless_<孩子名>_<开始日期>_<结束日期>.csv`

## 2. CSVImporter 服务层

- [x] 2.1 新建 `feverless/Services/CSVImporter.swift`，定义 `CSVImporter` struct
- [x] 2.2 实现 `DateFormatDetector`，按优先级依次尝试 5 种日期格式，返回解析后的 `Date` 或 `nil`
- [x] 2.3 实现 CSV 解析方法 `parse(url:) throws -> CSVParseResult`，返回体温记录列表、用药记录列表
- [x] 2.4 实现格式验证：检测必需列缺失、`record_type` 非法值、timestamp 无法解析、value 非数字，抛出带行号的 `CSVImportError`
- [x] 2.5 定义 `CSVParseResult` struct（包含 `temperatureRows`、`medicationRows`、`skippedCount`）
- [x] 2.6 实现重复检测方法：接受已有记录集合，返回去重后的可导入记录列表和跳过数量

## 3. 导出 UI

- [x] 3.1 新建 `feverless/Views/Profile/ExportSheet.swift`，实现导出配置 Sheet
- [x] 3.2 实现时间范围选择器（最近 7 天 / 30 天 / 3 个月 / 全部数据 / 自定义）
- [x] 3.3 实现自定义日期范围选择器（DatePicker 起止日期）
- [x] 3.4 实现实时预览：根据所选范围计算并显示将导出的体温记录数和用药记录数
- [x] 3.5 实现"无记录时禁用导出按钮"逻辑
- [x] 3.6 点击"导出 CSV"时调用 `CSVExporter` 生成文件并通过 `UIActivityViewController` 呈现 ShareSheet

## 4. 导入 UI

- [x] 4.1 新建 `feverless/Views/Profile/ImportPreviewSheet.swift`，实现导入预览 Sheet
- [x] 4.2 在 ProfileView 中接入系统文件选择器（`.fileImporter` modifier，限制 `.commaSeparatedText` 类型）
- [x] 4.3 文件选择后调用 `CSVImporter.parse(url:)`，捕获 `CSVImportError` 并弹出格式错误 Alert（包含行号和原始值）
- [x] 4.4 解析成功后呈现 `ImportPreviewSheet`，显示体温记录数、用药记录数、跳过数量
- [x] 4.5 实现"全部重复时禁用确认按钮"逻辑
- [x] 4.6 用户确认后调用 `CSVImporter` 将记录写入 SwiftData，关联当前选中孩子 ID
- [x] 4.7 导入完成后显示成功 Toast/Banner："已成功导入 N 条记录"

## 5. ProfileView 重构

- [x] 5.1 将孩子行改为卡片样式，副标题展示最近体温值和时间（"最近体温: 38.5°C · 昨天 10:30"，无记录则显示"暂无体温记录"）
- [x] 5.2 当前选中孩子行增加视觉高亮（`checkmark.circle.fill` 蓝色图标）
- [x] 5.3 在 List 底部新增 `Section` "数据管理"，标题动态显示 `"<孩子名> 的数据"`
- [x] 5.4 数据管理 Section 添加"导出数据..."行（触发 ExportSheet）
- [x] 5.5 数据管理 Section 添加"导入数据..."行（触发文件选择器）
- [x] 5.6 无选中孩子时隐藏数据管理 Section

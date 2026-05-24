## 1. 清理旧模型与枚举

- [x] 1.1 删除 `Models/TemperatureRecord.swift`
- [x] 1.2 删除 `Models/MedicationRecord.swift`
- [x] 1.3 从 `Models/Enums.swift` 中移除 `MeasurementMethod` 枚举（保留 `MedicationType` 直到确认所有引用已迁移）
- [x] 1.4 在 `feverlessApp.swift` 中更新 `ModelContainer` 的 Schema，移除旧模型引用

## 2. 新数据模型

- [x] 2.1 创建 `Models/TemperatureReading.swift`：`@Model final class TemperatureReading { positionRaw: String; value: Double }`，添加 `isFever` 计算属性（查询 `TemperaturePositionCatalog.shared`）
- [x] 2.2 创建 `Models/MedicationUsage.swift`：`@Model final class MedicationUsage { medicationNameRaw: String }`
- [x] 2.3 创建 `Models/DataRecord.swift`：`@Model final class DataRecord { id, childId, timestamp, notes, @Relationship(cascade) temperatures: [TemperatureReading], @Relationship(cascade) medications: [MedicationUsage] }`
- [x] 2.4 更新 `feverlessApp.swift` Schema 包含 `[Child.self, DataRecord.self, TemperatureReading.self, MedicationUsage.self]`

## 3. TemperaturePositionCatalog

- [x] 3.1 创建 `Models/TemperaturePositionDefinition.swift`（Codable struct：id, canonicalName, keywords, feverThreshold, isBuiltIn）
- [x] 3.2 创建 `Services/TemperaturePositionCatalog.swift`（仿 `MedicationCatalog`：`ObservableObject` 单例，内置五种位置，UserDefaults 持久化 key `"temperature_position_catalog_v1"`）
- [x] 3.3 实现 `find(_ canonicalName:)`、`findByKeyword(_:)`、`add`、`update`、`remove`、`addKeyword`、`removeKeyword`、`save`、`load` 方法
- [x] 3.4 在 App 启动时调用 `TemperaturePositionCatalog.shared.load()`（与 `MedicationCatalog` 一致）

## 4. TemperaturePositionCatalogView

- [x] 4.1 创建 `Views/Profile/TemperaturePositionCatalogView.swift`，Left-Right 布局：左侧位置列表，右侧关键词列表 + 发烧阈值编辑
- [x] 4.2 支持新增自建位置（输入 canonicalName + feverThreshold）；内置位置不可删除但可编辑 keywords
- [x] 4.3 关键词添加后立即刷新列表（修复与 MedicationCatalogView 相同的渲染 bug 模式）
- [x] 4.4 支持双模式呈现：`isSheet: Bool` 参数控制 toolbar 按钮（"完成" vs 系统返回）
- [x] 4.5 视图 `onDisappear` 时调用 `TemperaturePositionCatalog.shared.save()`

## 5. MedicationCatalogView 双模式改造

- [x] 5.1 为 `MedicationCatalogView` 添加 `isSheet: Bool` 参数（默认 `false`）
- [x] 5.2 当 `isSheet=true` 时 toolbar 显示"完成"按钮（`@Environment(\.dismiss)`）
- [x] 5.3 验证 NavigationLink 模式（ProfileView 入口）功能不变

## 6. ProfileView 更新

- [x] 6.1 在 ProfileView 药品管理入口下方添加"体温位置管理" `NavigationLink`，目标为 `TemperaturePositionCatalogView(isSheet: false)`

## 7. 更新 ImportAliasTable 和 CSVImporter

- [x] 7.1 更新 `ImportAliasTable`：`method` 字段的值解析改为查询 `TemperaturePositionCatalog.shared`（`findByKeyword`），移除硬编码的 `MeasurementMethod` 别名表
- [x] 7.2 更新 `CSVParseResult`：将 `temperatureRows: [TemperatureRecord]` 和 `medicationRows: [MedicationRecord]` 替换为 `records: [DataRecord]`
- [x] 7.3 重写 `CSVImporter.parseRows`：一行产生一个 `DataRecord`，多个体温列各产生一个 `TemperatureReading` 加入 `temperatures`，关键词提取各产生一个 `MedicationUsage` 加入 `medications`
- [x] 7.4 实现空行忽略逻辑：`temperatures.isEmpty && medications.isEmpty && notes.isEmpty` 则丢弃

## 8. 更新 ColumnMappingSheet

- [x] 8.1 更新体温列映射 UI：映射类型改为"体温列"，选择测量位置改为从 `TemperaturePositionCatalog.shared.all` 读取（下拉选择或 picker）
- [x] 8.2 移除对 `MeasurementMethod.allCases` 的引用，改为动态读取 catalog

## 9. 更新 ValueMappingSheet

- [x] 9.1 移除内嵌的关键词 Tag UI，替换为"管理药品"按钮，点击后 `.sheet` 呈现 `MedicationCatalogView(isSheet: true)`
- [x] 9.2 新增"管理体温位置"按钮（当存在体温位置未识别值时显示），点击后 `.sheet` 呈现 `TemperaturePositionCatalogView(isSheet: true)`
- [x] 9.3 更新体温位置值的解析逻辑：从 `TemperaturePositionCatalog` 识别，而非 `MeasurementMethod`

## 10. 更新 ImportPreviewSheet

- [x] 10.1 更新统计展示：使用 `records: [DataRecord]`，统计含体温的记录数和含用药的记录数
- [x] 10.2 更新示例记录展示：展示 DataRecord 内所有 TemperatureReading 和 MedicationUsage
- [x] 10.3 更新写入逻辑：改为将 `DataRecord`（含子对象）批量写入 SwiftData

## 11. FeverEpisodeDetector 适配

- [x] 11.1 更新 `FeverEpisodeDetector.currentEpisode(for:)` 签名：输入改为 `[DataRecord]`
- [x] 11.2 内部逻辑：遍历 `records.flatMap { $0.temperatures }`，用 `TemperatureReading.isFever` 判断发烧，时间戳取父 `DataRecord.timestamp`

## 12. MedicationSafetyViewModel 适配

- [x] 12.1 更新 `availability(forMedicationName:catalog:childId:records:)` 签名：`records` 改为 `[DataRecord]`
- [x] 12.2 内部逻辑：从 `records.flatMap { $0.medications }` 过滤对应药品，时间戳取父 `DataRecord.timestamp`

## 13. RecordView 适配

- [x] 13.1 体温 Tab：测量方式选择改为从 `TemperaturePositionCatalog.shared.all` 读取，保存时写入 `TemperatureReading(positionRaw: selectedPosition.canonicalName, value: ...)`
- [x] 13.2 体温 Tab：同时记录用药改为从 `MedicationCatalog.shared.all` 动态读取药品，保存时在同一 `DataRecord` 中写入 `MedicationUsage`
- [x] 13.3 用药 Tab：药品列表改为从 `MedicationCatalog.shared.all` 读取，保存时创建 `DataRecord { medications: [MedicationUsage(...)] }`
- [x] 13.4 移除所有 `TemperatureRecord`、`MedicationRecord` 的写入代码

## 14. ChartView 适配

- [x] 14.1 更新 `@Query` 为 `@Query(sort: \DataRecord.timestamp) private var allRecords: [DataRecord]`，移除旧的两个 Query
- [x] 14.2 图表数据源：`records.flatMap { $0.temperatures }` 作为折线图点，时间轴取父 `DataRecord.timestamp`
- [x] 14.3 用药标记：`records.flatMap { $0.medications }` 作为 RuleMark 数据，时间取父 `DataRecord.timestamp`，颜色查 `MedicationCatalog`
- [x] 14.4 记录明细列表：改为展示 DataRecord 列表，每条展示所有体温读数和药品

## 15. HomeView 适配

- [x] 15.1 更新 `@Query` 为 `DataRecord`
- [x] 15.2 状态卡片：最新体温从 `allRecords.last?.temperatures.first` 获取
- [x] 15.3 用药安全提醒：调用更新后的 `MedicationSafetyViewModel`（传入 `[DataRecord]`）
- [x] 15.4 最近记录列表：展示最近 5 条 DataRecord

## 16. CSVExporter 适配

- [x] 16.1 更新数据查询：从 `DataRecord` 查询替代旧模型查询
- [x] 16.2 展开逻辑：每个 DataRecord 的每个 `TemperatureReading` 和 `MedicationUsage` 各产生一行 CSV 输出
- [x] 16.3 测量方式列使用 `TemperatureReading.positionRaw`；药物类型列使用 `MedicationUsage.medicationNameRaw`
- [x] 16.4 更新导出预览统计：改为显示"N 条 DataRecord，含 M 次体温、K 次用药"

## 17. Widget 适配

- [x] 17.1 更新 `FeverWidgetProvider` 中的 Schema：`[Child.self, DataRecord.self, TemperatureReading.self, MedicationUsage.self]`
- [x] 17.2 更新 FetchDescriptor：查询 `DataRecord` 替代 `TemperatureRecord` 和 `MedicationRecord`
- [x] 17.3 更新 `WidgetModels.swift`：从 DataRecord 提取体温（`temperatures.first`）和药品（`medications`）填充 Widget entry
- [x] 17.4 Widget 侧调用 `TemperaturePositionCatalog.shared.load()` 以支持 `isFever` 判断

## 18. 清理与验证

- [x] 18.1 从 `Enums.swift` 完全移除 `MedicationType` 枚举（确认 `MedicationCatalog` 已不依赖它）
- [x] 18.2 全局搜索 `TemperatureRecord`、`MedicationRecord`、`MeasurementMethod`，确认无残留引用
- [x] 18.3 编译通过，无 warning（特别是 SwiftData Schema 相关）
- [x] 18.4 在模拟器上验证：录入体温 + 用药 → 首页展示正确 → 图表展示正确 → Widget 刷新正确
- [x] 18.5 验证 CSV 导入流程：选择文件 → ColumnMappingSheet → ValueMappingSheet（弹出 CatalogView）→ 预览 → 写入
- [x] 18.6 验证 CSV 导出：多读数 DataRecord 展开为多行正确

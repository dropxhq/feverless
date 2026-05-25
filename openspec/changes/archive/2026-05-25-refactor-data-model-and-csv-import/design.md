## Context

当前 App 的数据层由两个扁平的 SwiftData 模型组成：`TemperatureRecord`（一条体温记录）和 `MedicationRecord`（一条用药记录），两者通过 `childId` 关联到儿童，通过 `timestamp` 隐式关联彼此。体温测量位置由固定枚举 `MeasurementMethod` 描述，无法支持用户自定义位置（如"左侧液温"）。

CSV 导入目前通过 `compound` rule 将一个 CSV 列映射为多个字段，但语义模糊；导入一行只能产生一条体温记录，无法优雅地表达"同时记录多个位置体温"。

本次重构：
- 用统一的 `DataRecord` 替换两个分离的模型，使一条记录可持有多个体温读数和多条用药记录
- 用 `TemperaturePositionCatalog` 替换固定枚举，支持用户自定义测量位置
- 全面更新 CSV 导入、图表、首页、Widget 等依赖旧模型的组件

## Goals / Non-Goals

**Goals:**
- 统一数据模型：一个 `DataRecord` 包含体温列表 + 药品列表 + 备注
- 体温测量位置可扩展：用 `TemperaturePositionCatalog` 管理位置、关键词、发烧阈值
- CSV 导入：一行可产生多个体温读数和多条用药记录
- 导入/我的页面共享同一套 Catalog 管理 UI（`MedicationCatalogView`、`TemperaturePositionCatalogView`）
- 开发期直接重置数据库，无 SwiftData migration

**Non-Goals:**
- 不做 SwiftData 数据迁移（生产环境迁移留待后续）
- 不改变 CloudKit 同步配置
- 不重新设计记录录入的 UI 风格，只适配新模型
- 不重新设计图表的视觉样式，只适配数据源

## Decisions

### 决策 1：@Relationship 而非 JSON 序列化

**选择**：`DataRecord` 使用 SwiftData `@Relationship(deleteRule: .cascade)` 关联 `TemperatureReading` 和 `MedicationUsage` 子模型。

**理由**：JSON 序列化方案（将子对象编码为 `Data` 字段）虽然简单，但无法利用 SwiftData 的 `#Predicate` 进行关系查询（如过滤发烧记录），也无法在 Widget 中高效获取温度列表。`@Relationship` 方案保留了完整的 SwiftData 查询能力，且三个模型都足够简单，没有过度设计风险。

**子模型定义**：
```
TemperatureReading (@Model)
  positionRaw: String   // TemperaturePositionCatalog.canonicalName
  value: Double

MedicationUsage (@Model)
  medicationNameRaw: String  // MedicationCatalog.canonicalName
```

---

### 决策 2：TemperaturePositionCatalog 存储在 UserDefaults

**选择**：与 `MedicationCatalog` 完全对称，使用 `UserDefaults` + JSON 编码存储，key 为 `"temperature_position_catalog_v1"`。

**理由**：体温位置定义是 App 配置，不是用户数据，不需要 CloudKit 同步，也不需要 SwiftData Schema 参与。UserDefaults 方案与现有 MedicationCatalog 一致，实现最小化。

**内置位置**（从 `MeasurementMethod` 迁移）：
```
腋下: keywords=["腋下","腋温","液温"], feverThreshold=37.5
耳温: keywords=["耳温","耳朵"],       feverThreshold=38.0
肛温: keywords=["肛温"],             feverThreshold=38.0
口腔: keywords=["口腔","口温"],       feverThreshold=38.0
额温: keywords=["额温","额头"],       feverThreshold=37.5
```

---

### 决策 3：MeasurementMethod 枚举完全移除

**选择**：`MeasurementMethod` 枚举整体删除，所有引用改为字符串 canonicalName + catalog 查询。

**理由**：新模型中 `positionRaw` 存储 canonicalName 字符串，`feverThreshold` 从 catalog 动态读取。保留枚举会造成两套体温位置系统并存，维护混乱。`MedicationRecord.type` 也是相同的模式（typeRaw 字符串，不依赖枚举）。

**isFever 判断**：
```swift
extension TemperatureReading {
    func isFever(catalog: TemperaturePositionCatalog = .shared) -> Bool {
        let threshold = catalog.find(positionRaw)?.feverThreshold ?? 37.5
        return value >= threshold
    }
}
```

---

### 决策 4：concurrentTemperature 概念由 DataRecord 结构隐式表达

**选择**：移除 `MedicationRecord.concurrentTemperature` 字段，用"同一个 `DataRecord` 中同时有体温读数和用药记录"来表达并发关系。

**理由**：统一 DataRecord 后，`record.temperatures.first?.value` 就是并发体温。显式 `concurrentTemperature` 字段在新结构下是冗余的。历史数据中若只有用药无体温，该 DataRecord 的 `temperatures` 为空，与旧字段 `concurrentTemperature=nil` 语义等价。

---

### 决策 5：CatalogView 支持双模式呈现

**选择**：`MedicationCatalogView` 和 `TemperaturePositionCatalogView` 均支持两种呈现方式：
- **NavigationLink**：从 ProfileView 打开，有完整导航栏
- **Sheet**：从 `ValueMappingSheet` 弹出，有独立关闭按钮

**实现方式**：通过 `@Environment(\.dismiss)` + 可选参数 `isSheet: Bool` 控制 toolbar 按钮显示（关闭 vs 返回）。两种模式共享完全相同的内容和数据源（catalog 单例），保证「我的」页面和导入流程的修改结果完全一致。

---

### 决策 6：CSV 导入空行定义

**选择**：在 `CSVImporter.parseRows` 中，处理完一行后若产生的 `DataRecord` 满足 `temperatures.isEmpty && medications.isEmpty && notes.isEmpty`，则丢弃该记录，不写入 SwiftData。

**理由**：用户手动录入时由 UI 层保证有效内容，无需 Model 层校验。导入时 CSV 可能存在完全空白的行（如额外换行），需要在解析层静默忽略。

## Risks / Trade-offs

**[风险] SwiftData @Relationship 查询性能** → `DataRecord` 关联两个子模型，Widget 每次刷新需要 fetch DataRecord 并展开关系。缓解：Widget 只取最近 48h 数据，并设置 `fetchLimit`，关系展开成本可控。

**[风险] Widget Schema 需要同步更新** → `FeverWidgetProvider` 中 `Schema` 硬编码了旧模型类型，若主 App 更新 Schema 而 Widget 未同步，会导致 Widget 读取失败。缓解：Widget 和主 App 共享同一 `Schema` 定义，任何模型变更必须同时更新两处。

**[风险] 删除旧模型导致历史数据丢失** → 开发期可接受，但上线前需要补充 SwiftData VersionedSchema 迁移计划。当前决策：开发期不做迁移，留下待办。

**[取舍] 所有消费 DataRecord 的视图需要展开子关系** → `allTempRecords.filter { ... }` 这样的简单查询需要改写为 `allRecords.flatMap { $0.temperatures }.filter { ... }`，代码略冗长，但语义更清晰。

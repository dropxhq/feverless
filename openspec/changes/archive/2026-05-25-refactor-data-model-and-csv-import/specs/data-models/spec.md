## REMOVED Requirements

### Requirement: TemperatureRecord model
**Reason**: 被统一数据模型 `DataRecord + TemperatureReading` 替代。单条体温读数现在作为 `DataRecord.temperatures` 关系中的子对象，不再是顶层 SwiftData 模型。
**Migration**: 开发期重置数据库，无需迁移脚本。生产迁移留待后续 VersionedSchema 计划。

### Requirement: MedicationRecord model
**Reason**: 被统一数据模型 `DataRecord + MedicationUsage` 替代。单条用药记录现在作为 `DataRecord.medications` 关系中的子对象，`concurrentTemperature` 字段由 DataRecord 结构隐式表达（同一 DataRecord 中的 temperatures）。
**Migration**: 同上。

---

## ADDED Requirements

### Requirement: DataRecord model
系统 SHALL 提供 `DataRecord` SwiftData 模型，包含以下字段：
- `id: UUID`
- `childId: UUID`（关联儿童，用于过滤查询）
- `timestamp: Date`（记录时间）
- `notes: String`（默认空）
- `temperatures: [TemperatureReading]`（`@Relationship(deleteRule: .cascade)`，可空列表）
- `medications: [MedicationUsage]`（`@Relationship(deleteRule: .cascade)`，可空列表）

#### Scenario: 创建含体温和用药的记录
- **WHEN** 用户记录腋下 38.0°C 并同时服用布洛芬
- **THEN** 系统创建一个 DataRecord，temperatures=[TemperatureReading(positionRaw:"腋下", value:38.0)]，medications=[MedicationUsage(medicationNameRaw:"布洛芬")]

#### Scenario: 创建仅含备注的记录
- **WHEN** 用户仅录入备注文字
- **THEN** 系统创建 DataRecord，temperatures=[]，medications=[]，notes 非空

---

### Requirement: TemperatureReading model
系统 SHALL 提供 `TemperatureReading` SwiftData 模型，包含以下字段：
- `positionRaw: String`（存储 TemperaturePositionCatalog.canonicalName，如"腋下"）
- `value: Double`（体温值，单位 °C）
- `isFever: Bool`（计算属性，查询 TemperaturePositionCatalog.shared 获取阈值）

#### Scenario: isFever 查询 catalog
- **WHEN** TemperatureReading.positionRaw="腋下", value=37.6
- **THEN** isFever 返回 true（腋下阈值 37.5°C）

#### Scenario: 自建位置的 isFever
- **WHEN** TemperatureReading.positionRaw="左侧液温", value=37.4，用户设定该位置阈值 37.5
- **THEN** isFever 返回 false

---

### Requirement: MedicationUsage model
系统 SHALL 提供 `MedicationUsage` SwiftData 模型，包含以下字段：
- `medicationNameRaw: String`（存储 MedicationCatalog.canonicalName，如"布洛芬"）

#### Scenario: 存储自建药品
- **WHEN** MedicationUsage.medicationNameRaw="退热贴"
- **THEN** 可通过 MedicationCatalog.shared.findByCanonicalName("退热贴") 查到对应定义

---

### Requirement: MeasurementMethod 枚举移除
系统 SHALL 移除 `MeasurementMethod` 枚举。所有原先引用该枚举的代码 SHALL 改为查询 `TemperaturePositionCatalog`（通过 canonicalName 字符串）。

#### Scenario: 体温位置信息来自 catalog
- **WHEN** 代码需要获取"腋下"位置的发烧阈值
- **THEN** 通过 `TemperaturePositionCatalog.shared.find("腋下")?.feverThreshold` 获取，而非 `MeasurementMethod.axillary.feverThreshold`

---

### Requirement: CloudKit 同步配置（保持不变）
系统 SHALL 使用 `ModelConfiguration(cloudKitDatabase: .automatic)` 并将存储文件放置在 App Group 共享容器（`group.top.dropx.feverless`）路径下，使主 App 与 Widget 共享同一数据库文件。Widget 的 `Schema` SHALL 包含 `DataRecord`、`TemperatureReading`、`MedicationUsage`、`Child` 四个模型。

#### Scenario: Widget Schema 包含新模型
- **WHEN** FeverWidgetProvider 构建 ModelContainer
- **THEN** Schema 包含 [Child.self, DataRecord.self, TemperatureReading.self, MedicationUsage.self]

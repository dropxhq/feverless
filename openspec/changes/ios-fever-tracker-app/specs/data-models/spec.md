## ADDED Requirements

### Requirement: Child model
系统 SHALL 提供 `Child` SwiftData 模型，包含 id（UUID）、name（String）、birthDate（Date?）、avatarEmoji（String，默认 "🧒"）、createdAt（Date）字段，所有字段须兼容 CloudKit（有默认值或可选）。

#### Scenario: 创建儿童档案
- **WHEN** 用户提供姓名后保存
- **THEN** 系统创建 Child 记录并持久化到 SwiftData

### Requirement: TemperatureRecord model
系统 SHALL 提供 `TemperatureRecord` SwiftData 模型，包含 id（UUID）、childId（UUID）、value（Double，单位 °C）、method（枚举：axillary/ear/rectal/oral/forehead）、timestamp（Date）、notes（String，默认空）字段。

#### Scenario: 记录体温
- **WHEN** 用户输入体温值、测量方式并保存
- **THEN** 系统创建 TemperatureRecord 并关联到当前儿童

### Requirement: MedicationRecord model
系统 SHALL 提供 `MedicationRecord` SwiftData 模型，包含 id（UUID）、childId（UUID）、type（枚举：ibuprofen/acetaminophen/other）、timestamp（Date）、concurrentTemperature（Double?，同时记录的体温）、notes（String，默认空）字段。

#### Scenario: 记录用药
- **WHEN** 用户选择药物类型并保存
- **THEN** 系统创建 MedicationRecord 并关联到当前儿童

### Requirement: CloudKit 同步配置
系统 SHALL 使用 `ModelConfiguration(cloudKitDatabase: .automatic)` 并将存储文件放置在 App Group 共享容器（`group.top.dropx.feverless`）路径下，使主 App 与 Widget 共享同一数据库文件。

#### Scenario: 多设备同步
- **WHEN** 用户在设备 A 录入体温后切换到设备 B
- **THEN** 设备 B 最终（异步）展示相同数据

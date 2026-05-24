## MODIFIED Requirements

### Requirement: MedicationRecord model
系统 SHALL 提供 `MedicationRecord` SwiftData 模型，包含 id（UUID）、childId（UUID）、typeRaw（String，存储药品 canonical name，如 `"布洛芬"`）、timestamp（Date）、concurrentTemperature（Double?，同时记录的体温）、notes（String，默认空）字段。

`typeRaw` 的合法值为 `MedicationCatalog` 中任意 `MedicationDefinition.canonicalName`。不再使用 `MedicationType` enum 的 rawValue（`"ibuprofen"` 等）作为存储值。

#### Scenario: 记录用药
- **WHEN** 用户选择药品"布洛芬"并保存
- **THEN** 系统创建 MedicationRecord，typeRaw=`"布洛芬"`，并关联到当前儿童

#### Scenario: 记录自建药品
- **WHEN** 用户选择自建药品"退热贴"并保存
- **THEN** 系统创建 MedicationRecord，typeRaw=`"退热贴"`

#### Scenario: 旧数据迁移
- **WHEN** App 升级后首次启动，检测到 typeRaw=`"ibuprofen"` 的历史记录
- **THEN** 系统自动将其更新为 `"布洛芬"`，并标记迁移完成，后续启动不再重复执行

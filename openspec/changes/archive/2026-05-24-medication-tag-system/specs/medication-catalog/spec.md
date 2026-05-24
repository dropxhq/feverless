## ADDED Requirements

### Requirement: MedicationDefinition 模型
系统 SHALL 提供 `MedicationDefinition` Codable 结构体，包含以下字段：
- `id: UUID`（不可变）
- `canonicalName: String`（药品标准名，同时作为存储标识符）
- `keywords: [String]`（用于 CSV 关键词提取的别名列表，不含 canonicalName 本身）
- `isBuiltIn: Bool`（内置药品标记，内置药品不可删除）
- `hasReminder: Bool`（是否启用用药间隔提醒，默认 `true`）
- `minIntervalHours: Double?`（最短用药间隔，nil 表示无限制）
- `maxDailyDoses: Int?`（每日最多剂量，nil 表示无限制）

#### Scenario: 读取内置药品安全配置
- **WHEN** 查询 canonicalName 为"布洛芬"的定义
- **THEN** 返回 minIntervalHours=6.0, maxDailyDoses=4, hasReminder=true

#### Scenario: 读取自建药品配置
- **WHEN** 用户新建了名为"退热贴"的药品，未配置安全参数
- **THEN** 返回 minIntervalHours=nil, maxDailyDoses=nil, hasReminder=true

---

### Requirement: MedicationCatalog 服务
系统 SHALL 提供 `MedicationCatalog` 服务，管理所有 `MedicationDefinition`，支持以下操作：
- `all: [MedicationDefinition]`：返回内置 + 用户自建药品，内置在前
- `find(byName:) -> MedicationDefinition?`：按 canonicalName 查找
- `findCanonicalName(forKeyword:) -> String?`：按关键词（含 canonicalName 自身）查找对应标准名
- `add(_ definition:)`：新增用户自建药品（canonicalName 不可与现有重复）
- `update(_ definition:)`：更新（不可修改内置药品的安全配置）
- `remove(id:)`：删除（内置药品不可删除）
- `save()` / `load()`：持久化到 UserDefaults（key: `"medication_catalog_v2"`）

内置默认药品：
- 布洛芬：keywords=["美林","芬必得","Advil","ibuprofen","布洛芬悬液"], minIntervalHours=6.0, maxDailyDoses=4
- 对乙酰氨基酚：keywords=["对乙","扑热息痛","泰诺","退热净","acetaminophen","小儿泰诺"], minIntervalHours=4.0, maxDailyDoses=5
- 其他：keywords=[], minIntervalHours=nil, maxDailyDoses=nil, isBuiltIn=true

#### Scenario: 关键词查找
- **WHEN** 调用 `findCanonicalName(forKeyword: "美林")`
- **THEN** 返回 `"布洛芬"`

#### Scenario: canonicalName 自身作为关键词
- **WHEN** 调用 `findCanonicalName(forKeyword: "布洛芬")`
- **THEN** 返回 `"布洛芬"`

#### Scenario: 新增自建药品
- **WHEN** 用户添加 canonicalName="退热贴" 的新药品
- **THEN** catalog.all 包含该药品，且持久化成功

#### Scenario: 禁止删除内置药品
- **WHEN** 调用 `remove(id:)` 传入内置药品的 id
- **THEN** 操作被忽略，内置药品仍存在

#### Scenario: 关键词不存在时返回 nil
- **WHEN** 调用 `findCanonicalName(forKeyword: "未知药品")`
- **THEN** 返回 `nil`

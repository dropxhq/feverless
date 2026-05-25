## ADDED Requirements

### Requirement: TemperaturePositionDefinition 模型
系统 SHALL 提供 `TemperaturePositionDefinition` Codable 结构体，包含以下字段：
- `id: UUID`（不可变）
- `canonicalName: String`（测量位置标准名，如"腋下"，同时作为存储标识符，全局唯一）
- `keywords: [String]`（用于 CSV 导入列名/值映射的别名列表，不含 canonicalName 本身）
- `feverThreshold: Double`（该位置的发烧判定阈值，单位 °C）
- `isBuiltIn: Bool`（内置位置标记，内置位置不可删除）

#### Scenario: 读取内置位置配置
- **WHEN** 查询 canonicalName 为"腋下"的定义
- **THEN** 返回 feverThreshold=37.5, isBuiltIn=true

#### Scenario: 读取自建位置配置
- **WHEN** 用户新建了名为"左侧液温"的位置，设置 feverThreshold=37.5
- **THEN** 返回 feverThreshold=37.5, isBuiltIn=false

---

### Requirement: TemperaturePositionCatalog 服务
系统 SHALL 提供 `TemperaturePositionCatalog` ObservableObject 单例，管理所有 `TemperaturePositionDefinition`，支持以下操作：
- `all: [TemperaturePositionDefinition]`：返回内置 + 用户自建位置，内置在前
- `find(_ canonicalName: String) -> TemperaturePositionDefinition?`：按 canonicalName 查找
- `findByKeyword(_ keyword: String) -> TemperaturePositionDefinition?`：按关键词（含 canonicalName 自身）查找
- `add(_ definition:)`：新增用户自建位置（canonicalName 不可与现有重复）
- `update(_ definition:)`：更新（不可修改内置位置的 feverThreshold）
- `remove(id:)`：删除（内置位置不可删除）
- `addKeyword(_ keyword: String, to id: UUID)`
- `removeKeyword(_ keyword: String, from id: UUID)`
- `save()` / `load()`：持久化到 UserDefaults（key: `"temperature_position_catalog_v1"`）

内置默认位置（对应原 `MeasurementMethod` 枚举）：
- 腋下：keywords=["腋下","腋温","液温"], feverThreshold=37.5
- 耳温：keywords=["耳温","耳朵"], feverThreshold=38.0
- 肛温：keywords=["肛温"], feverThreshold=38.0
- 口腔：keywords=["口腔","口温"], feverThreshold=38.0
- 额温：keywords=["额温","额头"], feverThreshold=37.5

#### Scenario: 关键词查找
- **WHEN** 调用 `findByKeyword("腋温")`
- **THEN** 返回 canonicalName 为"腋下"的定义

#### Scenario: canonicalName 自身作为关键词
- **WHEN** 调用 `findByKeyword("额温")`
- **THEN** 返回 canonicalName 为"额温"的定义

#### Scenario: 新增自建位置
- **WHEN** 用户添加 canonicalName="左侧液温", feverThreshold=37.5 的位置
- **THEN** catalog.all 包含该位置，且持久化成功

#### Scenario: 禁止删除内置位置
- **WHEN** 调用 `remove(id:)` 传入内置位置的 id
- **THEN** 操作被忽略，内置位置仍存在

---

### Requirement: TemperaturePositionCatalogView 管理界面
系统 SHALL 提供 `TemperaturePositionCatalogView`，展示所有测量位置，支持：
- 左侧：位置列表（内置在前，自建在后），选中后右侧显示该位置的关键词列表和发烧阈值
- 右侧：关键词列表可添加/删除；底部有"添加关键词"输入框；feverThreshold 可编辑（自建位置）
- 可新增自建位置（输入 canonicalName 和 feverThreshold）
- 内置位置不可删除，但可编辑 keywords
- 视图关闭时自动持久化修改

该视图 SHALL 同时支持两种呈现方式：
- **NavigationLink 模式**：从 ProfileView 进入，使用导航栈
- **Sheet 模式**：从 ValueMappingSheet 弹出，toolbar 显示"完成"关闭按钮

#### Scenario: 添加关键词立即显示
- **WHEN** 用户输入"左腋"并点击"添加"
- **THEN** 关键词列表立即出现"左腋"

#### Scenario: 新增自建位置
- **WHEN** 用户输入 canonicalName="左侧液温" 并确认
- **THEN** 左侧列表末尾出现"左侧液温"

#### Scenario: Sheet 模式有关闭按钮
- **WHEN** TemperaturePositionCatalogView 以 sheet 模式展示
- **THEN** toolbar 显示"完成"按钮，点击后关闭 sheet
